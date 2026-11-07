#!/usr/bin/env swift
// Renders AppIcon.iconset PNGs. Usage: swift scripts/make-icon.swift <out.iconset>
import AppKit
import Foundation

func drawSparkle(center: NSPoint, radius: CGFloat) {
    let path = NSBezierPath()
    let inner = radius * 0.30
    let points = 4
    for i in 0..<(points * 2) {
        let angle = CGFloat(i) * .pi / CGFloat(points) + .pi / 2
        let r = (i % 2 == 0) ? radius : inner
        let p = NSPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        if i == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    NSColor.white.setFill()
    path.fill()
}

func drawIcon(size: CGFloat) {
    // Rounded-square gradient background.
    let inset = size * 0.055
    let bg = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = size * 0.225
    let bgPath = NSBezierPath(roundedRect: bg, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.36, green: 0.42, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.66, green: 0.31, blue: 0.98, alpha: 1),
    ])!
    gradient.draw(in: bgPath, angle: -90)

    // Three "text" lines.
    NSColor.white.setFill()
    let lineHeight = size * 0.086
    let left = size * 0.235
    let widths: [CGFloat] = [0.50, 0.50, 0.32]
    var y = size * 0.575
    for width in widths {
        let rect = NSRect(x: left, y: y, width: size * width, height: lineHeight)
        NSBezierPath(roundedRect: rect, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
        y -= size * 0.155
    }

    // Sparkle, upper right.
    drawSparkle(center: NSPoint(x: size * 0.725, y: size * 0.735), radius: size * 0.115)
}

func png(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon(size: size)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let variants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, size) in variants {
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(name)
    try! png(size: size).write(to: url)
}
print("wrote \(variants.count) images to \(outputDir)")
