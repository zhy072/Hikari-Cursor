import Foundation
import CoreGraphics
import ImageIO

public enum CursorParseError: Error, CustomStringConvertible {
    case notACursorFile(String)
    case corrupt(String)

    public var description: String {
        switch self {
        case .notACursorFile(let s): return "不是有效的光标文件: \(s)"
        case .corrupt(let s): return "文件损坏或格式不支持: \(s)"
        }
    }
}

public struct CursorFrame {
    public let image: CGImage
    /// 热点坐标,像素,左上角为原点
    public let hotspotX: Int
    public let hotspotY: Int
}

/// 解析后的光标:静态 .cur 为单帧;.ani(或伪装成 .cur 的 RIFF 动画)为多帧。
public struct ParsedCursor {
    public let frames: [CursorFrame]
    /// 播放顺序,元素是 frames 的下标(已展开 ANI 的 seq 块)
    public let steps: [Int]
    /// 每步时长(秒),ANI 的 rate 不均匀时取平均
    public let stepDuration: Double
    public let isAnimated: Bool

    public init(frames: [CursorFrame], steps: [Int], stepDuration: Double, isAnimated: Bool) {
        self.frames = frames
        self.steps = steps
        self.stepDuration = stepDuration
        self.isAnimated = isAnimated
    }

    public var pixelWidth: Int { frames.first?.image.width ?? 0 }
    public var pixelHeight: Int { frames.first?.image.height ?? 0 }
}

// MARK: - 小端二进制读取

private struct BinaryReader {
    // 注意:始终用 Data(...) 重新构造,保证 startIndex == 0
    let data: Data
    var offset: Int = 0

    init(_ data: Data) { self.data = Data(data) }

    var remaining: Int { data.count - offset }

    mutating func require(_ n: Int) throws {
        guard remaining >= n else { throw CursorParseError.corrupt("数据不足(需要 \(n) 字节,剩余 \(remaining))") }
    }
    mutating func u8() throws -> Int {
        try require(1); defer { offset += 1 }
        return Int(data[offset])
    }
    mutating func u16() throws -> Int {
        try require(2); defer { offset += 2 }
        return Int(data[offset]) | Int(data[offset + 1]) << 8
    }
    mutating func u32() throws -> Int {
        try require(4); defer { offset += 4 }
        return Int(data[offset]) | Int(data[offset + 1]) << 8 | Int(data[offset + 2]) << 16 | Int(data[offset + 3]) << 24
    }
    mutating func i32() throws -> Int {
        let v = try u32()
        return v > 0x7FFF_FFFF ? v - 0x1_0000_0000 : v
    }
    mutating func fourcc() throws -> String {
        try require(4); defer { offset += 4 }
        return String(bytes: data[offset..<offset + 4], encoding: .ascii) ?? "????"
    }
    mutating func bytes(_ n: Int) throws -> Data {
        try require(n); defer { offset += n }
        return data.subdata(in: offset..<offset + n)
    }
    mutating func skip(_ n: Int) throws { try require(n); offset += n }
}

// MARK: - 解析入口

public enum CursorFile {

    /// 解析 .cur / .ani 文件。按文件内容(而不是扩展名)自动识别格式:
    /// 有些主题包把 RIFF 动画直接命名为 .cur。
    public static func parse(url: URL, firstFrameOnly: Bool = false) throws -> ParsedCursor {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw CursorParseError.notACursorFile("无法读取 \(url.path)") }
        return try parse(data: data, name: url.lastPathComponent, firstFrameOnly: firstFrameOnly)
    }

    public static func parse(data: Data, name: String, firstFrameOnly: Bool = false) throws -> ParsedCursor {
        let d = Data(data)
        if d.count >= 12,
           d[0] == 0x52, d[1] == 0x49, d[2] == 0x46, d[3] == 0x46,       // "RIFF"
           d[8] == 0x41, d[9] == 0x43, d[10] == 0x4F, d[11] == 0x4E {    // "ACON"
            return try parseANI(d, name: name, firstFrameOnly: firstFrameOnly)
        }
        if d.count >= 6, d[0] == 0, d[1] == 0, (d[2] == 1 || d[2] == 2), d[3] == 0 {
            let frame = try parseICOorCUR(d, name: name)
            return ParsedCursor(frames: [frame], steps: [0], stepDuration: 1.0, isAnimated: false)
        }
        throw CursorParseError.notACursorFile(name)
    }

    // MARK: .cur / .ico(取最佳一帧)

    private static func parseICOorCUR(_ data: Data, name: String) throws -> CursorFrame {
        var r = BinaryReader(data)
        _ = try r.u16()               // reserved
        let type = try r.u16()        // 1 = ico, 2 = cur
        let count = try r.u16()
        guard count >= 1 else { throw CursorParseError.corrupt("\(name): 目录里没有图像") }

        struct Entry { var w: Int; var h: Int; var hx: Int; var hy: Int; var size: Int; var offset: Int }
        var entries: [Entry] = []
        for _ in 0..<count {
            let bw = try r.u8(), bh = try r.u8()
            _ = try r.u8(); _ = try r.u8()          // colorCount, reserved
            let f1 = try r.u16(), f2 = try r.u16()  // cur: 热点坐标; ico: planes/bitcount
            let size = try r.u32(), off = try r.u32()
            entries.append(Entry(w: bw == 0 ? 256 : bw, h: bh == 0 ? 256 : bh,
                                 hx: type == 2 ? f1 : 0, hy: type == 2 ? f2 : 0,
                                 size: size, offset: off))
        }
        // 取面积最大的一项;面积相同时数据越大(位深越高)越好
        let best = entries.max { a, b in
            (a.w * a.h, a.size) < (b.w * b.h, b.size)
        }!
        guard best.offset >= 0, best.size > 0, best.offset + best.size <= data.count else {
            throw CursorParseError.corrupt("\(name): 图像数据越界")
        }
        let sub = data.subdata(in: best.offset..<best.offset + best.size)
        let image = try decodeEntryImage(sub, entryW: best.w, entryH: best.h, name: name)
        return CursorFrame(image: image, hotspotX: best.hx, hotspotY: best.hy)
    }

    private static func decodeEntryImage(_ d: Data, entryW: Int, entryH: Int, name: String) throws -> CGImage {
        // Vista+ 允许内嵌 PNG
        if d.count >= 4, d[0] == 0x89, d[1] == 0x50, d[2] == 0x4E, d[3] == 0x47 {
            guard let src = CGImageSourceCreateWithData(d as CFData, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                throw CursorParseError.corrupt("\(name): PNG 帧解码失败")
            }
            return img
        }
        return try decodeDIB(d, entryW: entryW, entryH: entryH, name: name)
    }

    // MARK: ICO 内嵌 DIB(BMP 无文件头)解码,支持 1/4/8/24/32 位 + AND 掩码

    private static func decodeDIB(_ d: Data, entryW: Int, entryH: Int, name: String) throws -> CGImage {
        var r = BinaryReader(d)
        let biSize = try r.u32()
        guard biSize >= 40 else { throw CursorParseError.corrupt("\(name): DIB 头过小") }
        let w = try r.i32()
        let hRaw = try r.i32()
        _ = try r.u16()                    // planes
        let bpp = try r.u16()
        let compression = try r.u32()
        _ = try r.u32(); _ = try r.i32(); _ = try r.i32()  // sizeImage, ppm x/y
        var clrUsed = try r.u32()
        _ = try r.u32()                    // clrImportant
        if biSize > 40 { try r.skip(biSize - 40) }

        guard w > 0, w <= 4096, hRaw > 0 else { throw CursorParseError.corrupt("\(name): 图像尺寸异常") }
        // ICO/CUR 中 biHeight 是 XOR+AND 的总高(双倍);个别文件不双倍
        let h: Int
        if hRaw == entryH * 2 || (entryH == 0 && hRaw % 2 == 0) { h = hRaw / 2 }
        else if hRaw == entryH { h = entryH }
        else { h = hRaw % 2 == 0 ? hRaw / 2 : hRaw }
        guard h > 0, h <= 4096 else { throw CursorParseError.corrupt("\(name): 图像高度异常") }

        if compression == 3, bpp == 32 {
            // BI_BITFIELDS:仅支持标准 BGRA 掩码
            let rm = try r.u32(), gm = try r.u32(), bm = try r.u32()
            guard rm == 0x00FF0000, gm == 0x0000FF00, bm == 0x000000FF else {
                throw CursorParseError.corrupt("\(name): 不支持的位域掩码")
            }
        } else if compression != 0 {
            throw CursorParseError.corrupt("\(name): 不支持的压缩方式 \(compression)")
        }

        var palette: [(UInt8, UInt8, UInt8)] = []
        if bpp <= 8 {
            if clrUsed == 0 { clrUsed = 1 << bpp }
            for _ in 0..<clrUsed {
                let b = try r.u8(), g = try r.u8(), rr = try r.u8()
                _ = try r.u8()
                palette.append((UInt8(rr), UInt8(g), UInt8(b)))
            }
        }

        let xorStride = ((w * bpp + 31) / 32) * 4
        let xor = try r.bytes(xorStride * h)
        let andStride = ((w + 31) / 32) * 4
        let and: Data? = r.remaining >= andStride * h ? try r.bytes(andStride * h) : nil

        var rgba = [UInt8](repeating: 0, count: w * h * 4)

        // 32 位图里 alpha 全 0 时说明作者用的是 AND 掩码而不是 alpha 通道
        var use32Alpha = false
        if bpp == 32 {
            outer: for j in 0..<h {
                let row = j * xorStride
                for x in 0..<w where xor[row + x * 4 + 3] != 0 { use32Alpha = true; break outer }
            }
        }

        xor.withUnsafeBytes { (xorBuf: UnsafeRawBufferPointer) in
            let xp = xorBuf.bindMemory(to: UInt8.self)
            for j in 0..<h {                       // j: BMP 行号,0 = 底部
                let y = h - 1 - j
                let xorRow = j * xorStride
                let andRow = j * andStride
                for x in 0..<w {
                    var red: UInt8 = 0, green: UInt8 = 0, blue: UInt8 = 0, alpha: UInt8 = 255
                    switch bpp {
                    case 32:
                        let o = xorRow + x * 4
                        blue = xp[o]; green = xp[o + 1]; red = xp[o + 2]
                        if use32Alpha { alpha = xp[o + 3] }
                    case 24:
                        let o = xorRow + x * 3
                        blue = xp[o]; green = xp[o + 1]; red = xp[o + 2]
                    case 8:
                        let idx = Int(xp[xorRow + x])
                        if idx < palette.count { (red, green, blue) = palette[idx] }
                    case 4:
                        let byte = xp[xorRow + x / 2]
                        let idx = Int(x % 2 == 0 ? byte >> 4 : byte & 0x0F)
                        if idx < palette.count { (red, green, blue) = palette[idx] }
                    case 1:
                        let byte = xp[xorRow + x / 8]
                        let idx = Int((byte >> (7 - UInt8(x % 8))) & 1)
                        if idx < palette.count { (red, green, blue) = palette[idx] }
                    default:
                        break
                    }
                    if !(bpp == 32 && use32Alpha), let and {
                        let maskByte = and[andRow + x / 8]
                        let bit = (maskByte >> (7 - UInt8(x % 8))) & 1
                        alpha = bit == 1 ? 0 : 255
                    }
                    // 预乘 alpha
                    let o = (y * w + x) * 4
                    let a = Int(alpha)
                    rgba[o] = UInt8(Int(red) * a / 255)
                    rgba[o + 1] = UInt8(Int(green) * a / 255)
                    rgba[o + 2] = UInt8(Int(blue) * a / 255)
                    rgba[o + 3] = alpha
                }
            }
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let img = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32,
                                bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: true,
                                intent: .defaultIntent) else {
            throw CursorParseError.corrupt("\(name): CGImage 创建失败")
        }
        return img
    }

    // MARK: .ani(RIFF/ACON)

    private static func parseANI(_ data: Data, name: String, firstFrameOnly: Bool) throws -> ParsedCursor {
        var r = BinaryReader(data)
        _ = try r.fourcc()            // RIFF
        _ = try r.u32()               // riff size
        _ = try r.fourcc()            // ACON

        var nFramesDeclared = 0, nSteps = 0, dispRate = 5, attributes = 1
        var rates: [Int]? = nil
        var seq: [Int]? = nil
        var frames: [CursorFrame] = []

        while r.remaining >= 8 {
            let cc = try r.fourcc()
            let size = try r.u32()
            guard size >= 0, size <= r.remaining else { break }
            let payload = try r.bytes(size)
            if size % 2 == 1 && r.remaining > 0 { try r.skip(1) }   // RIFF 块按偶数对齐

            switch cc {
            case "anih":
                var a = BinaryReader(payload)
                _ = try a.u32()                       // cbSize
                nFramesDeclared = try a.u32()
                nSteps = try a.u32()
                _ = try a.u32(); _ = try a.u32()      // iWidth, iHeight(常为 0,不可信)
                _ = try a.u32(); _ = try a.u32()      // iBitCount, nPlanes
                dispRate = try a.u32()
                attributes = try a.u32()
            case "rate":
                var a = BinaryReader(payload)
                var v: [Int] = []
                while a.remaining >= 4 { v.append(try a.u32()) }
                rates = v
            case "seq ":
                var a = BinaryReader(payload)
                var v: [Int] = []
                while a.remaining >= 4 { v.append(try a.u32()) }
                seq = v
            case "LIST":
                var l = BinaryReader(payload)
                let listType = try l.fourcc()
                guard listType == "fram" else { break }
                while l.remaining >= 8 {
                    let scc = try l.fourcc()
                    let ssize = try l.u32()
                    guard ssize >= 0, ssize <= l.remaining else { break }
                    let spayload = try l.bytes(ssize)
                    if ssize % 2 == 1 && l.remaining > 0 { try l.skip(1) }
                    if scc == "icon" {
                        guard attributes & 1 == 1 else {
                            throw CursorParseError.corrupt("\(name): 不支持原始位图帧的 ANI")
                        }
                        frames.append(try parseICOorCUR(spayload, name: name))
                        if firstFrameOnly { break }
                    }
                }
            default:
                break
            }
            if firstFrameOnly && !frames.isEmpty { break }
        }

        guard !frames.isEmpty else { throw CursorParseError.corrupt("\(name): ANI 里没有帧") }
        _ = nFramesDeclared

        if firstFrameOnly {
            return ParsedCursor(frames: frames, steps: [0], stepDuration: 1.0, isAnimated: true)
        }

        if nSteps <= 0 { nSteps = seq?.count ?? frames.count }
        var steps: [Int] = []
        var totalJiffies = 0
        for i in 0..<nSteps {
            let f = seq.map { i < $0.count ? $0[i] : i } ?? i
            guard f >= 0, f < frames.count else { continue }
            steps.append(f)
            var j = rates.map { i < $0.count ? $0[i] : dispRate } ?? dispRate
            if j <= 0 { j = 1 }
            totalJiffies += j
        }
        if steps.isEmpty { steps = Array(0..<frames.count); totalJiffies = max(dispRate, 1) * frames.count }
        let stepDuration = max(Double(totalJiffies) / Double(steps.count) / 60.0, 1.0 / 60.0)

        return ParsedCursor(frames: frames, steps: steps, stepDuration: stepDuration,
                            isAnimated: steps.count > 1)
    }
}
