import Testing
@testable import LyricsXApp

struct SettingsSearchTests {
    @Test func findsSpecificOptionsAcrossSectionsWithNaturalAliases() {
        #expect(SettingsSearchIndex.results(for: "自动打开 网易云").contains { $0.section == .general && $0.title == "随网易云启动" })
        #expect(SettingsSearchIndex.results(for: "TB 等待").contains { $0.section == .touchBar && $0.title == "恢复全宽的等待时间" })
        #expect(SettingsSearchIndex.results(for: "高清 隐私").contains { $0.title == "补充高清封面" })
        #expect(SettingsSearchIndex.results(for: "翻译").contains { $0.section == .lyrics && $0.title == "显示翻译" })
        #expect(SettingsSearchIndex.results(for: "翻译").contains { $0.section == .touchBar && $0.title == "显示歌词翻译" })
        #expect(SettingsSearchIndex.results(for: "字号").contains { $0.section == .overlay })
        #expect(SettingsSearchIndex.results(for: "悬浮窗 翻译").contains { $0.title == "翻译与下一句" })
    }
    @Test func handlesCaseSpacingAndUnknownQueriesWithoutChangingSettings() {
        #expect(SettingsSearchIndex.results(for: "  tOuCh BAR   等待  ").map(\.id) == SettingsSearchIndex.results(for: "touchbar 等待").map(\.id))
        #expect(SettingsSearchIndex.results(for: "  \n ").isEmpty)
        #expect(SettingsSearchIndex.results(for: "不存在的设置项xyz").isEmpty)
        #expect(Set(SettingsSearchIndex.entries.map(\.id)).count == SettingsSearchIndex.entries.count)
        #expect(Set(SettingsSearchIndex.entries.map(\.section)) == Set(SettingsSection.allCases))
    }
    @Test func groupedNavigationKeepsEveryPageReachableExactlyOnce() {
        let sections = SettingsGroup.allCases.flatMap(\.sections)
        #expect(sections == SettingsSection.allCases)
        #expect(Set(sections).count == sections.count)
        #expect(SettingsSearchIndex.results(for: "悬浮窗样式").contains { $0.section == .appearance })
        #expect(SettingsSearchIndex.results(for: "应用界面").contains { $0.section == .appearance })
        #expect(!SettingsSearchIndex.entries.contains { $0.section == .touchBar && $0.title == "字体与颜色" })
        #expect(SettingsSearchIndex.entries.contains { $0.section == .typography && $0.title == "Touch Bar" })
    }

}
