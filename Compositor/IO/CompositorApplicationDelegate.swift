import AppKit
#if canImport(Sparkle)
import Sparkle
#else
@MainActor
final class SPUStandardUpdaterController: NSObject {
    init(startingUpdater: Bool, updaterDelegate: Any?, userDriverDelegate: Any?) {}
    func startUpdater() {}
    func checkForUpdates(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Check for Updates…".localized
        alert.informativeText = "You are currently running the latest version.".localized
        alert.addButton(withTitle: "OK".localized)
        alert.runModal()
    }
}
#endif

@MainActor
final class CompositorApplicationDelegate: NSObject, NSApplicationDelegate {
    let workspace = ProjectWorkspace()
    var session: EditorSession { workspace.current.session }
    var projects: ProjectController { workspace.current.controller }
    var showEditor: (() -> Void)?
    /// Checks the update feed and installs new versions (Sparkle). Started only after launch: its first-run prompt,
    /// shown during launch, kept the editor window from ever opening.
    let updater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

    // Finder Open With and Dock drops, including files delivered during launch.
    func application(_ application: NSApplication, open urls: [URL]) {
        // Reopening a window that's already showing makes SwiftUI rebuild it, so the app blinks out and back:
        // only a closed editor is reopened.
        if !application.windows.contains(where: { $0.isVisible && $0.identifier?.rawValue.hasPrefix("editor") == true }) {
            showEditor?()
        }
        application.activate()
        Task { await workspace.receive(urls) }
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Slider knobs snap to a click on the track instead of gliding there.
        SliderSnap.install()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [updater] in updater.startUpdater() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showEditor?() }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard workspace.canSwitch else { return .terminateCancel }
        Task { sender.reply(toApplicationShouldTerminate: await workspace.confirmQuit()) }
        return .terminateLater
    }
}
