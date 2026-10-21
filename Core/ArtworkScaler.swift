import AppKit

/// Scales artwork to a fixed square size: widgets reject large images.
enum ArtworkScaler {
    static func jpeg(from raw: Data, side: Int = 400) -> Data? {
        guard let src = NSBitmapImageRep(data: raw)
                ?? NSImage(data: raw).flatMap({ $0.tiffRepresentation }).flatMap({ NSBitmapImageRep(data: $0) }),
              let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctx = NSGraphicsContext(bitmapImageRep: out) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        src.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return out.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
    }
}
