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

  // Body on Apple's 1024 grid: an 824 pt squircle-ish rounded rect with a soft drop shadow.
  let body = CGPath(
    roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 186,
    cornerHeight: 186,
    transform: nil)
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0, 0, 0.35))
  ctx.addPath(body)
  ctx.setFillColor(color(0.05, 0.06, 0.17))
  ctx.fillPath()
  ctx.restoreGState()

  ctx.saveGState()
  ctx.addPath(body)
  ctx.clip()
  let background = CGGradient(
    colorsSpace: space, colors: [color(0.24, 0.26, 0.68), color(0.05, 0.06, 0.17)] as CFArray,
    locations: [0, 1])!
  ctx.drawLinearGradient(
    background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
  let glow = CGGradient(
    colorsSpace: space, colors: [color(0.45, 0.5, 1, 0.4), color(0.45, 0.5, 1, 0)] as CFArray,
    locations: [0, 1])!
  ctx.drawRadialGradient(
    glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 0, endCenter: CGPoint(x: 512, y: 512),
    endRadius: 400, options: [])
  ctx.restoreGState()

  let center = CGPoint(x: 512, y: 512)
  let radius: CGFloat = 248
  let line: CGFloat = 90

  ctx.setLineWidth(line)
  ctx.setStrokeColor(color(1, 1, 1, 0.1))
  ctx.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
  ctx.strokePath()

  // The arc runs clockwise from 12 o'clock through 80% of the circle.
  let start = CGFloat.pi / 2
  let end = start - .pi * 2 * 0.8
  // Short segments with interpolated colors stand in for a conic gradient: cyan → violet → pink.
  let stops: [[CGFloat]] = [[0.37, 0.89, 0.98], [0.63, 0.52, 0.99], [0.96, 0.45, 0.75]]
  func colorAt(_ t: CGFloat) -> CGColor {
    let x = min(max(t, 0), 1) * CGFloat(stops.count - 1)
    let i = min(Int(x), stops.count - 2)
    let f = x - CGFloat(i)
    let c = (0..<3).map { stops[i][$0] + (stops[i + 1][$0] - stops[i][$0]) * f }
    return color(c[0], c[1], c[2])
  }
  let point = { (a: CGFloat) in
    CGPoint(x: center.x + radius * cos(a), y: center.y + radius * sin(a))
  }
  ctx.setFillColor(colorAt(0))
  ctx.fillEllipse(
    in: CGRect(
      x: point(start).x - line / 2, y: point(start).y - line / 2, width: line, height: line))
  ctx.setFillColor(colorAt(1))
  ctx.fillEllipse(
    in: CGRect(x: point(end).x - line / 2, y: point(end).y - line / 2, width: line, height: line))
  ctx.setLineCap(.butt)
  let segments = 360
  for i in 0..<segments {
    let t0 = CGFloat(i) / CGFloat(segments)
    let t1 = CGFloat(i + 1) / CGFloat(segments)
    ctx.setStrokeColor(colorAt((t0 + t1) / 2))
    ctx.addArc(
      center: center, radius: radius, startAngle: start + (end - start) * t0,
      endAngle: start + (end - start) * t1 - 0.004, clockwise: true)
    ctx.strokePath()
  }

  let knob = CGPoint(x: center.x + radius * cos(end), y: center.y + radius * sin(end))
  ctx.saveGState()
  ctx.setShadow(offset: .zero, blur: 28, color: color(1, 1, 1, 0.7))
  ctx.setFillColor(color(1, 1, 1))
  ctx.fillEllipse(in: CGRect(x: knob.x - 30, y: knob.y - 30, width: 60, height: 60))
  ctx.restoreGState()

  return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

for (name, pixels) in [
  ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
  ("128x128@2x", 256),
  ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024),
] {
  try render(pixels: pixels).write(to: out.appendingPathComponent("icon_\(name).png"))
}
