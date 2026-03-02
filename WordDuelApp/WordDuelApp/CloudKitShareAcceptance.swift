import Foundation
import UIKit
import CloudKit

extension Notification.Name {
    static let wordDuelCloudShareAccepted = Notification.Name("WordDuelCloudShareAccepted")
}

final class CloudKitShareAcceptanceDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let container = CKContainer(identifier: cloudKitShareMetadata.containerIdentifier)

        container.accept(cloudKitShareMetadata) { _, error in
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .wordDuelCloudShareAccepted,
                    object: error
                )
            }
        }
    }
}
