#!/bin/bash
# Renders AppIcon.svg to an .iconset and packs it into AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")"

ICONSET="AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

cat > /tmp/render-icon.swift <<'SWIFT'
import AppKit
let args = CommandLine.arguments
let svgPath = args[1], outDir = args[2]
guard let image = NSImage(contentsOfFile: svgPath) else { fatalError("Cannot load \(svgPath)") }
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}
SWIFT

swiftc -O -o /tmp/render-icon /tmp/render-icon.swift 2>/dev/null || swiftc -o /tmp/render-icon /tmp/render-icon.swift
/tmp/render-icon AppIcon.svg "$ICONSET"
iconutil -c icns "$ICONSET" -o AppIcon.icns
rm -rf "$ICONSET" /tmp/render-icon /tmp/render-icon.swift
echo "Wrote $(pwd)/AppIcon.icns"
