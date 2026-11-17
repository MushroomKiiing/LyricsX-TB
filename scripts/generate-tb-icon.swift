// SPDX-License-Identifier: MPL-2.0
// Original geometric icon for LyricsX TB. No upstream logo assets are used.
import AppKit
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("Resources/Icon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let px = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let c = NSGraphicsContext.current!.cgContext
        c.scaleBy(x: CGFloat(px)/1024, y: CGFloat(px)/1024)
        NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.20, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 32,y:32,width:960,height:960),xRadius:215,yRadius:215).fill()
        NSColor(calibratedRed: 0.24, green: 0.55, blue: 0.96, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x:112,y:340,width:800,height:344),xRadius:85,yRadius:85).fill()
        NSColor(calibratedWhite: 0.03, alpha:1).setFill()
        NSBezierPath(roundedRect: NSRect(x:142,y:370,width:740,height:284),xRadius:60,yRadius:60).fill()
        NSColor.white.setFill()
        for (x,w) in [(216.0,275.0),(527.0,205.0)] {
            NSBezierPath(roundedRect:NSRect(x:x,y:492,width:w,height:36),xRadius:18,yRadius:18).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using:.png,properties:[:])!.write(to:iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
