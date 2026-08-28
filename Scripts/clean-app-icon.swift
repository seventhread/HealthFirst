#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("用法：Scripts/clean-app-icon.swift <输入 PNG> <输出 PNG>\n".utf8)
    )
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let source = NSImage(contentsOf: inputURL) else {
    FileHandle.standardError.write(Data("无法读取输入图标。\n".utf8))
    exit(1)
}

let pixelSize = 1_024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("无法创建输出画布。\n".utf8))
    exit(1)
}

bitmap.size = NSSize(width: pixelSize, height: pixelSize)
guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    FileHandle.standardError.write(Data("无法创建绘图上下文。\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
context.shouldAntialias = true

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

// The generated tile has a consistent 6% safe margin. Clipping a few pixels
// inside its antialiased edge removes every extraction speck while preserving
// the complete foreground artwork and the tile's soft interior shadow.
let tileRect = NSRect(x: 66, y: 51, width: 892, height: 919)
let tilePath = NSBezierPath(
    roundedRect: tileRect,
    xRadius: 154,
    yRadius: 154
)
tilePath.addClip()

source.draw(
    in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
    from: .zero,
    operation: .copy,
    fraction: 1,
    respectFlipped: true,
    hints: [.interpolation: NSImageInterpolation.high]
)

context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("无法编码 PNG。\n".utf8))
    exit(1)
}

do {
    try png.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(Data("写入图标失败：\(error)\n".utf8))
    exit(1)
}
