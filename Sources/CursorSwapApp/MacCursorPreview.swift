import AppKit

/// 生成代表某个 macOS 光标槽位的预览小图,给映射菜单当图标用。
/// 优先用系统 NSCursor 的真实光标位图;系统没有对应 NSCursor 的,用 SF Symbol 兜底。
enum MacCursorGlyph {
    private static var cache: [String: NSImage] = [:]

    static func image(for identifier: String, size: CGFloat = 16) -> NSImage? {
        let key = "\(identifier)@\(size)"
        if let cached = cache[key] { return cached }

        var result: NSImage?
        if let base = nsCursor(for: identifier)?.image {
            // NSCursor 图有各自尺寸,按比例缩到 size 见方以内,别拉伸变形
            let copy = (base.copy() as? NSImage) ?? base
            let w = base.size.width, h = base.size.height
            if w > 0, h > 0 {
                let r = min(size / w, size / h)
                copy.size = NSSize(width: w * r, height: h * r)
            }
            result = copy
        } else if let symbol = sfSymbol(for: identifier) {
            result = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        } else {
            result = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil)
        }
        cache[key] = result
        return result
    }

    private static func nsCursor(for id: String) -> NSCursor? {
        switch id {
        case "com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.cursor.0":
            return .arrow
        case "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS",
             "com.apple.coregraphics.IBeamXOR", "com.apple.cursor.1":
            return .iBeam
        case "com.apple.cursor.26": return .iBeamCursorForVerticalLayout
        case "com.apple.cursor.13": return .pointingHand
        case "com.apple.cursor.11": return .closedHand
        case "com.apple.cursor.12": return .openHand
        case "com.apple.cursor.7", "com.apple.cursor.8": return .crosshair
        case "com.apple.cursor.3": return .operationNotAllowed
        case "com.apple.coregraphics.Alias", "com.apple.cursor.2": return .dragLink
        case "com.apple.coregraphics.Copy", "com.apple.cursor.5": return .dragCopy
        case "com.apple.coregraphics.ArrowCtx", "com.apple.cursor.24": return .contextualMenu
        case "com.apple.cursor.25": return .disappearingItem
        case "com.apple.cursor.17": return .resizeLeft
        case "com.apple.cursor.18": return .resizeRight
        case "com.apple.cursor.19", "com.apple.cursor.28": return .resizeLeftRight
        case "com.apple.cursor.21": return .resizeUp
        case "com.apple.cursor.22": return .resizeDown
        case "com.apple.cursor.23", "com.apple.cursor.32": return .resizeUpDown
        default: return nil
        }
    }

    private static func sfSymbol(for id: String) -> String? {
        switch id {
        case "com.apple.coregraphics.Wait", "com.apple.cursor.4": return "hourglass"
        case "com.apple.coregraphics.Move": return "arrow.up.and.down.and.arrow.left.and.right"
        case "com.apple.coregraphics.Empty": return "cursorarrow.slash"
        case "com.apple.cursor.40": return "questionmark.circle"
        case "com.apple.cursor.41", "com.apple.cursor.20": return "squareshape"
        case "com.apple.cursor.42": return "plus.magnifyingglass"
        case "com.apple.cursor.43": return "minus.magnifyingglass"
        case "com.apple.cursor.14", "com.apple.cursor.15", "com.apple.cursor.16": return "hand.point.up"
        case "com.apple.cursor.9", "com.apple.cursor.10": return "camera"
        case "com.apple.cursor.39": return "arrow.up.left.and.down.right.magnifyingglass"
        // 窗口角
        case "com.apple.cursor.29", "com.apple.cursor.35": return "arrow.up.right.and.arrow.down.left"
        case "com.apple.cursor.30", "com.apple.cursor.34": return "arrow.up.left.and.arrow.down.right"
        case "com.apple.cursor.33", "com.apple.cursor.37": return "arrow.up.left.and.arrow.down.right"
        // 窗口边缘
        case "com.apple.cursor.27", "com.apple.cursor.38": return "arrow.left.and.right"
        case "com.apple.cursor.31", "com.apple.cursor.36": return "arrow.up.and.down"
        default: return nil
        }
    }
}
