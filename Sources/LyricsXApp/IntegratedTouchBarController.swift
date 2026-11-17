// SPDX-License-Identifier: MPL-2.0
import AppKit
import CoreGraphics
import Observation
import LyricsXCore

struct TouchBarIdleState {
    var showingControls = false
    var fingerDown = false
    var lastTouch = 0.0
    mutating func yieldControls(at now: Double) { showingControls = true; fingerDown = false; lastTouch = now }
    mutating func touch(at now: Double, down: Bool) { lastTouch = now; fingerDown = down }
    func shouldReturnToLyrics(at now: Double, delay: Double = 5) -> Bool {
        showingControls && !fingerDown && now - lastTouch >= delay
    }
}

final class LyricButtonCell: NSButtonCell {
    override func hitTest(for event: NSEvent, in cellFrame: NSRect, of controlView: NSView) -> NSCell.HitResult {
        let point = controlView.convert(event.locationInWindow, from: nil)
        guard cellFrame.contains(point) else { return [] }
        return isEnabled ? [.contentArea, .trackableArea] : [.contentArea]
    }
}

/// The physically verified Touch Bar presentation now lives in the main app.
/// Preferences and the session clock are read directly; no helper or socket.
@Observable @MainActor final class IntegratedTouchBarController: NSObject, NSWindowDelegate {
    private(set) var status = "未启用"
    private(set) var isRunning = false
    private(set) var isRefreshing = false
    private(set) var showingNormalControls = false
    private(set) var lyricButtonActivations = 0
    @ObservationIgnored private weak var model: AppModel?
    @ObservationIgnored private let bridge: TouchBarSystemBridge
    @ObservationIgnored private let managesSystemTouchBar: Bool
    @ObservationIgnored private let bar = NSTouchBar()
    @ObservationIgnored private var tray: NSCustomTouchBarItem?
    @ObservationIgnored private var lyricView: LyricView?
    @ObservationIgnored private var previewView: LyricView?
    @ObservationIgnored private var previewWindow: NSWindow?
    @ObservationIgnored private var idle = TouchBarIdleState()
    @ObservationIgnored private var presentedFullWidth: Bool?
    @ObservationIgnored private var pending: DispatchWorkItem?
    @ObservationIgnored private var lastAttempt = -Double.infinity
    @ObservationIgnored private var lastDiagnostic = 0.0
    @ObservationIgnored private var recoveryTimer: Timer?
    @ObservationIgnored private var animationTimer: Timer?
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var lockObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var touchMonitor: Any?
    @ObservationIgnored private var localTouchMonitor: Any?
    @ObservationIgnored private var sleeping = false
    @ObservationIgnored private var displaySleeping = false
    @ObservationIgnored private var sessionInactive = false
    @ObservationIgnored private var screenLocked = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var previousOptions: [Bool] = []
    private static let contentID = NSTouchBarItem.Identifier("local.shiloh.touchbarlyrics.content")
    private static let trayID = NSTouchBarItem.Identifier("local.shiloh.touchbarlyrics.tray")

    init(managesSystemTouchBar: Bool = true, bridge: TouchBarSystemBridge? = nil) {
        self.managesSystemTouchBar = managesSystemTouchBar
        self.bridge = bridge ?? TouchBarSystemBridge()
        super.init()
    }
    var supportsFullWidth: Bool { bridge.supportsFullWidth }
    private var suspended: Bool { sleeping || displaySleeping || sessionInactive || screenLocked }
    private var eligible: Bool {
        guard isRunning, !suspended, let p = model?.preferences else { return false }
        return p.touchBarEnabled && (p.touchBarBackgroundEnabled || NSApp.isActive)
    }
    var wantsFullWidth: Bool {
        guard let p = model?.preferences else { return false }
        return (p.touchBarAutoFullWidth ? !idle.showingControls : p.touchBarFullWidth) && supportsFullWidth
    }
    func start(model: AppModel) {
        guard !isRunning else { return }
        self.model = model; isRunning = true; generation += 1
        bar.delegate = self; bar.defaultItemIdentifiers = [Self.contentID]; bar.principalItemIdentifier = Self.contentID
        let item = NSCustomTouchBarItem(identifier: Self.trayID)
        let image = NSImage(systemSymbolName: "quote.bubble", accessibilityDescription: "显示歌词")!
        image.isTemplate = true
        let button = NSButton(image: image, target: self, action: #selector(showLyrics))
        button.imagePosition = .imageOnly; button.contentTintColor = .white
        item.view = button; tray = item
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspaceObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let name = note.name
                MainActor.assumeIsolated {
                    guard let self else { return }
                    switch name {
                    case NSWorkspace.screensDidSleepNotification: self.displaySleeping = true
                    case NSWorkspace.screensDidWakeNotification: self.displaySleeping = false
                    case NSWorkspace.sessionDidResignActiveNotification: self.sessionInactive = true
                    case NSWorkspace.sessionDidBecomeActiveNotification: self.sessionInactive = false
                    default: break
                    }
                    self.synchronizePlayback()
                }
            })
        }
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        screenLocked = session?["CGSSessionScreenIsLocked"] as? Bool ?? false
        sessionInactive = !(session?[kCGSessionOnConsoleKey as String] as? Bool ?? true)
        for name in ["com.apple.screenIsLocked", "com.apple.screenIsUnlocked"] {
            lockObservers.append(DistributedNotificationCenter.default().addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] note in
                let name = note.name
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.screenLocked = name.rawValue == "com.apple.screenIsLocked"
                    self.synchronizePlayback()
                }
            })
        }
        touchMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.directTouch]) { [weak self] event in
            MainActor.assumeIsolated { self?.observeTouch(event) }
        }
        localTouchMonitor = NSEvent.addLocalMonitorForEvents(matching: [.directTouch]) { [weak self] event in
            self?.observeTouch(event); return event
        }
        recoveryTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.recover() }
        }
        observeModel()
    }
    private func observeModel() {
        guard isRunning, let model else { return }
        let token = generation
        withObservationTracking {
            let p = model.preferences
            _ = p.touchBarEnabled; _ = p.touchBarBackgroundEnabled; _ = p.touchBarFullWidth
            _ = p.touchBarAutoFullWidth; _ = p.touchBarShowTranslation; _ = p.touchBarIdleSeconds
            _ = p.showTranslation; _ = p.conversion
            _ = model.session.track; _ = model.session.documentRevision; _ = model.session.currentLineIndex
            _ = model.session.isPlaying; _ = model.session.globalOffsetMilliseconds
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self, self.isRunning, self.generation == token else { return }
                self.observeModel()
            }
        }
        let p = model.preferences
        let options = [p.touchBarEnabled, p.touchBarBackgroundEnabled, p.touchBarFullWidth, p.touchBarAutoFullWidth]
        if options != previousOptions {
            if p.touchBarAutoFullWidth { idle.yieldControls(at: ProcessInfo.processInfo.systemUptime) }
            else { idle.showingControls = false }
            previousOptions = options
        }
        showingNormalControls = idle.showingControls
        synchronizePlayback()
    }
    func synchronizePlayback() {
        guard isRunning else { return }
        render()
        if eligible { schedulePresentation() }
        else {
            pending?.cancel(); bridge.dismiss(bar)
            if let tray { bridge.remove(item: tray) }
            // This was a settings/lifecycle removal, not a user tracking a
            // system control. Re-enabling must be allowed to present again.
            presentedFullWidth = nil
        }
        updateAnimation()
        updateStatus()
    }
    private func schedulePresentation() {
        guard eligible, managesSystemTouchBar, let tray else { return }
        if model?.preferences.touchBarAutoFullWidth == true && idle.showingControls && presentedFullWidth == false && !bar.isVisible { return }
        guard !bar.isVisible || presentedFullWidth != wantsFullWidth else { return }
        pending?.cancel()
        lastAttempt = ProcessInfo.processInfo.systemUptime
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.eligible else { return }
            self.lastAttempt = ProcessInfo.processInfo.systemUptime
            let full = self.wantsFullWidth
            self.lyricView?.expandsToHost = full
            if self.presentedFullWidth != full { self.bridge.dismiss(self.bar) }
            if !self.bar.isVisible { self.bridge.remove(item: tray) }
            _ = self.bridge.install(item: tray)
            if self.bridge.present(self.bar, itemIdentifier: Self.trayID, fullWidth: full) { self.presentedFullWidth = full }
            self.render(); self.updateAnimation(); self.updateStatus()
        }
        pending = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
    private func recover() {
        guard isRunning, let p = model?.preferences else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if eligible {
            if p.touchBarAutoFullWidth && idle.showingControls && !bar.isVisible && managesSystemTouchBar {
                idle.lastTouch = now
            } else if p.touchBarAutoFullWidth && idle.shouldReturnToLyrics(at: now, delay: p.touchBarIdleSeconds) {
                idle.showingControls = false; showingNormalControls = false; schedulePresentation()
            } else if !bar.isVisible && now - lastAttempt > 2 { schedulePresentation() }
        }
        updateAnimation()
        if now - lastDiagnostic >= 1 { lastDiagnostic = now; updateStatus() }
    }
    private func observeTouch(_ event: NSEvent) {
        guard eligible, model?.preferences.touchBarAutoFullWidth == true else { return }
        let down = !event.touches(matching: .touching, in: nil).isEmpty
        idle.touch(at: ProcessInfo.processInfo.systemUptime, down: down)
        if !down && !idle.showingControls { showNormalLyrics() }
    }
    @objc func showLyrics() {
        guard eligible else { return }
        idle.showingControls = false; showingNormalControls = false; schedulePresentation()
    }
    func showNormalLyrics() {
        guard eligible, model?.preferences.touchBarAutoFullWidth == true else { return }
        idle.yieldControls(at: ProcessInfo.processInfo.systemUptime)
        showingNormalControls = true; schedulePresentation(); updateStatus()
    }
    private func render() {
        guard let model else { return }
        let s = model.session, p = model.preferences
        var line: LyricLine?
        if let d = s.document, d.isSynced, !d.isInstrumental, !s.documentIsPlaceholder,
           let index = d.index(at: s.presentationPosition(), globalOffsetMilliseconds: s.globalOffsetMilliseconds),
           d.lines.indices.contains(index), FlexbarSnapshot.isDisplayableLyric(d.lines[index].text) { line = d.lines[index] }
        let text = line.map { p.text($0.text) } ?? s.track?.title ?? "等待播放"
        let translation = line?.translation.map { p.text($0) }
        for view in [lyricView, previewView].compactMap({ $0 }) {
            view.update(text, playing: s.isPlaying, translation: translation,
                        showsTranslation: p.showTranslation && p.touchBarShowTranslation)
        }
    }
    private func updateAnimation() {
        let active = !suspended && model?.session.isPlaying == true && (bar.isVisible || previewWindow?.isVisible == true)
        if active && animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.render() }
            }
        } else if !active { animationTimer?.invalidate(); animationTimer = nil }
        isRefreshing = active
    }
    private func updateStatus() {
        if model?.preferences.touchBarEnabled != true { status = "未启用" }
        else if suspended { status = "已暂停，唤醒后恢复" }
        else if !eligible { status = "仅在 LyricsX TB 前台显示" }
        else { status = wantsFullWidth ? "全宽歌词" : "歌词与系统控制条" }
        guard managesSystemTouchBar else { return }
        let data: [String: Any] = ["owner": "LyricsX TB", "automaticDisplayEnabled": model?.preferences.touchBarEnabled == true,
            "autoFullWidth": model?.preferences.touchBarAutoFullWidth == true,
            "showsTranslation": model.map { $0.preferences.showTranslation && $0.preferences.touchBarShowTranslation } ?? false,
            "translationAvailable": lyricView?.translation?.isEmpty == false, "requestedPresentation": wantsFullWidth ? "fullWidth" : "lyricsWithControlStrip",
            "touchBarVisible": bar.isVisible, "showingNormalControls": showingNormalControls,
            "contentWidth": lyricView?.bounds.width ?? 0, "contentVisibleWidth": lyricView?.visibleRect.width ?? 0,
            "lyricButtonActivations": lyricButtonActivations, "fontWeight": "regular", "color": "white",
            "updatedAt": Date().timeIntervalSince1970]
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Touch Bar Lyrics")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let url = directory.appendingPathComponent("status.json")
        if let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]) {
            try? bytes.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
    func showPreview() {
        if previewWindow == nil {
            let view = LyricView(frame: .init(x: 16, y: 46, width: 700, height: 30))
            let root = NSView(frame: .init(x: 0, y: 0, width: 732, height: 110))
            let label = NSTextField(labelWithString: "当前歌曲 · 白色常规字体 · 翻译左右分栏；实体宽度由 Touch Bar 决定。")
            label.font = .systemFont(ofSize: 12); label.textColor = .secondaryLabelColor
            label.frame = .init(x: 16, y: 14, width: 700, height: 22)
            root.addSubview(view); root.addSubview(label)
            let window = NSWindow(contentRect: root.bounds, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Touch Bar 预览"; window.isReleasedWhenClosed = false; window.contentView = root; window.delegate = self; window.center()
            previewWindow = window; previewView = view
        }
        render(); previewWindow?.makeKeyAndOrderFront(nil); NSApp.activate(); updateAnimation()
    }
    func sleep() { sleeping = true; synchronizePlayback() }
    func wake() { sleeping = false; synchronizePlayback() }
    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === previewWindow else { return }
        previewWindow = nil; previewView = nil; updateAnimation()
    }
    func stop() {
        generation += 1; isRunning = false
        pending?.cancel(); pending = nil
        recoveryTimer?.invalidate(); recoveryTimer = nil; animationTimer?.invalidate(); animationTimer = nil
        isRefreshing = false; bridge.dismiss(bar); if let tray { bridge.remove(item: tray) }
        if let touchMonitor { NSEvent.removeMonitor(touchMonitor) }; touchMonitor = nil
        if let localTouchMonitor { NSEvent.removeMonitor(localTouchMonitor) }; localTouchMonitor = nil
        for observer in workspaceObservers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        for observer in lockObservers { DistributedNotificationCenter.default().removeObserver(observer) }
        workspaceObservers.removeAll(); lockObservers.removeAll()
        previewWindow?.close(); previewWindow = nil; previewView = nil
        model = nil; previousOptions = []; presentedFullWidth = nil; status = "未启用"
    }
}

extension IntegratedTouchBarController: NSTouchBarDelegate {
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Self.contentID else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        let view = LyricView(frame: .init(x: 0, y: 0, width: 620, height: 30))
        view.fillsTouchBar = true; view.expandsToHost = wantsFullWidth
        view.setAccessibilityRole(.button)
        view.onActivate = { [weak self] in
            guard let self else { return }
            self.lyricButtonActivations += 1; self.showNormalLyrics()
        }
        item.view = view; lyricView = view; render()
        return item
    }
}

final class LyricView: NSButton {
    var onActivate: (() -> Void)?
    var fillsTouchBar = false
    var expandsToHost = false { didSet { fitPresentationWidth() } }
    private var preferredWidth: CGFloat = 620
    var lyric = "等待 LyricsX TB 同步歌词…"
    var translation: String?
    var showsTranslation = false
    var changedAt = ProcessInfo.processInfo.systemUptime
    var playing = false
    override var intrinsicContentSize: NSSize { NSSize(width: preferredWidth, height: 30) }
    override var isOpaque: Bool { true }
    override init(frame: NSRect) {
        super.init(frame: frame)
        cell = LyricButtonCell(textCell: "")
        title = ""
        isBordered = false
        setButtonType(.momentaryChange)
        target = self
        action = #selector(activateLyrics)
        allowedTouchTypes = [.direct]
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
    required init?(coder: NSCoder) { nil }
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async { [weak self] in self?.fitPresentationWidth() }
    }
    override func layout() { super.layout(); fitPresentationWidth() }
    func fitPresentationWidth() {
        guard fillsTouchBar else { return }
        // The immediate wrapper fits this item. Its parent is the system bar's
        // actual host, measured as 1004 pt on this Mac; never invent a screen size.
        let hostWidth = superview?.superview?.bounds.width ?? 0
        let width = expandsToHost && hostWidth > 100 ? max(80, hostWidth - 16) : 620
        guard abs(preferredWidth - width) > 1 else { return }
        preferredWidth = width
        invalidateIntrinsicContentSize()
    }
    // Let NSButton handle the remote Touch Bar tracking and lift-off action.
    // Raw NSView touches callbacks are not delivered on all system-modal hosts.
    @objc private func activateLyrics() { onActivate?() }
    var displayedTranslation: String? {
        guard showsTranslation, let translation, !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return translation
    }
    func update(_ text: String, playing: Bool, translation: String? = nil, showsTranslation: Bool = false) {
        if lyric != text || self.translation != translation { changedAt = ProcessInfo.processInfo.systemUptime }
        lyric = text; self.translation = translation; self.showsTranslation = showsTranslation
        self.playing = playing
        setAccessibilityLabel(displayedTranslation.map { text + "，" + $0 } ?? text)
        needsDisplay = true
    }
    func drawLine(_ value: String, in region: NSRect) {
        guard region.width > 0 else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .regular), .foregroundColor: NSColor.white]
        let text = value as NSString
        let dimensions = text.size(withAttributes: attrs)
        let overflow = max(0, dimensions.width - region.width)
        let elapsed = max(0, ProcessInfo.processInfo.systemUptime - changedAt - 1.5)
        let shift = min(overflow, elapsed * 28)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: region).addClip()
        text.draw(at: NSPoint(x: region.minX + (overflow == 0 ? (region.width - dimensions.width) / 2 : -shift),
                             y: region.midY - dimensions.height / 2), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }
    override func draw(_ rect: NSRect) {
        NSColor.black.setFill(); bounds.fill()
        let content = bounds.insetBy(dx: 8, dy: 0)
        if let translated = displayedTranslation {
            let gap = min(40, content.width / 6)
            let columnWidth = max(0, (content.width - gap) / 2)
            drawLine(lyric, in: NSRect(x: content.minX, y: content.minY, width: columnWidth, height: content.height))
            drawLine(translated, in: NSRect(x: content.maxX - columnWidth, y: content.minY, width: columnWidth, height: content.height))
        } else { drawLine(lyric, in: content) }
    }

}
