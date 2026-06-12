// Генератор иконки приложения: тёмный сквиркл + градиентное пламя.
// Использование: swift scripts/make_icon.swift Resources
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let iconsetPath = outDir + "/AppIcon.iconset"

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let inset = size * 0.09
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225

    // Фон — тёмный сквиркл с лёгким вертикальным градиентом
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    bgPath.addClip()
    let bg = NSGradient(
        starting: NSColor(calibratedRed: 0.13, green: 0.12, blue: 0.15, alpha: 1),
        ending: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1)
    )
    bg?.draw(in: rect, angle: -90)

    // Тёплое свечение снизу
    let glowColors = [
        NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.12, alpha: 0.55).cgColor,
        NSColor.clear.cgColor,
    ] as CFArray
    if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1]) {
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.12),
            endRadius: rect.width * 0.75,
            options: []
        )
    }

    // Пламя — SF Symbol как маска, залитая градиентом
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.42, weight: .semibold)
    if let symbol = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let scale = (rect.width * 0.52) / max(symbolSize.width, symbolSize.height)
        let w = symbolSize.width * scale
        let h = symbolSize.height * scale
        let symbolRect = CGRect(
            x: rect.midX - w / 2,
            y: rect.midY - h / 2 + rect.height * 0.01,
            width: w, height: h
        )

        var proposed = symbolRect
        if let cgSymbol = symbol.cgImage(forProposedRect: &proposed, context: nil, hints: nil) {
            ctx.saveGState()
            // Мягкая тень-свечение от пламени
            ctx.setShadow(
                offset: .zero, blur: size * 0.06,
                color: NSColor(calibratedRed: 1, green: 0.45, blue: 0.15, alpha: 0.8).cgColor
            )
            ctx.clip(to: symbolRect, mask: cgSymbol)
            let flameColors = [
                NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.30, alpha: 1).cgColor,
                NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.12, alpha: 1).cgColor,
                NSColor(calibratedRed: 1.0, green: 0.20, blue: 0.25, alpha: 1).cgColor,
            ] as CFArray
            if let flame = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: flameColors, locations: [0, 0.55, 1]
            ) {
                ctx.drawLinearGradient(
                    flame,
                    start: CGPoint(x: symbolRect.midX, y: symbolRect.maxY),
                    end: CGPoint(x: symbolRect.midX, y: symbolRect.minY),
                    options: []
                )
            }
            ctx.restoreGState()
        }
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, pixels: Int) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = image.size
    guard let resized = rep.representation(using: .png, properties: [:]) else { return }
    // Перерисовываем в нужный пиксельный размер
    guard let src = NSImage(data: resized) else { return }
    let target = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    target.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
    src.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = target.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
}

try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

let master = drawIcon(size: 1024)
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for s in sizes {
    savePNG(master, to: "\(iconsetPath)/\(s.name).png", pixels: s.px)
}
print("iconset written to \(iconsetPath)")
