import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite(.serialized) @MainActor struct IntegratedTouchBarTests {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }
    @Test func mainPreferencesControlActualLyricAndTranslation() async throws {
        _ = NSApplication.shared
        let suite = "IntegratedTouchBar-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let p = Preferences(defaults: defaults)
        p.touchBarEnabled = true; p.touchBarBackgroundEnabled = true
        p.touchBarShowTranslation = true; p.showTranslation = true
        let model = AppModel(repository: Repository(), preferences: p)
        let controller = IntegratedTouchBarController(managesSystemTouchBar: false)
        defer { controller.stop(); model.stop() }
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Title"), position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(.init(lines: [.init(id: 0, time: 0, text: "Original", translation: "译文")]), persist: false)
        controller.start(model: model)
        let item = try #require(controller.touchBar(NSTouchBar(), makeItemForIdentifier: .init("local.shiloh.touchbarlyrics.content")))
        let view = try #require(item.view as? LyricView)
        #expect(view.lyric == "Original")
        #expect(view.displayedTranslation == "译文")
        p.showTranslation = false
        try await Task.sleep(for: .milliseconds(50))
        #expect(view.displayedTranslation == nil)
        p.showTranslation = true; p.touchBarShowTranslation = false
        try await Task.sleep(for: .milliseconds(50))
        #expect(view.displayedTranslation == nil)
        p.touchBarShowTranslation = true
        try await Task.sleep(for: .milliseconds(50))
        #expect(view.displayedTranslation == "译文")
        p.touchBarAutoFullWidth = true
        try await Task.sleep(for: .milliseconds(50))
        view.performClick(nil)
        #expect(controller.showingNormalControls)
        #expect(controller.lyricButtonActivations == 1)
        p.touchBarEnabled = false
        try await Task.sleep(for: .milliseconds(50))
        #expect(controller.status == "未启用")
        let restored = Preferences(defaults: defaults)
        #expect(!restored.touchBarEnabled && restored.touchBarAutoFullWidth && restored.touchBarShowTranslation)
    }
    @Test func idleDelayPersistsEntireOneToFifteenSecondRange() throws {
        let suite = "TouchBarIdleRange-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        for seconds in [1.0, 3.0, 15.0] {
            let p = Preferences(defaults: defaults)
            p.touchBarIdleSeconds = seconds
            let restored = Preferences(defaults: defaults)
            #expect(restored.touchBarIdleSeconds == seconds)
            var idle = TouchBarIdleState()
            idle.yieldControls(at: 100)
            #expect(!idle.shouldReturnToLyrics(at: 100 + seconds - 0.01, delay: restored.touchBarIdleSeconds))
            #expect(idle.shouldReturnToLyrics(at: 100 + seconds, delay: restored.touchBarIdleSeconds))
        }
    }
    @Test func fullWidthUsesRealHostAndBlankSidesAreClickable() throws {
        let host = NSView(frame: .init(x: 0, y: 0, width: 1004, height: 30))
        let wrapper = NSView(frame: .init(x: 0, y: 0, width: 445, height: 30))
        let view = LyricView(frame: .init(x: 0, y: 0, width: 988, height: 30))
        host.addSubview(wrapper); wrapper.addSubview(view)
        view.fillsTouchBar = true; view.expandsToHost = true
        #expect(view.intrinsicContentSize.width == 988)
        for x in [CGFloat(1), CGFloat(494), CGFloat(987)] {
            let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: .init(x: x, y: 15), modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
            #expect(view.cell!.hitTest(for: event, in: view.bounds, of: view).contains(.trackableArea))
        }
        view.expandsToHost = false
        #expect(view.intrinsicContentSize.width == 620)
        var idle = TouchBarIdleState(); idle.yieldControls(at: 10)
        #expect(!idle.shouldReturnToLyrics(at: 14.99))
        #expect(idle.shouldReturnToLyrics(at: 15))
        idle.touch(at: 14, down: true)
        #expect(!idle.shouldReturnToLyrics(at: 30))
    }
}
