import AppKit
import Testing
@testable import LyricsXApp

@MainActor @Test func legacyOverlayUsesBackdropAcrossStyleAndSizeChanges() throws {
    let view = OverlayGlassBackground(frame: NSRect(x: 0, y: 0, width: 300, height: 75), preferNativeGlass: false)
    view.configure(appearance: .glass, transparency: 0.4, frostAmount: 0.5,
                   reduceTransparency: false, reduceMotion: true)
    let initial = try #require(view.subviews.first as? NSVisualEffectView)
    #expect(initial.blendingMode == .behindWindow)
    #expect(initial.material == .hudWindow)
    view.setFrameSize(NSSize(width: 420, height: 130))
    #expect(initial.frame == view.bounds)
    #expect(initial.subviews.first?.frame == initial.bounds)
    view.configure(appearance: .frosted, transparency: 0.4, frostAmount: 0.5,
                   reduceTransparency: true, reduceMotion: true)
    let replacement = try #require(view.subviews.first as? NSVisualEffectView)
    #expect(replacement.material == .popover)
    #expect(replacement.isHidden)
    #expect(replacement.subviews.first?.frame == replacement.bounds)
}
