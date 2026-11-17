import AppKit
import Testing
import LyricsXCore
@testable import LyricsXApp

@Suite(.serialized) @MainActor struct SettingsTranslationPolicyTests {
    private struct Repository: LyricsRepository {
        func lyrics(for track: Track, forceRefresh: Bool) -> AsyncThrowingStream<LyricCandidate, Error> { .init { $0.finish() } }
        func save(_ document: LyricsDocument, for track: Track) async throws {}
    }

    @Test func overlayCanHideTranslationWhileMainMasterAndTouchBarRemainEnabled() async throws {
        _ = NSApplication.shared
        let suite = "SettingsTranslationPolicy-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let p = Preferences(defaults: defaults)
        p.showTranslation = true; p.touchBarShowTranslation = true
        p.touchBarEnabled = true; p.touchBarBackgroundEnabled = true
        let document = LyricsDocument(lines: [
            .init(id: 0, time: 0, text: "Original", translation: "译文"),
            .init(id: 1, time: 10, text: "Next")])
        let model = AppModel(repository: Repository(), preferences: p)
        let controller = IntegratedTouchBarController(managesSystemTouchBar: false)
        defer { controller.stop(); model.stop() }
        model.session.accept(.init(track: .init(playerID: "test", playerName: "Test", title: "Title"), position: 1, isPlaying: false), shouldSearch: false)
        model.session.use(document, persist: false)
        controller.start(model: model)
        let item = try #require(controller.touchBar(NSTouchBar(), makeItemForIdentifier: .init("local.shiloh.touchbarlyrics.content")))
        let view = try #require(item.view as? LyricView)

        for mode in OverlaySecondaryMode.allCases {
            p.overlaySecondaryMode = mode
            let content = OverlayTextMeasure.secondary(document: document, index: 0, preferences: p)
            #expect(content.translation == (mode.supportsTranslation ? "译文" : nil))
            #expect(p.showTranslation && p.touchBarShowTranslation)
            #expect(view.displayedTranslation == "译文")
        }
        p.overlaySecondaryMode = .both
        p.showTranslation = false
        try await Task.sleep(for: .milliseconds(50))
        let content = OverlayTextMeasure.secondary(document: document, index: 0, preferences: p)
        #expect(content.translation == nil && content.next == "Next")
        #expect(view.displayedTranslation == nil)
        // Disabling translations must not erase the user's selected overlay mode.
        #expect(Preferences(defaults: defaults).overlaySecondaryMode == .both)
    }

    @Test func searchExposesActualOverlaySelectorAndNoLongerPromisesIndependentMainSwitch() {
        #expect(SettingsSearchIndex.results(for: "悬浮窗 关闭翻译").contains { $0.title == "翻译与下一句" })
        #expect(!SettingsSearchIndex.entries.contains { $0.title == "辅助内容" })
        #expect(!SettingsSearchIndex.entries.contains { $0.detail.contains("各位置可单独关闭") })
        for title in ["悬浮窗样式", "HDR 辉光增强", "HDR 亮度倍数", "恢复字体与颜色"] {
            #expect(SettingsSearchIndex.results(for: title).contains { $0.title == title })
        }
    }
}
