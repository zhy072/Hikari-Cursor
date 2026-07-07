import Foundation
import CoreGraphics

/// 通过 dlsym 调用 SkyLight/CoreGraphics 私有接口,全局注册系统光标。
/// 与 Mousecape 的 mousecloak 使用同一组 API:
///   CGError CGSRegisterCursorWithImages(cid, name, setGlobally, instantly,
///                                       size, hotspot, frameCount, frameDuration,
///                                       imageArray, &seed)
public enum CGSBridgeError: Error, CustomStringConvertible {
    case symbolMissing(String)
    case connectionFailed
    case callFailed(String, Int32)

    public var description: String {
        switch self {
        case .symbolMissing(let s):
            return "系统私有接口 \(s) 不存在(此 macOS 版本可能已移除该接口)"
        case .connectionFailed:
            return "无法连接 WindowServer(需要在图形登录会话中运行)"
        case .callFailed(let what, let code):
            return "\(what) 调用失败,错误码 \(code)"
        }
    }
}

public enum CGS {

    private static let libraryPaths = [
        "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
        "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices",
        "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics",
    ]

    private static let handles: [UnsafeMutableRawPointer] = {
        libraryPaths.compactMap { dlopen($0, RTLD_NOW) }
    }()

    private static func symbol(_ name: String) -> UnsafeMutableRawPointer? {
        for h in handles {
            if let s = dlsym(h, name) { return s }
        }
        // RTLD_DEFAULT
        return dlsym(UnsafeMutableRawPointer(bitPattern: -2), name)
    }

    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias RegisterFn = @convention(c) (
        Int32, UnsafePointer<CChar>, Bool, Bool,
        CGSize, CGPoint, UInt, CGFloat,
        CFArray, UnsafeMutablePointer<Int32>
    ) -> Int32
    private typealias UnregisterAllFn = @convention(c) (Int32) -> Int32
    private typealias SetRegisteredFn = @convention(c) (
        Int32, UnsafePointer<CChar>, UnsafeMutablePointer<Int32>
    ) -> Int32

    public static func connectionID() -> Int32? {
        guard let s = symbol("CGSMainConnectionID") else { return nil }
        let cid = unsafeBitCast(s, to: MainConnectionFn.self)()
        return cid != 0 ? cid : nil
    }

    /// 检查各私有符号是否可用,用于 doctor 命令
    public static func diagnostics() -> [(name: String, ok: Bool)] {
        var result: [(String, Bool)] = [
            ("CGSMainConnectionID", symbol("CGSMainConnectionID") != nil),
            ("CGSRegisterCursorWithImages", symbol("CGSRegisterCursorWithImages") != nil),
            ("CGSSetRegisteredCursor", symbol("CGSSetRegisteredCursor") != nil),
            ("CoreCursorUnregisterAll", symbol("CoreCursorUnregisterAll") != nil),
        ]
        result.append(("WindowServer 连接", connectionID() != nil))
        return result
    }

    /// 全局注册(替换)一个系统光标。
    public static func register(identifier: String, cursor: RenderedCursor) throws {
        guard let sym = symbol("CGSRegisterCursorWithImages") else {
            throw CGSBridgeError.symbolMissing("CGSRegisterCursorWithImages")
        }
        guard let cid = connectionID() else { throw CGSBridgeError.connectionFailed }
        let fn = unsafeBitCast(sym, to: RegisterFn.self)
        var seed: Int32 = 0
        let err = identifier.withCString { cName in
            fn(cid, cName, true, true,
               cursor.size, cursor.hotspot,
               UInt(cursor.frameCount), cursor.frameDuration,
               cursor.images as CFArray, &seed)
        }
        guard err == 0 else { throw CGSBridgeError.callFailed("注册光标 \(identifier)", err) }

        // 注册只更新表项,还要激活才会立即显示(MaCursor 同款做法)
        if let setSym = symbol("CGSSetRegisteredCursor") {
            var activateSeed: Int32 = 0
            _ = identifier.withCString { cName in
                unsafeBitCast(setSym, to: SetRegisteredFn.self)(cid, cName, &activateSeed)
            }
        }
    }

    private typealias CopyImagesFn = @convention(c) (
        Int32, UnsafePointer<CChar>,
        UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>,
        UnsafeMutablePointer<UInt>, UnsafeMutablePointer<CGFloat>,
        UnsafeMutablePointer<Unmanaged<CFArray>?>
    ) -> Int32

    /// 读回 WindowServer 中当前注册的光标(调试用)。
    public static func copyRegistered(identifier: String) throws -> (images: [CGImage], size: CGSize, hotspot: CGPoint, frameCount: Int, frameDuration: Double) {
        guard let sym = symbol("CGSCopyRegisteredCursorImages") else {
            throw CGSBridgeError.symbolMissing("CGSCopyRegisteredCursorImages")
        }
        guard let cid = connectionID() else { throw CGSBridgeError.connectionFailed }
        let fn = unsafeBitCast(sym, to: CopyImagesFn.self)
        var size = CGSize.zero
        var hotspot = CGPoint.zero
        var frameCount: UInt = 0
        var duration: CGFloat = 0
        var arrayRef: Unmanaged<CFArray>? = nil
        let err = identifier.withCString { cName in
            fn(cid, cName, &size, &hotspot, &frameCount, &duration, &arrayRef)
        }
        guard err == 0, let arr = arrayRef?.takeRetainedValue() else {
            throw CGSBridgeError.callFailed("读取光标 \(identifier)", err)
        }
        let images = (arr as! [CGImage])
        return (images, size, hotspot, Int(frameCount), Double(duration))
    }

    private typealias GlobalCursorSizeFn = @convention(c) (Int32, UnsafeMutablePointer<Int32>) -> Int32
    private typealias GlobalCursorDataFn = @convention(c) (
        Int32, UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>,
        UnsafeMutablePointer<CGSize>, UnsafeMutablePointer<CGPoint>,
        UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>,
        UnsafeMutablePointer<Int32>
    ) -> Int32

    /// 读取 WindowServer 当前正在屏幕上显示的光标图像(调试/验证用)。
    public static func currentDisplayedCursor() throws -> CGImage {
        guard let sizeSym = symbol("CGSGetGlobalCursorDataSize"),
              let dataSym = symbol("CGSGetGlobalCursorData") else {
            throw CGSBridgeError.symbolMissing("CGSGetGlobalCursorData")
        }
        guard let cid = connectionID() else { throw CGSBridgeError.connectionFailed }
        var dataSize: Int32 = 0
        var err = unsafeBitCast(sizeSym, to: GlobalCursorSizeFn.self)(cid, &dataSize)
        guard err == 0, dataSize > 0 else { throw CGSBridgeError.callFailed("读取光标数据大小", err) }

        var buf = [UInt8](repeating: 0, count: Int(dataSize))
        var outSize = CGSize.zero
        var hotspot = CGPoint.zero
        var depth: Int32 = 0, components: Int32 = 0, bpc: Int32 = 0, rowBytes: Int32 = 0
        err = buf.withUnsafeMutableBytes { raw in
            unsafeBitCast(dataSym, to: GlobalCursorDataFn.self)(
                cid, raw.baseAddress!, &dataSize, &outSize, &hotspot,
                &depth, &components, &bpc, &rowBytes)
        }
        guard err == 0 else { throw CGSBridgeError.callFailed("读取当前光标", err) }

        _ = (depth, components, bpc)   // 各版本返回的含义不一致,按 32bpp 自行推算
        let w = Int(outSize.width), h = Int(outSize.height)
        guard w > 0, h > 0, h <= Int(dataSize) else {
            throw CGSBridgeError.callFailed("当前光标尺寸异常(\(w)×\(h))", -1)
        }
        let stride = Int(dataSize) / h
        guard stride >= w * 4, rowBytes >= 0,
              let provider = CGDataProvider(data: Data(buf.prefix(stride * h)) as CFData),
              let img = CGImage(width: w, height: h, bitsPerComponent: 8,
                                bitsPerPixel: 32, bytesPerRow: stride,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                provider: provider, decode: nil, shouldInterpolate: false,
                                intent: .defaultIntent) else {
            throw CGSBridgeError.callFailed("当前光标图像构建失败(\(w)×\(h))", -1)
        }
        return img
    }

    private typealias CoreCursorSetFn = @convention(c) (Int32, Int32) -> Int32

    /// 反注册所有核心光标并强制刷新显示。
    /// 注意:macOS 26 上这不会清掉 com.apple.coregraphics.* 的命名注册,
    /// 那部分靠 DefaultBackup 重新注册备份来恢复。
    public static func unregisterAll() throws {
        guard let cid = connectionID() else { throw CGSBridgeError.connectionFailed }
        guard let sym = symbol("CoreCursorUnregisterAll") else {
            throw CGSBridgeError.symbolMissing("CoreCursorUnregisterAll")
        }
        let err = unsafeBitCast(sym, to: UnregisterAllFn.self)(cid)
        guard err == 0 else { throw CGSBridgeError.callFailed("恢复默认光标", err) }

        // 逐个核心光标强制刷新,让屏幕立刻回到默认样式(MaCursor 同款),
        // 最后停在 0 号(箭头)
        if let setSym = symbol("CoreCursorSet") {
            let fn = unsafeBitCast(setSym, to: CoreCursorSetFn.self)
            for x: Int32 in stride(from: 43, through: 0, by: -1) { _ = fn(cid, x) }
        }
    }
}
