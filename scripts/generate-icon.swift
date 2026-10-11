import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

func drawIcon(size: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    NSColor(calibratedRed: 0.89, green: 0.92, blue: 0.84, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 54, y: 54, width: 916, height: 916), xRadius: 215, yRadius: 215).fill()
    NSColor(calibratedRed: 0.27, green: 0.39, blue: 0.29, alpha: 1).setStroke()
    let envelope = NSBezierPath(roundedRect: NSRect(x: 248, y: 315, width: 528, height: 362), xRadius: 42, yRadius: 42)
    envelope.lineWidth = 28
    envelope.stroke()
    let flap = NSBezierPath()
    flap.move(to: NSPoint(x: 260, y: 655))
    flap.line(to: NSPoint(x: 512, y: 465))
    flap.line(to: NSPoint(x: 764, y: 655))
    flap.lineWidth = 28
    flap.lineJoinStyle = .round
    flap.stroke()
    NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.91, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 635, y: 587, width: 220, height: 220)).fill()
    NSColor(calibratedRed: 0.27, green: 0.39, blue: 0.29, alpha: 1).setFill()
    let star = NSBezierPath()
    star.move(to: NSPoint(x: 745, y: 782))
    star.curve(to: NSPoint(x: 830, y: 697), controlPoint1: NSPoint(x: 757, y: 713), controlPoint2: NSPoint(x: 761, y: 709))
    star.curve(to: NSPoint(x: 745, y: 612), controlPoint1: NSPoint(x: 761, y: 685), controlPoint2: NSPoint(x: 757, y: 681))
    star.curve(to: NSPoint(x: 660, y: 697), controlPoint1: NSPoint(x: 733, y: 681), controlPoint2: NSPoint(x: 729, y: 685))
    star.curve(to: NSPoint(x: 745, y: 782), controlPoint1: NSPoint(x: 729, y: 709), controlPoint2: NSPoint(x: 733, y: 713))
    star.fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        try drawIcon(size: points * scale).write(to: destination.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
