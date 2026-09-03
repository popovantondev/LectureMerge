import AppKit
import Foundation

// Approved design option 2: the original SF Symbol, enlarged and rendered in
// two teal shades. Its exterior and the gap between the cards are transparent.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
guard let symbol = NSImage(systemSymbolName: "play.rectangle.on.rectangle.fill", accessibilityDescription: nil) else {
    fatalError("SF Symbol unavailable")
}
let originalTeal = NSColor(srgbRed: 0.08, green: 0.48, blue: 0.48, alpha: 1)
let rearTeal = NSColor(srgbRed: 0.055, green: 0.345, blue: 0.365, alpha: 1)
let frontTeal = NSColor(srgbRed: 0.075, green: 0.515, blue: 0.51, alpha: 1)
let sourceRect = NSRect(x: 12, y: 112, width: 1000, height: 800)

func drawSymbol(panels: NSColor) {
    symbol.withSymbolConfiguration(.init(paletteColors: [.white, panels]))!.draw(in: sourceRect)
}

func bitmap(_ pixels: Int, drawing: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current!.imageInterpolation = .high
    drawing()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// SF Symbols have internal padding. Center and size the visible silhouette,
// not that padded image frame, while retaining the original aspect ratio.
let probe = bitmap(1024) { drawSymbol(panels: originalTeal) }
var minX = 1024, minY = 1024, maxX = 0, maxY = 0
for y in 0..<1024 { for x in 0..<1024 {
    if probe.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}}
let bounds = NSRect(x: minX, y: 1023 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
let enlargement = 916 / bounds.width
// This clip contains the front card without reaching the disconnected rear
// card. All visible contours and the white Play still come from SF Symbols.
let frontClip = NSBezierPath(roundedRect: NSRect(x: 271, y: 205, width: 646, height: 507)
    .insetBy(dx: -7, dy: -7), xRadius: 96, yRadius: 96)

func render(_ pixels: Int) -> Data {
    bitmap(pixels) {
        let cg = NSGraphicsContext.current!.cgContext
        cg.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        cg.translateBy(x: 512 - bounds.midX * enlargement, y: 512 - bounds.midY * enlargement)
        cg.scaleBy(x: enlargement, y: enlargement)
        drawSymbol(panels: rearTeal)
        NSGraphicsContext.saveGraphicsState()
        frontClip.addClip()
        drawSymbol(panels: frontTeal)
        NSGraphicsContext.restoreGraphicsState()
    }.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let pixels = points * multiplier
        let filename = "icon_\(points)x\(points)\(multiplier == 2 ? "@2x" : "").png"
        try render(pixels).write(to: iconset.appendingPathComponent(filename))
    }
}
try render(1024).write(to: root.appendingPathComponent("Assets/AppIcon-1024.png"))
