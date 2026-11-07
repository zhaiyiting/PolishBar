import AppKit

/// A template (monochrome) menu-bar glyph matching the app icon's motif:
/// three text lines and a sparkle. Template images are tinted by the system.
enum MenuBarGlyph {
    static let image: NSImage = {
        let pointSize: CGFloat = 18
        let scale: CGFloat = 2

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pointSize * scale), pixelsHigh: Int(pointSize * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        rep.size = NSSize(width: pointSize, height: pointSize)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawGlyph(side: pointSize)
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }()

    private static func drawGlyph(side: CGFloat) {
        NSColor.black.setFill()

        let lineHeight = side * 0.13
        let left = side * 0.12
        let widths: [CGFloat] = [0.52, 0.52, 0.30]
        var y = side * 0.66
        for width in widths {
            let rect = NSRect(x: left, y: y, width: side * width, height: lineHeight)
            NSBezierPath(roundedRect: rect, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
            y -= side * 0.22
        }

        let center = NSPoint(x: side * 0.80, y: side * 0.80)
        let radius = side * 0.17
        let inner = radius * 0.30
        let path = NSBezierPath()
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4 + .pi / 2
            let r = (i % 2 == 0) ? radius : inner
            let point = NSPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.line(to: point) }
        }
        path.close()
        path.fill()
    }
}
