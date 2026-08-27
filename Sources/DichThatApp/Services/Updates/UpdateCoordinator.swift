import Foundation
import DichThatCore
import Sparkle

@MainActor
final class UpdateCoordinator: NSObject, SPUUpdaterDelegate {
    var onStateChange: (@MainActor (UpdateState) -> Void)?

    private(set) var state = UpdateState()
    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    func start() {
        _ = updaterController
        if state.lastCheckedAt == nil,
           let lastCheckedAt = updaterController.updater.lastUpdateCheckDate {
            state = UpdateState(lastCheckedAt: lastCheckedAt)
            publishState()
        }
    }

    func checkForUpdates() {
        start()
        guard state.beginCheck() else { return }
        publishState()

        guard updaterController.updater.canCheckForUpdates,
              !updaterController.updater.sessionInProgress else {
            state.fail(
                message: AppText.Updates.checkUnavailable,
                checkedAt: Date()
            )
            publishState()
            return
        }
        updaterController.updater.checkForUpdateInformation()
    }

    func installAvailableUpdate() {
        guard state.availableVersion != nil else {
            checkForUpdates()
            return
        }
        updaterController.checkForUpdates(nil)
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        state.foundUpdate(version: item.displayVersionString, checkedAt: Date())
        publishState()
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        state.foundNoUpdate(checkedAt: Date())
        publishState()
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        guard nsError.domain != SUSparkleErrorDomain || nsError.code != SUError.noUpdateError.rawValue else {
            return
        }
        state.fail(message: error.localizedDescription, checkedAt: Date())
        publishState()
    }

    private func publishState() {
        onStateChange?(state)
    }
}
