import SwiftUI
import UIKit
import CloudKit

struct CloudSharingControllerSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    let onSaved: () -> Void
    let onStopped: () -> Void
    let onFailure: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let parent: CloudSharingControllerSheet

        init(parent: CloudSharingControllerSheet) {
            self.parent = parent
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            parent.onSaved()
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            parent.onStopped()
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            parent.onFailure(error)
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            if let customTitle = parent.share[CKShare.SystemFieldKey.title] as? String,
               !customTitle.isEmpty {
                return customTitle
            }

            return "Word Duel"
        }
    }
}
