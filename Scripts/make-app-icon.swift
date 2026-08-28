#!/usr/bin/swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(
        Data("用法：Scripts/make-app-icon.swift <1024×1024 PNG> <输出 .icns>\n".utf8)
    )
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard outputURL.pathExtension.lowercased() == "icns" else {
    FileHandle.standardError.write(Data("输出文件必须使用 .icns 扩展名。\n".utf8))
    exit(2)
}

guard let source = NSImage(contentsOf: inputURL),
      let sourceRepresentation = source.representations.first,
      sourceRepresentation.pixelsWide == 1_024,
      sourceRepresentation.pixelsHigh == 1_024 else {
    FileHandle.standardError.write(
        Data("输入图标必须是可读取的 1024×1024 位图。\n".utf8)
    )
    exit(1)
}

extension Data {
    mutating func appendBigEndianUInt32(_ value: Int) {
        var encoded = UInt32(value).bigEndian
        Swift.withUnsafeBytes(of: &encoded) { bytes in
            append(contentsOf: bytes)
        }
    }
}

func pngRepresentation(of image: NSImage, pixelSize: Int) throws -> Data {
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
        throw NSError(
            domain: "HealthFirstIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "无法创建 \(pixelSize)×\(pixelSize) 图标画布。"]
        )
    }

    bitmap.size = NSSize(width: pixelSize, height: pixelSize)
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(
            domain: "HealthFirstIcon",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "无法创建图标绘图上下文。"]
        )
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
    image.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "HealthFirstIcon",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "无法编码 \(pixelSize)×\(pixelSize) PNG。"]
        )
    }
    return png
}

// Modern ICNS readers accept PNG-compressed icon chunks. These chunk types
// cover every standard macOS icon pixel size from 16 through 1024 without
// relying on iconutil behavior that differs between Xcode/macOS releases.
let representations: [(type: String, pixels: Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("ic11", 32),
    ("ic12", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic13", 256),
    ("ic09", 512),
    ("ic14", 512),
    ("ic10", 1_024),
]

do {
    var chunks = Data()
    for representation in representations {
        let png = try pngRepresentation(
            of: source,
            pixelSize: representation.pixels
        )
        chunks.append(contentsOf: representation.type.utf8)
        chunks.appendBigEndianUInt32(png.count + 8)
        chunks.append(png)
    }

    var icns = Data("icns".utf8)
    icns.appendBigEndianUInt32(chunks.count + 8)
    icns.append(chunks)

    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try icns.write(to: outputURL, options: .atomic)
} catch {
    FileHandle.standardError.write(
        Data("生成 .icns 失败：\(error.localizedDescription)\n".utf8)
    )
    exit(1)
}
