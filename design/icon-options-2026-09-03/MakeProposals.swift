import AppKit
import Foundation

// Design proposals only. The active icon and the application bundle are never touched.
// Render the original SF Symbol at the final size; do not enlarge a screenshot.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let voiceoverIcon = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : ""
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
}
let originalTeal = rgb(0.08, 0.48, 0.48)
let baseSymbol = NSImage(systemSymbolName: "play.rectangle.on.rectangle.fill", accessibilityDescription: nil)!
let sourceRect = NSRect(x: 12, y: 112, width: 1000, height: 800)

func nativeSymbol(play: NSColor, panels: NSColor) {
    let symbol = baseSymbol.withSymbolConfiguration(.init(paletteColors: [play, panels]))!
    symbol.draw(in: sourceRect)
}

func bitmap(_ width: Int, _ height: Int, drawing: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current!.imageInterpolation = .high
    drawing()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) throws {
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}

// Measure actual opaque glyph bounds instead of using its padded NSImage frame.
let probe = bitmap(1024, 1024) { nativeSymbol(play: .white, panels: originalTeal) }
var minX = 1024, minY = 1024, maxX = 0, maxY = 0
for y in 0..<1024 { for x in 0..<1024 {
    if probe.colorAt(x: x, y: y)!.alphaComponent > 0.5 {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}}
let glyphBounds = NSRect(x: minX, y: 1023 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
let enlargement = 916 / glyphBounds.width
let frontBounds = NSRect(x: 271, y: 205, width: 646, height: 507)
let rearBounds = NSRect(x: 112, y: 356, width: 646, height: 506)
// These generous clipping shapes separate the native symbol's disconnected panels.
// Visible contours and the Play glyph still come from SF Symbols.
let frontClip = NSBezierPath(roundedRect: frontBounds.insetBy(dx: -7, dy: -7), xRadius: 96, yRadius: 96)

enum Treatment: Int, CaseIterable {
    case original = 1, layers, soft
    var filename: String { ["", "01-clean", "02-two-tones", "03-soft-depth"][rawValue] }
    var title: String { ["", "Чистый", "Два оттенка", "Мягкий объём"][rawValue] }
    var caption: String {
        ["", "Исходный цвет · прозрачный зазор", "Тёмная задняя карточка · чистый зазор", "Лёгкий градиент · светлый внутренний шов"][rawValue]
    }
}

func drawIcon(_ treatment: Treatment, in rect: NSRect) {
    NSGraphicsContext.saveGraphicsState()
    let cg = NSGraphicsContext.current!.cgContext
    cg.translateBy(x: rect.minX, y: rect.minY)
    cg.scaleBy(x: rect.width / 1024, y: rect.height / 1024)
    cg.translateBy(x: 512 - glyphBounds.midX * enlargement, y: 512 - glyphBounds.midY * enlargement)
    cg.scaleBy(x: enlargement, y: enlargement)

    if treatment == .soft {
        // A short seam only where the front card overlaps the rear card.
        // Clip it to the rear card so it can never become an exterior white rim.
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rearBounds, xRadius: 104, yRadius: 104).addClip()
        let seam = NSBezierPath()
        let corner: CGFloat = 104
        seam.move(to: NSPoint(x: frontBounds.minX, y: rearBounds.minY + 24))
        seam.line(to: NSPoint(x: frontBounds.minX, y: frontBounds.maxY - corner))
        seam.curve(to: NSPoint(x: frontBounds.minX + corner, y: frontBounds.maxY),
                   controlPoint1: NSPoint(x: frontBounds.minX, y: frontBounds.maxY - corner * 0.447715),
                   controlPoint2: NSPoint(x: frontBounds.minX + corner * 0.447715, y: frontBounds.maxY))
        seam.line(to: NSPoint(x: rearBounds.maxX - 24, y: frontBounds.maxY))
        rgb(0.94, 0.99, 0.98).setStroke()
        seam.lineWidth = 30
        seam.lineCapStyle = .round
        seam.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    let rear = treatment == .original ? originalTeal : rgb(0.055, 0.345, 0.365)
    nativeSymbol(play: .white, panels: rear)
    if treatment != .original {
        NSGraphicsContext.saveGraphicsState()
        frontClip.addClip()
        if treatment == .layers {
            nativeSymbol(play: .white, panels: rgb(0.075, 0.515, 0.51))
        } else {
            cg.beginTransparencyLayer(auxiliaryInfo: nil)
            nativeSymbol(play: .clear, panels: .white)
            cg.setBlendMode(.sourceIn)
            NSGradient(starting: rgb(0.055, 0.43, 0.465), ending: rgb(0.13, 0.595, 0.565))!
                .draw(in: frontBounds.insetBy(dx: -8, dy: -8), angle: 90)
            cg.endTransparencyLayer()
            cg.setBlendMode(.normal)
            nativeSymbol(play: .white, panels: .clear)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    NSGraphicsContext.restoreGraphicsState()
}

for treatment in Treatment.allCases {
    for size in [32, 64, 128, 256, 512, 1024] {
        let rep = bitmap(size, size) {
            drawIcon(treatment, in: NSRect(x: 0, y: 0, width: size, height: size))
        }
        try save(rep, "\(treatment.filename)-\(size).png")
    }
}

let boardWidth = 1600
let boardHeight = 1160
func topRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: CGFloat(boardHeight) - y - height, width: width, height: height)
}
func label(_ value: String, x: CGFloat, y: CGFloat, width: CGFloat,
           size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = rgb(0.13, 0.18, 0.19),
           alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color, .paragraphStyle: paragraph
    ]
    (value as NSString).draw(in: topRect(x, y, width, size * 1.6), withAttributes: attributes)
}

let finder = NSImage(contentsOfFile: "/System/Library/CoreServices/Finder.app/Contents/Resources/Finder.icns")
let notes = NSImage(contentsOfFile: "/System/Applications/Notes.app/Contents/Resources/AppIcon.icns")
let voiceover = NSImage(contentsOfFile: voiceoverIcon)

let board = bitmap(boardWidth, boardHeight) {
    rgb(0.96, 0.97, 0.965).setFill()
    NSRect(x: 0, y: 0, width: boardWidth, height: boardHeight).fill()
    label("LectureMerge", x: 64, y: 44, width: 800, size: 42, weight: .semibold)
    label("ТРИ ВАРИАНТА ЗНАЧКА", x: 1040, y: 62, width: 496, size: 17, weight: .semibold,
          color: rgb(0.25, 0.39, 0.38), alignment: .right)
    label("Крупнее · прозрачный фон · без внешней белой обводки", x: 66, y: 111, width: 1460, size: 23,
          color: rgb(0.40, 0.46, 0.46))

    let cardWidth: CGFloat = 472
    for treatment in Treatment.allCases {
        let x = CGFloat(64 + (treatment.rawValue - 1) * 500)
        NSColor.white.withAlphaComponent(0.65).setFill()
        NSBezierPath(roundedRect: topRect(x, 180, cardWidth, 441), xRadius: 26, yRadius: 26).fill()
        drawIcon(treatment, in: topRect(x + 76, 213, 320, 320))
        label("\(treatment.rawValue)  \(treatment.title)", x: x + 16, y: 538, width: cardWidth - 32,
              size: 27, weight: .semibold, alignment: .center)
        label(treatment.caption, x: x + 10, y: 582, width: cardWidth - 20, size: 17,
              color: rgb(0.39, 0.46, 0.45), alignment: .center)
    }

    label("Сравнение с соседними значками", x: 64, y: 663, width: 1000, size: 25, weight: .semibold)
    label("Одинаковые ячейки 64 × 64 px", x: 1070, y: 670, width: 466, size: 17,
          color: rgb(0.42, 0.48, 0.47), alignment: .right)

    for (row, dark) in [false, true].enumerated() {
        let top = CGFloat(718 + row * 165)
        let panel = topRect(64, top, 1472, 144)
        (dark ? rgb(0.095, 0.13, 0.15) : rgb(0.89, 0.915, 0.91)).setFill()
        NSBezierPath(roundedRect: panel, xRadius: 23, yRadius: 23).fill()
        label(dark ? "Тёмный фон" : "Светлый фон", x: 96, y: top + 59, width: 215, size: 18,
              color: dark ? rgb(0.66, 0.73, 0.75) : rgb(0.40, 0.48, 0.47))
        let titles = ["Finder", "Заметки", "Озвучка", "1", "2", "3"]
        let references = [finder, notes, voiceover]
        for index in 0..<6 {
            let x = CGFloat(376 + index * 183)
            let iconRect = topRect(x, top + 23, 64, 64)
            if index < 3 {
                references[index]?.draw(in: iconRect)
            } else {
                drawIcon(Treatment(rawValue: index - 2)!, in: iconRect)
            }
            label(titles[index], x: x - 40, y: top + 101, width: 144, size: 16,
                  weight: index >= 3 ? .semibold : .regular,
                  color: dark ? rgb(0.83, 0.88, 0.89) : rgb(0.36, 0.43, 0.42), alignment: .center)
        }
        (dark ? NSColor.white.withAlphaComponent(0.15) : NSColor.black.withAlphaComponent(0.11)).setFill()
        topRect(866, top + 29, 1, 67).fill()
    }
    label("Все варианты: PNG 1024 × 1024 с прозрачностью", x: 64, y: 1083, width: 1100,
          size: 19, color: rgb(0.40, 0.47, 0.46))
}
try save(board, "comparison.png")
print("Saved 3 native-symbol variants and comparison to \(output.path)")
print("Visible symbol width: 916 / 1024; height: \(glyphBounds.height * enlargement)")
