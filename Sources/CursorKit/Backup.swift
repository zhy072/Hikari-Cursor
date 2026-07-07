import Foundation
import CoreGraphics
import ImageIO

/// 系统默认光标备份。
/// macOS 26 上 CoreCursorUnregisterAll 清不掉 com.apple.coregraphics.* 的命名注册,
/// 所以在第一次覆盖每个槽位之前,把当时的注册(即系统默认)存到本地;
/// 恢复默认 = 把备份重新注册回去。备份一旦存在就不再覆盖,
/// 避免把已替换过的光标误当成默认。
public enum DefaultBackup {

    public static var directory: URL {
        StateStore.directory.appendingPathComponent("default-backup", isDirectory: true)
    }

    private struct Meta: Codable {
        var width: Double, height: Double
        var hotspotX: Double, hotspotY: Double
        var frameCount: Int
        var frameDuration: Double
        var repCount: Int
        var missing: Bool
    }

    private static func metaURL(_ id: String) -> URL {
        directory.appendingPathComponent("\(id).json")
    }
    private static func repURL(_ id: String, _ i: Int) -> URL {
        directory.appendingPathComponent("\(id).\(i).png")
    }

    public static func hasBackup(_ id: String) -> Bool {
        FileManager.default.fileExists(atPath: metaURL(id).path)
    }

    /// 备份这些标识符当前的注册;已有备份的跳过。
    public static func ensure(_ ids: [String]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for id in Set(ids) where !hasBackup(id) {
            do {
                let r = try CGS.copyRegistered(identifier: id)
                for (i, img) in r.images.enumerated() {
                    try writePNGImage(img, to: repURL(id, i))
                }
                let meta = Meta(width: r.size.width, height: r.size.height,
                                hotspotX: r.hotspot.x, hotspotY: r.hotspot.y,
                                frameCount: r.frameCount, frameDuration: r.frameDuration,
                                repCount: r.images.count, missing: false)
                try JSONEncoder().encode(meta).write(to: metaURL(id))
            } catch {
                // 这个标识符本来就没有注册,记个标记,恢复时跳过
                let meta = Meta(width: 0, height: 0, hotspotX: 0, hotspotY: 0,
                                frameCount: 0, frameDuration: 0, repCount: 0, missing: true)
                try? JSONEncoder().encode(meta).write(to: metaURL(id))
            }
        }
    }

    /// 把所有备份重新注册回去。返回 (成功数, 无法恢复的标识符)。
    public static func restoreAll() -> (restored: Int, skipped: [String]) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return (0, []) }
        var restored = 0
        var skipped: [String] = []
        for f in files where f.pathExtension == "json" {
            let id = f.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: f),
                  let meta = try? JSONDecoder().decode(Meta.self, from: data),
                  !meta.missing, meta.repCount > 0 else {
                skipped.append(id)
                continue
            }
            var images: [CGImage] = []
            for i in 0..<meta.repCount {
                if let src = CGImageSourceCreateWithURL(repURL(id, i) as CFURL, nil),
                   let img = CGImageSourceCreateImageAtIndex(src, 0, nil) {
                    images.append(img)
                }
            }
            guard !images.isEmpty else { skipped.append(id); continue }
            let cursor = RenderedCursor(images: images,
                                        frameCount: meta.frameCount,
                                        size: CGSize(width: meta.width, height: meta.height),
                                        hotspot: CGPoint(x: meta.hotspotX, y: meta.hotspotY),
                                        frameDuration: meta.frameDuration)
            do {
                try CGS.register(identifier: id, cursor: cursor)
                restored += 1
            } catch {
                skipped.append(id)
            }
        }
        return (restored, skipped)
    }
}

func writePNGImage(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw CursorParseError.corrupt("无法创建 \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw CursorParseError.corrupt("PNG 写入失败: \(url.lastPathComponent)")
    }
}
