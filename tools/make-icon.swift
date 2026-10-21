// Generates App/Assets.xcassets/AppIcon.appiconset (gradient background + mirrored equalizer).
// Usage: swift tools/make-icon.swift
import AppKit

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    // macOS icon body: rounded square with a margin (about 80%).
    let body = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let path = NSBezierPath(roundedRect: body, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02,
                                                   color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill(); path.fill()
    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    NSGradient(colors: [NSColor(red: 0.42, green: 0.30, blue: 0.95, alpha: 1), NSColor(red: 0.98, green: 0.35, blue: 0.55, alpha: 1)])!
        .draw(in: path, angle: -60)
    // Equalizer bars symmetric about the horizontal axis: the "mirror".
    let heights: [CGFloat] = [0.20, 0.38, 0.54, 0.34, 0.24]
    let barW = body.width * 0.09, gap = body.width * 0.055
    let total = CGFloat(heights.count) * barW + CGFloat(heights.count - 1) * gap
    var x = body.midX - total / 2
    for (i, h) in heights.enumerated() {
        let bh = body.height * h
        let r = NSRect(x: x, y: body.midY - bh / 2, width: barW, height: bh)
        NSColor.white.withAlphaComponent(i == 2 ? 1 : 0.92).setFill()
        NSBezierPath(roundedRect: r, xRadius: barW / 2, yRadius: barW / 2).fill()
        x += barW + gap
    }
    // Thin mirror line.
    NSColor.white.withAlphaComponent(0.35).setFill()
    NSBezierPath(roundedRect: NSRect(x: body.minX + body.width * 0.2, y: body.midY - s * 0.002, width: body.width * 0.6, height: s * 0.004),
                 xRadius: s * 0.002, yRadius: s * 0.002).fill()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "App/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try! render(base * scale).write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let json = try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["version": 1, "author": "xcode"]], options: [.prettyPrinted])
try! json.write(to: URL(fileURLWithPath: "\(dir)/Contents.json"))
try! #"{"info":{"version":1,"author":"xcode"}}"#.write(toFile: "App/Assets.xcassets/Contents.json", atomically: true, encoding: .utf8)
