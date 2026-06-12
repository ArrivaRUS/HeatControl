// Фон для окна DMG-инсталлятора.
// Холст сильно больше окна (1600×1000 при окне 660×400): если Finder
// откроет/растянет окно крупнее — вокруг останется тот же тёмный фон,
// а не белая пустота. Дизайн-зона — верхний левый угол 660×400.
// Под иконками — светлые плитки: Finder в светлой теме рисует подписи
// чёрным, на тёмном фоне их не видно.
// Использование: swift scripts/make_dmg_background.swift <outdir>
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources"
let canvas = NSSize(width: 1600, height: 1000)
let design = NSSize(width: 660, height: 400) // видимая зона окна

func draw(scale: CGFloat) -> NSBitmapImageRep {
    let px = NSSize(width: canvas.width * scale, height: canvas.height * scale)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(px.width), pixelsHigh: Int(px.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = canvas // логический размер → корректный dpi для retina

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

    let full = NSRect(origin: .zero, size: canvas)
    // Координаты дизайна: origin окна — верхний левый угол холста.
    // В AppKit y растёт вверх, поэтому верх холста = canvas.height.
    func designY(_ yFromTop: CGFloat) -> CGFloat { canvas.height - yFromTop }

    // Тёмный фон на ВЕСЬ холст
    NSGradient(
        starting: NSColor(calibratedRed: 0.10, green: 0.10, blue: 0.125, alpha: 1),
        ending: NSColor(calibratedRed: 0.055, green: 0.055, blue: 0.07, alpha: 1)
    )?.draw(in: full, angle: -90)

    // Тёплое свечение в дизайн-зоне
    let glow = [
        NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.16, alpha: 0.18).cgColor,
        NSColor.clear.cgColor,
    ] as CFArray
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glow, locations: [0, 1]) {
        ctx.drawRadialGradient(
            g,
            startCenter: CGPoint(x: 120, y: designY(20)), startRadius: 0,
            endCenter: CGPoint(x: 120, y: designY(20)), endRadius: 320,
            options: []
        )
    }

    // Светлые плитки под иконками: подписи Finder (чёрные в светлой теме)
    // ложатся на них. Центры иконок в координатах Finder: (165,195) и (495,195),
    // иконка 104pt, подпись ~до y=285.
    let plateColor = NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.95, alpha: 1)
    for centerX in [CGFloat(165), CGFloat(495)] {
        let plate = NSRect(
            x: centerX - 86,
            y: designY(292),
            width: 172,
            height: 172
        )
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -3), blur: 16,
            color: NSColor.black.withAlphaComponent(0.45).cgColor
        )
        plateColor.setFill()
        NSBezierPath(roundedRect: plate, xRadius: 26, yRadius: 26).fill()
        ctx.restoreGState()
    }

    // Логотип: сквиркл с пламенем + название
    let logoRect = NSRect(x: 26, y: designY(64), width: 38, height: 38)
    let logoPath = NSBezierPath(roundedRect: logoRect, xRadius: 9.5, yRadius: 9.5)
    NSGradient(
        starting: NSColor(calibratedRed: 1.0, green: 0.72, blue: 0.20, alpha: 1),
        ending: NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.21, alpha: 1)
    )?.draw(in: logoPath, angle: -90)
    let flameConfig = NSImage.SymbolConfiguration(pointSize: 19, weight: .bold)
    if let flame = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(flameConfig) {
        let tinted = NSImage(size: flame.size, flipped: false) { r in
            NSColor.white.set()
            r.fill(using: .sourceOver)
            flame.draw(in: r, from: .zero, operation: .destinationIn, fraction: 1)
            return true
        }
        tinted.draw(in: NSRect(
            x: logoRect.midX - flame.size.width / 2,
            y: logoRect.midY - flame.size.height / 2,
            width: flame.size.width, height: flame.size.height
        ))
    }

    func text(_ s: String, size fs: CGFloat, weight: NSFont.Weight,
              color: NSColor, at point: NSPoint, centered: Bool = false) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fs, weight: weight),
            .foregroundColor: color,
        ]
        let str = NSAttributedString(string: s, attributes: attrs)
        var p = point
        if centered {
            p.x -= str.size().width / 2
        }
        str.draw(at: p)
    }

    text("System Control", size: 19, weight: .semibold,
         color: NSColor.white.withAlphaComponent(0.92),
         at: NSPoint(x: 76, y: designY(53)))
    text("Energy · Temperatures · Battery", size: 10.5, weight: .medium,
         color: NSColor.white.withAlphaComponent(0.38),
         at: NSPoint(x: 77, y: designY(71)))

    // Стрелка между плитками
    let arrowY = designY(195)
    let arrowColor = NSColor.white.withAlphaComponent(0.30)
    arrowColor.setStroke()
    let line = NSBezierPath()
    line.lineWidth = 5
    line.lineCapStyle = .round
    line.move(to: NSPoint(x: 272, y: arrowY))
    line.line(to: NSPoint(x: 372, y: arrowY))
    line.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 364, y: arrowY + 15))
    head.line(to: NSPoint(x: 388, y: arrowY))
    head.line(to: NSPoint(x: 364, y: arrowY - 15))
    head.lineWidth = 5
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Подпись снизу дизайн-зоны
    text("Drag System Control to the Applications folder to install",
         size: 12, weight: .medium,
         color: NSColor.white.withAlphaComponent(0.50),
         at: NSPoint(x: design.width / 2, y: designY(362)), centered: true)
    text("First launch: right-click → Open (app is not notarized)",
         size: 10, weight: .regular,
         color: NSColor.white.withAlphaComponent(0.30),
         at: NSPoint(x: design.width / 2, y: designY(380)), centered: true)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (scale, name) in [(CGFloat(1), "dmg-bg.png"), (CGFloat(2), "dmg-bg@2x.png")] {
    let rep = draw(scale: scale)
    if let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    }
}
print("dmg background written to \(outDir)")
