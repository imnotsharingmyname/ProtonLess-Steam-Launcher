import AppKit
import Sparkle

/// Keeps the updater disabled until this fork has its own signed update feed.
/// Never allow a fork to auto-update itself from the original app's appcast.
@MainActor
final class AppUpdater {

    private let controller: SPUStandardUpdaterController?

    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        let feed = info["SUFeedURL"] as? String ?? ""
        let publicKey = info["SUPublicEDKey"] as? String ?? ""
        guard !feed.isEmpty, !publicKey.isEmpty else {
            controller = nil
            return
        }
        #if DEBUG
        let scheduling = false
        #else
        let scheduling = true
        #endif
        controller = SPUStandardUpdaterController(
            startingUpdater: scheduling,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func check() {
        guard let controller else {
            let alert = NSAlert()
            alert.messageText = "ProtonLess Steam updates are not configured"
            alert.informativeText = "Download builds from your project's GitHub Actions page. "
                + "To enable automatic updates, configure your own signed Sparkle appcast."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        #if !DEBUG
        controller.checkForUpdates(nil)
        #endif
    }
}
