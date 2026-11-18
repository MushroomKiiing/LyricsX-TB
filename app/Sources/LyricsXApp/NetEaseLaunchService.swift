import ServiceManagement

/// macOS owns the registration state; no preference can silently enable this agent.
@MainActor
enum NetEaseLaunchService {
    static let plistName = "com.lyricsx.modern.netease-launch.plist"
    static var agent: SMAppService { SMAppService.agent(plistName: plistName) }
}
