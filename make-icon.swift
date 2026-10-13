// Draws the app icon into an .iconset folder. Usage: swift make-icon.swift <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let space = CGColorSpace(name: CGColorSpace.displayP3)!

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
  CGColor(colorSpace: space, components: [r, g, b, a])!
}

func render(pixels: Int) -> Data {
  let ctx = CGContext(
    data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0, space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.interpolationQuality = .high
  ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

  // One solid color and a white ring mark. The icon MUST NOT use gradients.
  let body = CGPath(
    roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 186,
    cornerHeight: 186, transform: nil)
  ctx.addPath(body)
  ctx.setFillColor(color(0.04, 0.52, 1))
  ctx.fillPath()

  let center = CGPoint(x: 512, y: 512)
  let radius: CGFloat = 248
  let line: CGFloat = 90

  ctx.setLineWidth(line)
  ctx.setLineCap(.round)
  ctx.setStrokeColor(color(1, 1, 1, 0.25))
  ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
  ctx.strokePath()

  // The arc runs clockwise from 12 o'clock through 80% of the circle.
  let start = CGFloat.pi / 2
  let end = start - .pi * 2 * 0.8
  ctx.setStrokeColor(color(1, 1, 1))
  ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
  ctx.strokePath()

  return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

for (name, pixels) in [
  ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
  ("128x128@2x", 256),
  ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024),
] {
  try render(pixels: pixels).write(to: out.appendingPathComponent("icon_\(name).png"))
}
