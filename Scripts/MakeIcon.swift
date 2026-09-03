import AppKit
import Foundation

// Reuse the exact SF Symbol already used by v1; no screenshot scaling or tracing.
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let color = NSColor(srgbRed: 0.08, green: 0.48, blue: 0.48, alpha: 1)
guard let symbol = NSImage(systemSymbolName: "play.rectangle.on.rectangle.fill", accessibilityDescription: nil)?
    .withSymbolConfiguration(.init(paletteColors: [.white, color])) else { fatalError("SF Symbol unavailable") }

func render(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 184, yRadius: 184)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.17); shadow.shadowBlurRadius = 17; shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.set()
    NSColor.white.setFill(); tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(srgbRed: 0.88, green: 0.89, blue: 0.90, alpha: 1).setStroke(); tile.lineWidth = 1.5; tile.stroke()
    let scale = min(580 / symbol.size.width, 510 / symbol.size.height)
    let width = symbol.size.width * scale, height = symbol.size.height * scale
    symbol.draw(in: NSRect(x: (1024 - width) / 2, y: (1024 - height) / 2 + 5, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for multiplier in [1, 2] {
        let pixels = points * multiplier
        let filename = "icon_\(points)x\(points)\(multiplier == 2 ? "@2x" : "").png"
        try render(pixels).write(to: iconset.appendingPathComponent(filename))
    }
}
try render(1024).write(to: root.appendingPathComponent("Assets/AppIcon-1024.png"))
