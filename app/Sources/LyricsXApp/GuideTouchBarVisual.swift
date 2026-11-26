import AppKit
import SwiftUI
import LyricsXCore

/// Fixed examples use the shipping lyric view without system Touch Bar access.
enum GuideTouchBarExample {
    static let line = LyricLine(id: 0, time: 0, text: "让每一句歌词，跟着音乐前进", words: [
        .init(text: "让每一句", start: 0, end: 2),
        .init(text: "歌词，", start: 2, end: 4),
        .init(text: "跟着音乐", start: 4, end: 7),
        .init(text: "前进", start: 7, end: 9)
    ])
    static let position = 4.8
}

struct GuideTouchBarVisual: View {
    var showsModes = false
    var showsTranslation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(showsModes ? "闲置后 · 全宽歌词" : "MacBook Pro Touch Bar").font(.headline)
            bar(includesControls: false)
            if showsModes {
                Text("轻触后 · 歌词与系统控制条").font(.headline)
                bar(includesControls: true)
            }
            Text("界面示意 · 使用实际歌词控件")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.quaternary.opacity(0.4))
        .accessibilityElement(children: .combine)
    }
    private func bar(includesControls: Bool) -> some View {
        HStack(spacing: 14) {
            GuideTouchBarNativeView(showsTranslation: showsTranslation)
                .frame(maxWidth: .infinity)
            if includesControls {
                Image(systemName: "sun.max.fill")
                Image(systemName: "speaker.wave.2.fill")
            }
        }
        .foregroundStyle(.white)
        .frame(height: 30)
        .padding(10)
        .background(.black, in: .rect(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

struct GuideTouchBarNativeView: NSViewRepresentable {
    var showsTranslation = false
    func makeNSView(context: Context) -> LyricView { LyricView(frame: .zero) }
    func updateNSView(_ view: LyricView, context: Context) {
        view.update(showsTranslation ? "跟着音乐前进" : GuideTouchBarExample.line.text,
                    playing: false, translation: showsTranslation ? "Let the music lead" : nil,
                    showsTranslation: showsTranslation)
    }
}
