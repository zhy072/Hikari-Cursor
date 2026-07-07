import Foundation
import CoreGraphics

/// 渲染成 WindowServer 需要的形式:每个缩放比例一张"竖条"图,
/// 动画帧从上到下依次排列(与 Mousecape cape 的表示一致)。
public struct RenderedCursor {
    public let images: [CGImage]     // 每个缩放比例(1x、2x)各一张竖条图
    public let frameCount: Int
    public let size: CGSize          // 单帧显示尺寸(pt)
    public let hotspot: CGPoint      // pt
    public let frameDuration: Double // 秒

    public init(images: [CGImage], frameCount: Int, size: CGSize,
                hotspot: CGPoint, frameDuration: Double) {
        self.images = images
        self.frameCount = frameCount
        self.size = size
        self.hotspot = hotspot
        self.frameDuration = frameDuration
    }
}

public enum StripBuilder {

    /// WindowServer(实测 macOS 26)最多接受 24 帧动画,超出的等间隔抽帧
    public static let maxFrames = 24

    /// pointSize:光标显示宽度(pt)。源图会被高质量缩放,热点按比例换算。
    public static func render(_ cursor: ParsedCursor,
                              pointSize: CGFloat,
                              scales: [CGFloat] = [1, 2]) throws -> RenderedCursor {
        guard let first = cursor.frames.first else {
            throw CursorParseError.corrupt("没有可用帧")
        }
        let srcW = CGFloat(cursor.frames.map { $0.image.width }.max() ?? first.image.width)
        let srcH = CGFloat(cursor.frames.map { $0.image.height }.max() ?? first.image.height)
        guard srcW > 0, srcH > 0 else { throw CursorParseError.corrupt("帧尺寸为 0") }

        let ptW = pointSize
        let ptH = (pointSize * srcH / srcW).rounded()

        var steps = cursor.steps.isEmpty ? [0] : cursor.steps
        var stepDuration = cursor.isAnimated ? cursor.stepDuration : 1.0
        if steps.count > Self.maxFrames {
            // 抽帧降到上限,循环总时长不变
            let n = steps.count
            let total = stepDuration * Double(n)
            steps = (0..<Self.maxFrames).map { steps[$0 * n / Self.maxFrames] }
            stepDuration = total / Double(Self.maxFrames)
        }

        var strips: [CGImage] = []
        for scale in scales {
            let cellW = Int(ptW * scale), cellH = Int(ptH * scale)
            guard cellW > 0, cellH > 0,
                  let ctx = CGContext(data: nil, width: cellW, height: cellH * steps.count,
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw CursorParseError.corrupt("画布创建失败")
            }
            ctx.interpolationQuality = .high
            let totalH = cellH * steps.count
            for (i, frameIndex) in steps.enumerated() {
                let img = cursor.frames[min(frameIndex, cursor.frames.count - 1)].image
                // CG 坐标系原点在左下:第 i 步画在从顶部数第 i 格
                let rect = CGRect(x: 0, y: totalH - (i + 1) * cellH, width: cellW, height: cellH)
                ctx.draw(img, in: rect)
            }
            guard let strip = ctx.makeImage() else {
                throw CursorParseError.corrupt("竖条图生成失败")
            }
            strips.append(strip)
        }

        let hx = min(max(CGFloat(first.hotspotX) * ptW / srcW, 0), ptW - 1)
        let hy = min(max(CGFloat(first.hotspotY) * ptH / srcH, 0), ptH - 1)

        return RenderedCursor(images: strips,
                              frameCount: steps.count,
                              size: CGSize(width: ptW, height: ptH),
                              hotspot: CGPoint(x: hx, y: hy),
                              frameDuration: stepDuration)
    }
}
