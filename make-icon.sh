#!/usr/bin/env bash
# Generates dist/AppIcon.icns for the Amateur Radio Suite from a 1024x1024 source.
# With no source supplied, draws a placeholder: radio-wave arcs over an antenna
# mast, in the LP-500/700 dark-LCD palette (teal/blue on near-black).
#
# Usage: ./make-icon.sh [path/to/source.png]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
DIST="$ROOT/dist"
ICONSET="$DIST/AppIcon.iconset"
SOURCE="${1:-$DIST/AppIcon-source.png}"

mkdir -p "$DIST" "$ICONSET"

generate_placeholder() {
    cat > "$DIST/_icon.swift" <<'SWIFT'
import AppKit
import CoreGraphics

let size = CGSize(width: 1024, height: 1024)
let cs = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// Rounded-rect background gradient (matches the LP apps' aesthetic).
let grad = CGGradient(colorsSpace: cs,
    colors: [CGColor(red: 0x14/255, green: 0x1b/255, blue: 0x25/255, alpha: 1),
             CGColor(red: 0x06/255, green: 0x09/255, blue: 0x0c/255, alpha: 1)] as CFArray,
    locations: [0, 1])!
ctx.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: size),
                   cornerWidth: 200, cornerHeight: 200, transform: nil))
ctx.clip()
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 1024), end: CGPoint(x: 0, y: 0), options: [])

// Antenna mast.
ctx.setFillColor(CGColor(red: 0x4a/255, green: 0xd6/255, blue: 0xa3/255, alpha: 1))
ctx.addPath(CGPath(roundedRect: CGRect(x: 496, y: 200, width: 32, height: 360),
                   cornerWidth: 16, cornerHeight: 16, transform: nil))
ctx.fillPath()
// Base feet.
ctx.setLineWidth(28); ctx.setLineCap(.round)
ctx.setStrokeColor(CGColor(red: 0x4a/255, green: 0xd6/255, blue: 0xa3/255, alpha: 1))
ctx.move(to: CGPoint(x: 420, y: 210)); ctx.addLine(to: CGPoint(x: 512, y: 300))
ctx.addLine(to: CGPoint(x: 604, y: 210)); ctx.strokePath()

// Radio-wave arcs fanning up from the apex.
let apex = CGPoint(x: 512, y: 560)
ctx.setLineCap(.round)
let waves: [(CGFloat, CGFloat)] = [(150, 0.95), (260, 0.7), (370, 0.45)]
for (r, a) in waves {
    ctx.setLineWidth(44)
    ctx.setStrokeColor(CGColor(red: 0x6c/255, green: 0xb6/255, blue: 0xff/255, alpha: a))
    ctx.addArc(center: apex, radius: r,
               startAngle: .pi * 0.18, endAngle: .pi * 0.82, clockwise: false)
    ctx.strokePath()
}
// Emitter dot at the apex.
ctx.setFillColor(CGColor(red: 0x6c/255, green: 0xb6/255, blue: 0xff/255, alpha: 1))
ctx.addPath(CGPath(ellipseIn: CGRect(x: apex.x - 34, y: apex.y - 34, width: 68, height: 68), transform: nil))
ctx.fillPath()

guard let img = ctx.makeImage() else { exit(1) }
let data = NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
    swift "$DIST/_icon.swift" "$1"
    rm -f "$DIST/_icon.swift"
}

if [ ! -f "$SOURCE" ]; then
    echo "==> Generating placeholder icon at $SOURCE"
    generate_placeholder "$SOURCE"
fi

echo "==> Generating .iconset from $SOURCE"
for sz in 16 32 128 256 512; do
    sips -z "$sz" "$sz" "$SOURCE" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
    dbl=$((sz * 2))
    sips -z "$dbl" "$dbl" "$SOURCE" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done
sips -z 1024 1024 "$SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET" -o "$DIST/AppIcon.icns"
echo "==> Wrote $DIST/AppIcon.icns"
