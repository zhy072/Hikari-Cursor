import AppKit

/// 生成代表某个 macOS 光标槽位的预览小图,给映射菜单当图标用。
///
/// 只用 SF Symbol,**不**用 `NSCursor.xxx.image`:后者返回的是 WindowServer 当前
/// 注册的光标,而本工具会全局替换这些光标,于是预览图会变成"已应用的主题光标"
/// 而不是中性的系统图标——那正是"选了新目标预览却还是上一个款式"的根因。
enum MacCursorGlyph {
    static func symbolName(for identifier: String) -> String {
        switch identifier {
        case "com.apple.coregraphics.Arrow", "com.apple.coregraphics.ArrowS", "com.apple.cursor.0":
            return "cursorarrow"
        case "com.apple.coregraphics.IBeam", "com.apple.coregraphics.IBeamS",
             "com.apple.coregraphics.IBeamXOR", "com.apple.cursor.1", "com.apple.cursor.26":
            return "character.cursor.ibeam"
        case "com.apple.cursor.13": return "hand.point.up.left.fill"   // 手型/链接
        case "com.apple.cursor.11": return "hand.raised.fill"          // 抓取(握拳)
        case "com.apple.cursor.12": return "hand.raised"               // 张开手
        case "com.apple.cursor.14", "com.apple.cursor.15", "com.apple.cursor.16":
            return "hand.point.up"                                     // 计数
        case "com.apple.cursor.7", "com.apple.cursor.8": return "scope"        // 十字线
        case "com.apple.cursor.3": return "nosign"                     // 禁止
        case "com.apple.coregraphics.Wait", "com.apple.cursor.4": return "hourglass"  // 等待/忙
        case "com.apple.coregraphics.Move": return "arrow.up.and.down.and.arrow.left.and.right"
        case "com.apple.cursor.40": return "questionmark"              // 帮助
        case "com.apple.coregraphics.ArrowCtx", "com.apple.cursor.24":
            return "filemenu.and.cursorarrow"                          // 右键菜单
        case "com.apple.coregraphics.Alias", "com.apple.cursor.2": return "arrowshape.turn.up.right"
        case "com.apple.coregraphics.Copy", "com.apple.cursor.5": return "plus.rectangle.on.rectangle"
        case "com.apple.cursor.25": return "sparkles"                  // 消失(poof)
        case "com.apple.cursor.9", "com.apple.cursor.10": return "camera"
        case "com.apple.coregraphics.Empty": return "cursorarrow.slash"
        case "com.apple.cursor.41", "com.apple.cursor.20": return "squareshape"        // 单元格
        case "com.apple.cursor.42": return "plus.magnifyingglass"      // 放大
        case "com.apple.cursor.43": return "minus.magnifyingglass"     // 缩小

        // 调整大小 / 窗口边缘·角
        case "com.apple.cursor.17": return "arrow.left"
        case "com.apple.cursor.18": return "arrow.right"
        case "com.apple.cursor.19", "com.apple.cursor.28", "com.apple.cursor.27", "com.apple.cursor.38":
            return "arrow.left.and.right"
        case "com.apple.cursor.21": return "arrow.up"
        case "com.apple.cursor.22": return "arrow.down"
        case "com.apple.cursor.23", "com.apple.cursor.32", "com.apple.cursor.31", "com.apple.cursor.36":
            return "arrow.up.and.down"
        case "com.apple.cursor.39", "com.apple.cursor.33", "com.apple.cursor.34":
            return "arrow.up.left.and.arrow.down.right"
        case "com.apple.cursor.29", "com.apple.cursor.30", "com.apple.cursor.35", "com.apple.cursor.37":
            return "arrow.up.right.and.arrow.down.left"

        default: return "cursorarrow"
        }
    }
}
