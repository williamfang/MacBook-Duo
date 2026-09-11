import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    fputs("usage: generate-icon <source.png> <output.icns>\n", stderr)
    exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = NSImage(contentsOf: sourceURL) else {
    fputs("unable to read source image\n", stderr)
    exit(1)
}

let entries: [(type: String, pixels: Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
]

func bigEndianData(_ value: UInt32) -> Data {
    var encoded = value.bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

var chunks = Data()
for entry in entries {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: entry.pixels,
        pixelsHigh: entry.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    bitmap.size = NSSize(width: entry.pixels, height: entry.pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    source.draw(
        in: NSRect(x: 0, y: 0, width: entry.pixels, height: entry.pixels),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    chunks.append(entry.type.data(using: .ascii)!)
    chunks.append(bigEndianData(UInt32(data.count + 8)))
    chunks.append(data)
}

var icon = Data("icns".utf8)
icon.append(bigEndianData(UInt32(chunks.count + 8)))
icon.append(chunks)
try icon.write(to: outputURL, options: .atomic)
