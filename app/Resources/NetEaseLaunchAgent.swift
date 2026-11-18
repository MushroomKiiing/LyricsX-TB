// SPDX-License-Identifier: MPL-2.0
// Optional local listener. No network, media APIs, window access, polling or storage.
import AppKit
import MachO

final class NetEaseLaunchListener: NSObject {
    private let workspace = NSWorkspace.shared
    private let targetBundleID = "com.netease.163music"
    private let lyricsBundleID = "com.lyricsx.modern"
    private let applicationURL: URL

    init(executableURL: URL) {
        // Bundled at LyricsX.app/Contents/MacOS/LyricsXNetEaseLaunchAgent.
        applicationURL = executableURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        super.init()
    }

    func start() {
        workspace.notificationCenter.addObserver(self, selector: #selector(applicationLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        // Also handle NetEase already running when this opt-in service starts at login.
        if workspace.runningApplications.contains(where: { $0.bundleIdentifier == targetBundleID }) {
            launchLyricsIfNeeded()
        }
    }

    @objc private func applicationLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == targetBundleID else { return }
        launchLyricsIfNeeded()
    }

    private func launchLyricsIfNeeded() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: lyricsBundleID)
            .contains(where: { $0.processIdentifier != ownPID }) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.arguments = ["--netease-background-launch"]
        configuration.addsToRecentItems = false
        workspace.openApplication(at: applicationURL, configuration: configuration) { _, _ in }
    }
}

// launchd may provide a relative argv[0]; dyld supplies the real executable path.
var pathSize: UInt32 = 0
_NSGetExecutablePath(nil, &pathSize)
var pathBuffer = [CChar](repeating: 0, count: Int(pathSize))
guard _NSGetExecutablePath(&pathBuffer, &pathSize) == 0 else { exit(1) }
let executableURL = URL(fileURLWithPath: String(cString: pathBuffer)).resolvingSymlinksInPath()
let listener = NetEaseLaunchListener(executableURL: executableURL)
listener.start()
RunLoop.main.run()
