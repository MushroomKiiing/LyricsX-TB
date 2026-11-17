import Foundation
import Testing
import LyricsXCore
@testable import LyricsXServices

@Suite(.serialized) @MainActor struct NeteaseDedicatedReaderTests {
    @Test func dedicatedModeKeepsNeteaseIdentityAndAcceptsPauseResumeAndSeek() async throws {
        let track = Track(playerID: "com.netease.163music", playerName: "网易云音乐", title: "Test Song", artist: "Artist", duration: 200)
        var input = PlaybackSnapshot(track: track, position: 70, isPlaying: true)
        var received: PlaybackSnapshot?
        let bridge = PlayerBridge(neteaseReader: { input })
        bridge.onSnapshot = { received = $0 }
        bridge.mode = .netease
        defer { bridge.stop() }
        for _ in 0..<100 { if received != nil { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(received?.track?.playerID == "com.netease.163music")
        #expect(received?.isPlaying == true)
        #expect(received?.position == 70)
        input = PlaybackSnapshot(track: track, position: 71, isPlaying: false)
        bridge.refresh()
        for _ in 0..<100 { if received?.isPlaying == false { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(received?.isPlaying == false)
        #expect(received?.position == 71)
        input = PlaybackSnapshot(track: track, position: 120, isPlaying: true)
        bridge.refresh()
        for _ in 0..<100 { if received?.position == 120 { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(received?.position == 120)
        #expect(received?.isPlaying == true)
    }
    @Test func neteaseAnchorIsAdvancedOnceAndPausedClockIsNotAdvanced() throws {
        let playing = Data(#"{"title":"Test Song","bundleIdentifier":"com.netease.163music","isPlaying":true,"elapsedTimeMicros":250000,"timestampEpochMicros":1000000000,"durationMicros":200000000}"#.utf8)
        let payload = try JSONDecoder().decode(SystemMediaPayload.self, from: playing)
        #expect(payload.snapshot(now: 50, wallTime: 1080).position == 80.25)
        let paused = Data(#"{"title":"Test Song","bundleIdentifier":"com.netease.163music","isPlaying":false,"elapsedTimeMicros":80250000,"timestampEpochMicros":1000000000,"durationMicros":200000000}"#.utf8)
        let frozen = try JSONDecoder().decode(SystemMediaPayload.self, from: paused)
        #expect(frozen.snapshot(now: 50, wallTime: 1080).position == 80.25)
    }
}
