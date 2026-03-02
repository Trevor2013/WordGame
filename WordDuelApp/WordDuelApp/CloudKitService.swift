import Foundation
import CloudKit
import WordDuelCore

struct CloudGameSnapshot {
    let gameID: String
    let state: GameState
    let databaseScope: CKDatabase.Scope
}

struct CloudGameSummary: Identifiable, Hashable {
    let gameID: String
    let databaseScope: CKDatabase.Scope
    let version: Int
    let currentTurn: String
    let updatedAt: Date

    var id: String {
        "\(databaseScope.rawValue)-\(gameID)"
    }
}

struct CloudShareContext {
    let share: CKShare
    let container: CKContainer
}

enum CloudKitServiceError: LocalizedError {
    case gameNotFound(String)
    case malformedRecord(String)
    case conflict(expected: Int, actual: Int)
    case versionMismatch(stateVersion: Int, recordVersion: Int)
    case turnMismatch(stateTurn: String, recordTurn: String)
    case shareRequiresOwnedGame(String)

    var errorDescription: String? {
        switch self {
        case .gameNotFound(let gameID):
            return "Game \(gameID) was not found."
        case .malformedRecord(let field):
            return "Cloud record is missing or invalid field: \(field)."
        case .conflict(let expected, let actual):
            return "Version conflict (expected \(expected), server is \(actual))."
        case .versionMismatch(let stateVersion, let recordVersion):
            return "State version \(stateVersion) does not match record version \(recordVersion)."
        case .turnMismatch(let stateTurn, let recordTurn):
            return "State turn \(stateTurn) does not match record turn \(recordTurn)."
        case .shareRequiresOwnedGame(let gameID):
            return "Game \(gameID) must be opened from your private database before sharing."
        }
    }
}

final class CloudKitService {
    private enum Constants {
        static let recordType = "Game"
        static let gameID = "gameId"
        static let stateJSON = "stateJson"
        static let version = "version"
        static let currentTurn = "currentTurn"
        static let updatedAt = "updatedAt"
    }

    private struct RecordContext {
        let record: CKRecord
        let databaseScope: CKDatabase.Scope
    }

    private struct QueryPage {
        let records: [CKRecord]
        let cursor: CKQueryOperation.Cursor?
    }

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    var sharingContainer: CKContainer {
        container
    }

    init(container: CKContainer = .default()) {
        self.container = container
        self.privateDatabase = container.privateCloudDatabase
        self.sharedDatabase = container.sharedCloudDatabase
    }

    func createGame(initialState: GameState) async throws -> CloudGameSnapshot {
        let gameID = UUID().uuidString.lowercased()
        let recordID = CKRecord.ID(recordName: gameID)
        let record = CKRecord(recordType: Constants.recordType, recordID: recordID)
        try populate(record: record, gameID: gameID, state: initialState)

        _ = try await privateDatabase.save(record)

        return CloudGameSnapshot(
            gameID: gameID,
            state: initialState,
            databaseScope: .private
        )
    }

    func fetchGame(gameId: String) async throws -> CloudGameSnapshot {
        let context = try await fetchRecordContext(
            gameID: gameId,
            preferredScopes: [.private, .shared]
        )

        return try CloudGameSnapshot(
            gameID: gameId,
            state: decodeState(from: context.record),
            databaseScope: context.databaseScope
        )
    }

    func fetchAccessibleGames() async throws -> [CloudGameSummary] {
        let privateResults = try await queryAllRecords(in: .private)
        let sharedResults: [RecordContext]
        do {
            sharedResults = try await queryAllRecords(in: .shared)
        } catch let ckError as CKError where ckError.code == .zoneNotFound || ckError.code == .unknownItem {
            sharedResults = []
        }

        let records = privateResults + sharedResults
        let summaries = records.compactMap { context -> CloudGameSummary? in
            guard let gameID = context.record[Constants.gameID] as? String,
                  let versionNumber = context.record[Constants.version] as? NSNumber,
                  let currentTurn = context.record[Constants.currentTurn] as? String else {
                return nil
            }

            let updatedAt = context.record[Constants.updatedAt] as? Date ?? Date.distantPast
            return CloudGameSummary(
                gameID: gameID,
                databaseScope: context.databaseScope,
                version: versionNumber.intValue,
                currentTurn: currentTurn,
                updatedAt: updatedAt
            )
        }

        return summaries.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.gameID < rhs.gameID
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func saveMove(gameId: String, expectedVersion: Int, newState: GameState) async throws {
        let context = try await fetchRecordContext(
            gameID: gameId,
            preferredScopes: [.private, .shared]
        )

        let serverVersion = try version(from: context.record)
        guard serverVersion == expectedVersion else {
            throw CloudKitServiceError.conflict(expected: expectedVersion, actual: serverVersion)
        }

        try populate(record: context.record, gameID: gameId, state: newState)

        do {
            _ = try await database(for: context.databaseScope).save(context.record)
        } catch let ckError as CKError {
            if ckError.code == .serverRecordChanged,
               let serverRecord = ckError.serverRecord,
               let latest = serverRecord[Constants.version] as? NSNumber {
                throw CloudKitServiceError.conflict(expected: expectedVersion, actual: latest.intValue)
            }
            throw ckError
        }
    }

    func createOrUpdateShare(gameId: String) async throws -> CloudShareContext {
        let context = try await fetchRecordContext(
            gameID: gameId,
            preferredScopes: [.private]
        )

        guard context.databaseScope == .private else {
            throw CloudKitServiceError.shareRequiresOwnedGame(gameId)
        }

        let record = context.record

        if let shareReference = record.share {
            let fetchedShare = try await privateDatabase.record(for: shareReference.recordID)
            guard let existingShare = fetchedShare as? CKShare else {
                throw CloudKitServiceError.malformedRecord("share")
            }

            if existingShare.publicPermission != .none {
                existingShare.publicPermission = .none
                _ = try await modifyRecords(
                    [existingShare],
                    in: .private,
                    savePolicy: .changedKeys,
                    atomically: true
                )
            }

            return CloudShareContext(share: existingShare, container: container)
        }

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Word Duel \(String(gameId.prefix(8)))" as CKRecordValue
        share.publicPermission = .none

        let savedRecords = try await modifyRecords(
            [record, share],
            in: .private,
            savePolicy: .ifServerRecordUnchanged,
            atomically: true
        )

        let savedShare = savedRecords.compactMap { $0 as? CKShare }.first ?? share
        return CloudShareContext(share: savedShare, container: container)
    }

    private func fetchRecordContext(gameID: String, preferredScopes: [CKDatabase.Scope]) async throws -> RecordContext {
        for scope in preferredScopes {
            if let context = try await findRecordContext(gameID: gameID, in: scope) {
                return context
            }
        }

        throw CloudKitServiceError.gameNotFound(gameID)
    }

    private func findRecordContext(gameID: String, in scope: CKDatabase.Scope) async throws -> RecordContext? {
        let predicate = NSPredicate(format: "%K == %@", Constants.gameID, gameID)
        let records: [CKRecord]
        do {
            records = try await queryRecords(in: scope, predicate: predicate, resultsLimit: 1)
        } catch let ckError as CKError where scope == .shared && (ckError.code == .zoneNotFound || ckError.code == .unknownItem) {
            return nil
        }
        guard let first = records.first else {
            return nil
        }

        return RecordContext(record: first, databaseScope: scope)
    }

    private func decodeState(from record: CKRecord) throws -> GameState {
        guard let stateJSON = record[Constants.stateJSON] as? String else {
            throw CloudKitServiceError.malformedRecord(Constants.stateJSON)
        }

        let decodedState = try GameStateCodec.decode(Data(stateJSON.utf8))

        let recordVersion = try version(from: record)
        guard decodedState.version == recordVersion else {
            throw CloudKitServiceError.versionMismatch(
                stateVersion: decodedState.version,
                recordVersion: recordVersion
            )
        }

        if let recordTurn = record[Constants.currentTurn] as? String,
           decodedState.turn.rawValue != recordTurn {
            throw CloudKitServiceError.turnMismatch(
                stateTurn: decodedState.turn.rawValue,
                recordTurn: recordTurn
            )
        }

        return decodedState
    }

    private func version(from record: CKRecord) throws -> Int {
        guard let number = record[Constants.version] as? NSNumber else {
            throw CloudKitServiceError.malformedRecord(Constants.version)
        }

        return number.intValue
    }

    private func populate(record: CKRecord, gameID: String, state: GameState) throws {
        let stateData = try GameStateCodec.encode(state)
        let stateJSON = String(decoding: stateData, as: UTF8.self)

        record[Constants.gameID] = gameID as CKRecordValue
        record[Constants.stateJSON] = stateJSON as CKRecordValue
        record[Constants.version] = Int64(state.version) as CKRecordValue
        record[Constants.currentTurn] = state.turn.rawValue as CKRecordValue
        record[Constants.updatedAt] = Date() as CKRecordValue
    }

    private func queryAllRecords(in scope: CKDatabase.Scope) async throws -> [RecordContext] {
        let predicate = NSPredicate(value: true)
        var results: [RecordContext] = []
        var cursor: CKQueryOperation.Cursor?

        repeat {
            let page = try await queryPage(in: scope, predicate: predicate, cursor: cursor)
            results.append(contentsOf: page.records.map { RecordContext(record: $0, databaseScope: scope) })
            cursor = page.cursor
        } while cursor != nil

        return results
    }

    private func queryRecords(
        in scope: CKDatabase.Scope,
        predicate: NSPredicate,
        resultsLimit: Int
    ) async throws -> [CKRecord] {
        let page = try await queryPage(in: scope, predicate: predicate, cursor: nil, resultsLimit: resultsLimit)
        return page.records
    }

    private func queryPage(
        in scope: CKDatabase.Scope,
        predicate: NSPredicate,
        cursor: CKQueryOperation.Cursor?,
        resultsLimit: Int = CKQueryOperation.maximumResults
    ) async throws -> QueryPage {
        try await withCheckedThrowingContinuation { continuation in
            let operation: CKQueryOperation
            if let cursor {
                operation = CKQueryOperation(cursor: cursor)
            } else {
                operation = CKQueryOperation(
                    query: CKQuery(recordType: Constants.recordType, predicate: predicate)
                )
            }

            operation.resultsLimit = resultsLimit

            let lock = NSLock()
            var records: [CKRecord] = []

            operation.recordMatchedBlock = { _, result in
                if case .success(let record) = result {
                    lock.lock()
                    records.append(record)
                    lock.unlock()
                }
            }

            operation.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    continuation.resume(returning: QueryPage(records: records, cursor: nextCursor))
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            self.database(for: scope).add(operation)
        }
    }

    private func modifyRecords(
        _ records: [CKRecord],
        in scope: CKDatabase.Scope,
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy,
        atomically: Bool
    ) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
            operation.savePolicy = savePolicy
            operation.isAtomic = atomically

            let lock = NSLock()
            var savedRecords: [CKRecord] = []

            operation.perRecordSaveBlock = { _, result in
                if case .success(let savedRecord) = result {
                    lock.lock()
                    savedRecords.append(savedRecord)
                    lock.unlock()
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: savedRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            self.database(for: scope).add(operation)
        }
    }

    private func database(for scope: CKDatabase.Scope) -> CKDatabase {
        switch scope {
        case .private:
            return privateDatabase
        case .shared:
            return sharedDatabase
        case .public:
            return container.publicCloudDatabase
        @unknown default:
            return privateDatabase
        }
    }
}
