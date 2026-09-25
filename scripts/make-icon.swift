#!/usr/bin/env swift
// Renders a 1024x1024 PNG app icon in the Field Notes design language.
// Run with: swift scripts/make-icon.swift <output.png>
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <output.png>\n".data(using: .utf8)!)
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let size: CGFloat = 1024

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// Field Notes palette. The icon carries the same single warm recording accent as
// the recording dock, against the quiet graphite used by the application shell.
let canvas = NSColor(red: 0.051, green: 0.055, blue: 0.051, alpha: 1)
let stroke = NSColor(red: 0.188, green: 0.192, blue: 0.180, alpha: 1)
let amber = NSColor(red: 0.961, green: 0.710, blue: 0.267, alpha: 1)

let background = NSBezierPath(
    roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
    xRadius: 225,
    yRadius: 225
)
canvas.setFill()
background.fill()

// A restrained inner keyline gives the dark icon edge definition in the Dock
// without introducing a second accent colour.
let keyline = NSBezierPath(
    roundedRect: NSRect(x: 28, y: 28, width: size - 56, height: size - 56),
    xRadius: 205,
    yRadius: 205
)
stroke.setStroke()
keyline.lineWidth = 4
keyline.stroke()

// The recording disc is the Field Notes signature: one deliberate capture
// control rather than a decorative waveform.
let center = NSPoint(x: size / 2, y: size / 2)
let disc = NSBezierPath(ovalIn: NSRect(x: center.x - 292, y: center.y - 292, width: 584, height: 584))
amber.setFill()
disc.fill()

// A three-bar audio mark is cut from the disc. It stays recognizable at small
// sizes and mirrors the live-level language used only during recording.
let barWidth: CGFloat = 58
let barSpacing: CGFloat = 36
let heights: [CGFloat] = [150, 262, 150]
let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * barSpacing
let startX = center.x - totalWidth / 2

canvas.setFill()
for (index, height) in heights.enumerated() {
    let rect = NSRect(
        x: startX + CGFloat(index) * (barWidth + barSpacing),
        y: center.y - height / 2,
        width: barWidth,
        height: height
    )
    NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to encode PNG\n".data(using: .utf8)!)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
