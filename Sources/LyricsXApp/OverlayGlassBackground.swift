import AppKit
import QuartzCore

/// A single native material with a contrast gradient in its supported content
/// view. AppKit owns refraction; no optical masks or copied desktop surface.
@MainActor
final class OverlayGlassBackground: NSView {
    private var glass: NSView
    private let preferNativeGlass: Bool
    private let scrim = OverlayGradientView()
    private var configuration: Configuration?
    private var applyingConfiguration = false

    private struct Configuration: Equatable {
        let appearance: OverlayAppearance
        let transparency: Double
        let frostAmount: Double
        let reduceTransparency: Bool
        let dark: Bool
    }

    override convenience init(frame: NSRect) {
        self.init(frame: frame, preferNativeGlass: true)
    }

    init(frame: NSRect, preferNativeGlass: Bool) {
        self.preferNativeGlass = preferNativeGlass
        glass = Self.makeMaterial(frame: frame, preferNativeGlass: preferNativeGlass)
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 24
        layer?.cornerCurve = .continuous
        glass.frame = bounds
        glass.autoresizingMask = [.width, .height]
        // The owning window or preview supplies the same explicit appearance
        // as its foreground ink. Do not seed a conflicting dark appearance.
        glass.wantsLayer = true
        scrim.wantsLayer = true
        attachScrim(to: glass)
        addSubview(glass)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        guard !applyingConfiguration, let configuration else { return }
        configure(appearance: configuration.appearance, transparency: configuration.transparency,
                  frostAmount: configuration.frostAmount, reduceTransparency: configuration.reduceTransparency,
                  reduceMotion: true)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        synchronizeGeometry()
    }

    override func layout() {
        super.layout()
        synchronizeGeometry()
    }

    // Commit the material and gradient in the same resize transaction.
    func synchronizeGeometry() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if glass.frame != bounds { glass.frame = bounds }
        if scrim.frame != glass.bounds { scrim.frame = glass.bounds }
        CATransaction.commit()
    }

    func configure(appearance: OverlayAppearance, transparency: Double, frostAmount: Double,
                   reduceTransparency: Bool, reduceMotion: Bool, theme: InterfaceTheme? = nil) {
        guard !applyingConfiguration else { return }
        applyingConfiguration = true
        defer { applyingConfiguration = false }
        if let theme, self.appearance?.name != theme.appearance?.name { self.appearance = theme.appearance }
        let dark = appearance == .glass || effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let next = Configuration(appearance: appearance,
                                 transparency: appearance.clampedMaterialTransparency(transparency),
                                 frostAmount: appearance.clampedFrost(frostAmount),
                                 reduceTransparency: reduceTransparency, dark: dark)
        if reduceMotion { scrim.layer?.removeAnimation(forKey: "appearance") }
        guard configuration != next, let gradient = scrim.layer as? CAGradientLayer else { return }
        let animate = configuration != nil && (configuration?.appearance != appearance || configuration?.dark != dark)
            && !reduceMotion && !reduceTransparency
        let previousColors = gradient.presentation()?.colors ?? gradient.colors
        let replacesOptics = configuration == nil || configuration?.appearance != next.appearance
            || configuration?.dark != next.dark || configuration?.reduceTransparency != next.reduceTransparency
        configuration = next
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Native backdrop graphs cache more than the public style property.
        // Build optical-mode changes off-window with the final appearance,
        // then exchange only the glass, in one transaction. A slider change
        // keeps the existing surface; the lyric host is never replaced.
        let previousGlass = glass
        if replacesOptics {
            glass = Self.makeMaterial(frame: bounds, preferNativeGlass: preferNativeGlass)
            glass.autoresizingMask = [.width, .height]
            glass.wantsLayer = true
        }
        // Clear retains native refraction without the regular variant
        // filling the window with a light/dark frosted surface. Never fade it.
        // Resolve explicit appearance before changing style: AppKit builds the
        // backdrop for that style immediately. Both styles use matching fixed
        // ink, so neither may independently adapt to the desktop underneath.
        let nativeAppearance: NSAppearance.Name = !dark ? .aqua : .darkAqua
        if glass.appearance?.name != nativeAppearance { glass.appearance = NSAppearance(named: nativeAppearance) }
        let radius: CGFloat = appearance == .glass ? 32 : 24
        if #available(macOS 26, *), let native = glass as? OverlayNativeGlassView {
            native.setFixedMaterialAppearance(true)
            let style: NSGlassEffectView.Style = appearance == .glass ? .clear : .regular
            if native.style != style { native.style = style }
            if native.cornerRadius != radius { native.cornerRadius = radius }
        } else if let backdrop = glass as? NSVisualEffectView {
            backdrop.material = appearance == .glass ? .hudWindow : .popover
            backdrop.layer?.cornerRadius = radius
            backdrop.layer?.masksToBounds = true
        }
        layer?.cornerRadius = radius
        gradient.cornerRadius = radius
        // Liquid Glass always remains fully composited: fading it introduces
        // sharp, unwarped ghost images from the desktop. Reading glass keeps
        // its separate opacity behavior; neither path fades foreground lyrics.
        let materialOpacity = appearance.materialOpacity(transparency: next.transparency, frost: next.frostAmount)
        if glass.alphaValue != materialOpacity { glass.alphaValue = materialOpacity }
        glass.needsLayout = true
        scrim.needsLayout = true
        glass.isHidden = reduceTransparency
        let lightPetGlass = !dark
        layer?.backgroundColor = reduceTransparency
            ? NSColor(white: lightPetGlass ? 0.91 : 0.12, alpha: 1).cgColor : nil
        let scrimColor = lightPetGlass ? NSColor.white : NSColor.black
        gradient.colors = appearance.shadeOpacities(transparency: next.transparency, dark: dark)
            .map { scrimColor.withAlphaComponent($0).cgColor }
        if replacesOptics {
            detachScrim(from: previousGlass)
            attachScrim(to: glass)
            replaceSubview(previousGlass, with: glass)
            synchronizeGeometry()
        }
        CATransaction.commit()
        gradient.removeAnimation(forKey: "appearance")
        if animate, let previousColors {
            let transition = CABasicAnimation(keyPath: "colors")
            transition.fromValue = previousColors
            transition.toValue = gradient.colors
            transition.duration = 0.24
            transition.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0, 0.2, 1)
            gradient.add(transition, forKey: "appearance")
        }
    }

    private static func makeMaterial(frame: NSRect, preferNativeGlass: Bool) -> NSView {
        if #available(macOS 26, *), preferNativeGlass {
            let view = OverlayNativeGlassView(frame: frame)
            view.cornerRadius = 24
            return view
        }
        let view = NSVisualEffectView(frame: frame)
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    private func attachScrim(to material: NSView) {
        if #available(macOS 26, *), let native = material as? NSGlassEffectView {
            native.contentView = scrim
        } else {
            material.addSubview(scrim)
        }
    }

    private func detachScrim(from material: NSView) {
        if #available(macOS 26, *), let native = material as? NSGlassEffectView {
            native.contentView = nil
        } else {
            scrim.removeFromSuperview()
        }
    }

}

/// Isolate compatibility behavior from the window and lyric drawing code.
@available(macOS 26, *)
@MainActor private final class OverlayNativeGlassView: NSGlassEffectView {
    private var savedAdaptiveAppearance: Int?

    /// Experimental compatibility, matching the native bridge's adaptive-off
    /// mode. Without it, AppKit can independently darken a light glass backdrop
    /// while our explicit lyric ink remains dark. Other styles restore the
    /// original system value; an unavailable selector leaves native behavior.
    func setFixedMaterialAppearance(_ fixed: Bool) {
        guard fixed != (savedAdaptiveAppearance != nil) else { return }
        let getter = NSSelectorFromString("_adaptiveAppearance")
        let setter = NSSelectorFromString("set_adaptiveAppearance:")
        guard responds(to: getter), responds(to: setter),
              let getIMP = method(for: getter), let setIMP = method(for: setter) else { return }
        typealias Get = @convention(c) (AnyObject, Selector) -> Int
        typealias Set = @convention(c) (AnyObject, Selector, Int) -> Void
        if fixed {
            savedAdaptiveAppearance = unsafeBitCast(getIMP, to: Get.self)(self, getter)
            unsafeBitCast(setIMP, to: Set.self)(self, setter, 1)
        } else if let previous = savedAdaptiveAppearance {
            unsafeBitCast(setIMP, to: Set.self)(self, setter, previous)
            savedAdaptiveAppearance = nil
        }
    }


}

/// AppKit resizes this backing gradient with the material's content view.
@MainActor private final class OverlayGradientView: NSView {
    override func makeBackingLayer() -> CALayer {
        let gradient = CAGradientLayer()
        gradient.startPoint = CGPoint(x: 0.5, y: 1)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.locations = [0, 0.38, 0.76, 1]
        gradient.cornerRadius = 24
        gradient.cornerCurve = .continuous
        gradient.masksToBounds = true
        return gradient
    }
}
