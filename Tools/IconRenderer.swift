import AppKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func bitmap(width: Int, height: Int, transparent: Bool = false, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    if transparent { NSColor.clear.setFill() } else { NSColor.black.setFill() }
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    draw(NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    let url = root.appendingPathComponent(path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func backdrop(_ rect: NSRect) {
    NSColor.black.setFill(); rect.fill()
    let gradient = NSGradient(colors: [NSColor(calibratedRed: 0.04, green: 0.02, blue: 0.14, alpha: 1), .black])!
    gradient.draw(in: rect, angle: -35)
}

func symbol(in rect: NSRect, scale: CGFloat, glow: Bool = true) {
    let side = min(rect.width, rect.height) * scale
    let target = NSRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
    let pointSize = side * 0.88
    let base = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "Ciani Device Control")!
    let palette = NSImage.SymbolConfiguration(paletteColors: [.white, .systemCyan, .systemPurple])
    let configured = base.withSymbolConfiguration(.init(pointSize: pointSize, weight: .semibold).applying(palette))!
    if glow {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.systemPurple.withAlphaComponent(0.85); shadow.shadowBlurRadius = side * 0.09
        shadow.shadowOffset = .zero; shadow.set()
        configured.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
    }
    configured.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
}

save(bitmap(width: 1024, height: 1024) { rect in backdrop(rect); symbol(in: rect, scale: 0.58) },
     "iOS/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

for (suffix, width, height) in [("", 400, 240), ("@2x", 800, 480)] {
    let base = "tvOS/Assets.xcassets/App Icon.brandassets/App Icon.imagestack"
    save(bitmap(width: width, height: height) { backdrop($0) }, "\(base)/Back.imagestacklayer/Content.imageset/Back\(suffix).png")
    save(bitmap(width: width, height: height, transparent: true) { rect in
        let glow = NSGradient(colors: [.systemCyan.withAlphaComponent(0.42), .systemPurple.withAlphaComponent(0.12), .clear])!
        glow.draw(in: NSBezierPath(ovalIn: NSRect(x: rect.midX - rect.height * 0.46, y: rect.midY - rect.height * 0.46,
                                                 width: rect.height * 0.92, height: rect.height * 0.92)), relativeCenterPosition: .zero)
    }, "\(base)/Middle.imagestacklayer/Content.imageset/Middle\(suffix).png")
    save(bitmap(width: width, height: height, transparent: true) { symbol(in: $0, scale: 0.58, glow: false) },
         "\(base)/Front.imagestacklayer/Content.imageset/Front\(suffix).png")
}
