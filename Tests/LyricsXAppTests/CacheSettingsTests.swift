import Foundation
import Testing
@testable import LyricsXApp

@MainActor @Test func cachePreferencePersistsAndIsVisibleToRunningStoreReader() throws {
    let suite = "LyricsXCacheSettings-" + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prefs = Preferences(defaults: defaults)
    #expect(prefs.automaticLyricsCache)
    prefs.automaticLyricsCache = false
    #expect(!prefs.sourceConfigurationReader.automaticCacheEnabled())
    #expect(!Preferences(defaults: defaults).automaticLyricsCache)
    prefs.automaticLyricsCache = true
    #expect(prefs.sourceConfigurationReader.automaticCacheEnabled())
    #expect(SettingsSearchIndex.results(for: "清除 缓存").contains { $0.section == .lyrics && $0.title == "清除歌词缓存" })
    #expect(SettingsSearchIndex.results(for: "自动保存").contains { $0.section == .lyrics && $0.title == "自动保存歌词缓存" })
}
