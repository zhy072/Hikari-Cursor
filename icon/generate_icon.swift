import CoreGraphics
import ImageIO
import Foundation

// Hikari-Cursor 图标 v3「星夜光标」(用户定稿):
// 深夜空渐变 + 星尘 + 四芒星 + 多层辉光的白色箭头,呼应 Hikari(光)。

let S: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                    bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

// 圆角方块(macOS 图标圆角比例)
let cornerRadius = S * 0.224
ctx.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: S, height: S),
                   cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
ctx.clip()

// 夜空渐变(底深顶亮)
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [rgba(13, 10, 40), rgba(56, 40, 110)] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: 1024), options: [])

// 星尘(固定伪随机,保证每次生成一致)
var seed: UInt64 = 42
func rnd() -> CGFloat {
    seed = seed &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((seed >> 33) % 10000) / 10000
}
for _ in 0..<70 {
    let x = rnd() * 1024, y = rnd() * 1024
    let r = 1.2 + rnd() * 2.6
    ctx.setFillColor(rgba(255, 255, 255, 0.15 + rnd() * 0.55))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// 四芒星(内凹曲线)
func sparklePath(center: CGPoint, r: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: center.x, y: center.y + r))
    p.addQuadCurve(to: CGPoint(x: center.x + r, y: center.y), control: center)
    p.addQuadCurve(to: CGPoint(x: center.x, y: center.y - r), control: center)
    p.addQuadCurve(to: CGPoint(x: center.x - r, y: center.y), control: center)
    p.addQuadCurve(to: CGPoint(x: center.x, y: center.y + r), control: center)
    return p
}
for (c, r, a) in [(CGPoint(x: 812, y: 830), CGFloat(58), 0.9),
                  (CGPoint(x: 890, y: 680), CGFloat(24), 0.6),
                  (CGPoint(x: 160, y: 200), CGFloat(34), 0.55)] {
    ctx.setFillColor(rgba(226, 214, 255, a))
    ctx.addPath(sparklePath(center: c, r: r))
    ctx.fillPath()
}

// 箭头(尖朝左上)
func cursorPath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 250, y: 830))
    p.addLine(to: CGPoint(x: 250, y: 240))
    p.addLine(to: CGPoint(x: 390, y: 420))
    p.addLine(to: CGPoint(x: 510, y: 190))
    p.addLine(to: CGPoint(x: 600, y: 230))
    p.addLine(to: CGPoint(x: 480, y: 450))
    p.addLine(to: CGPoint(x: 710, y: 450))
    p.closeSubpath()
    return p
}

// 多层辉光 + 白色核心
let path = cursorPath()
for (blur, color) in [(CGFloat(140), rgba(124, 92, 255, 0.85)),
                      (90, rgba(150, 120, 255, 0.9)),
                      (48, rgba(196, 160, 255, 0.95))] {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: blur, color: color)
    ctx.addPath(path)
    ctx.setFillColor(rgba(255, 255, 255))
    ctx.fillPath()
    ctx.restoreGState()
}
ctx.addPath(path)
ctx.setFillColor(rgba(255, 255, 255))
ctx.fillPath()

guard let image = ctx.makeImage() else { fatalError("makeImage failed") }
let outURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("dest failed")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outURL.path)")
