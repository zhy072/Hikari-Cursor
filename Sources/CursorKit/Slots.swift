import Foundation

/// macOS 系统光标槽位(标识符表与 Mousecape 一致)。
public struct CursorSlot {
    public let identifier: String
    public let name: String     // 中文说明

    public init(_ identifier: String, _ name: String) {
        self.identifier = identifier
        self.name = name
    }
}

public enum Slots {
    public static let all: [CursorSlot] = [
        CursorSlot("com.apple.coregraphics.Arrow", "箭头(默认指针)"),
        CursorSlot("com.apple.coregraphics.IBeam", "文本 I 型光标"),
        CursorSlot("com.apple.coregraphics.IBeamXOR", "文本 I 型(反色)"),
        CursorSlot("com.apple.coregraphics.Alias", "替身/别名拖放"),
        CursorSlot("com.apple.coregraphics.Copy", "拷贝拖放"),
        CursorSlot("com.apple.coregraphics.Move", "移动"),
        CursorSlot("com.apple.coregraphics.ArrowCtx", "右键菜单箭头"),
        CursorSlot("com.apple.coregraphics.Wait", "等待(彩球)"),
        CursorSlot("com.apple.coregraphics.Empty", "空白"),
        CursorSlot("com.apple.cursor.2", "链接"),
        CursorSlot("com.apple.cursor.3", "禁止"),
        CursorSlot("com.apple.cursor.4", "忙碌(可点按)"),
        CursorSlot("com.apple.cursor.5", "拷贝拖动"),
        CursorSlot("com.apple.cursor.7", "十字线"),
        CursorSlot("com.apple.cursor.8", "十字线 2"),
        CursorSlot("com.apple.cursor.9", "相机 2"),
        CursorSlot("com.apple.cursor.10", "相机"),
        CursorSlot("com.apple.cursor.11", "抓取(握拳)"),
        CursorSlot("com.apple.cursor.12", "张开手"),
        CursorSlot("com.apple.cursor.13", "手型(链接指点)"),
        CursorSlot("com.apple.cursor.14", "计数(上)"),
        CursorSlot("com.apple.cursor.15", "计数(下)"),
        CursorSlot("com.apple.cursor.16", "计数(上下)"),
        CursorSlot("com.apple.cursor.17", "调整 西"),
        CursorSlot("com.apple.cursor.18", "调整 东"),
        CursorSlot("com.apple.cursor.19", "调整 东-西"),
        CursorSlot("com.apple.cursor.20", "单元格(反色)"),
        CursorSlot("com.apple.cursor.21", "调整 北"),
        CursorSlot("com.apple.cursor.22", "调整 南"),
        CursorSlot("com.apple.cursor.23", "调整 北-南"),
        CursorSlot("com.apple.cursor.24", "上下文菜单"),
        CursorSlot("com.apple.cursor.25", "消失(poof)"),
        CursorSlot("com.apple.cursor.26", "竖排文本光标"),
        CursorSlot("com.apple.cursor.27", "窗口边缘 东"),
        CursorSlot("com.apple.cursor.28", "窗口边缘 东-西"),
        CursorSlot("com.apple.cursor.29", "窗口角 东北"),
        CursorSlot("com.apple.cursor.30", "窗口角 东北-西南"),
        CursorSlot("com.apple.cursor.31", "窗口边缘 北"),
        CursorSlot("com.apple.cursor.32", "窗口边缘 北-南"),
        CursorSlot("com.apple.cursor.33", "窗口角 西北"),
        CursorSlot("com.apple.cursor.34", "窗口角 西北-东南"),
        CursorSlot("com.apple.cursor.35", "窗口角 东南"),
        CursorSlot("com.apple.cursor.36", "窗口边缘 南"),
        CursorSlot("com.apple.cursor.37", "窗口角 西南"),
        CursorSlot("com.apple.cursor.38", "窗口边缘 西"),
        CursorSlot("com.apple.cursor.39", "调整方块"),
        CursorSlot("com.apple.cursor.40", "帮助"),
        CursorSlot("com.apple.cursor.41", "单元格"),
        CursorSlot("com.apple.cursor.42", "放大"),
        CursorSlot("com.apple.cursor.43", "缩小"),
        CursorSlot("com.apple.coregraphics.ArrowS", "箭头(Tahoe 新版)"),
        CursorSlot("com.apple.coregraphics.IBeamS", "文本 I 型(Tahoe 新版)"),
        CursorSlot("com.apple.cursor.0", "箭头(浏览器)"),
        CursorSlot("com.apple.cursor.1", "文本 I 型(浏览器)"),
    ]

    /// 同一光标在别的子系统里的别名:
    /// - macOS 26 Tahoe 屏幕上实际显示的箭头/文本光标是 ArrowS / IBeamS
    /// - Chromium/Electron(浏览器、VSCode、微信等)用数字或命名标识符
    /// 应用主题时把别名一并注册,主题自己直接提供的槽位除外。
    public static let aliasMap: [String: [String]] = [
        "com.apple.coregraphics.Arrow": ["com.apple.coregraphics.ArrowS", "com.apple.cursor.0"],
        "com.apple.coregraphics.IBeam": ["com.apple.coregraphics.IBeamS", "com.apple.cursor.1"],
        "com.apple.coregraphics.Wait": ["com.apple.cursor.4"],
        "com.apple.coregraphics.Move": ["com.apple.cursor.39"],
        "com.apple.coregraphics.ArrowCtx": ["com.apple.cursor.24"],
        "com.apple.cursor.3": ["com.apple.coregraphics.NotAllowed"],
        "com.apple.cursor.4": ["com.apple.coregraphics.Wait"],
        "com.apple.cursor.7": ["com.apple.cursor.20"],
        "com.apple.cursor.13": ["com.apple.coregraphics.PointingHand"],
        "com.apple.cursor.19": ["com.apple.coregraphics.ResizeLeftRight"],
        "com.apple.cursor.23": ["com.apple.coregraphics.ResizeUpDown"],
        "com.apple.cursor.28": ["com.apple.coregraphics.WindowResizeEastWest"],
        "com.apple.cursor.29": ["com.apple.coregraphics.WindowResizeNortheast"],
        "com.apple.cursor.30": ["com.apple.coregraphics.WindowResizeNortheastSouthwest"],
        "com.apple.cursor.32": ["com.apple.coregraphics.WindowResizeNorthSouth"],
        "com.apple.cursor.33": ["com.apple.coregraphics.WindowResizeNorthwest"],
        "com.apple.cursor.34": ["com.apple.coregraphics.WindowResizeNorthwestSoutheast"],
        "com.apple.cursor.35": ["com.apple.coregraphics.WindowResizeSoutheast"],
        "com.apple.cursor.37": ["com.apple.coregraphics.WindowResizeSouthwest"],
        "com.apple.cursor.40": ["com.apple.coregraphics.Help"],
    ]

    public static func aliases(for identifier: String) -> [String] {
        aliasMap[identifier] ?? []
    }

    public static func name(for identifier: String) -> String {
        all.first { $0.identifier == identifier }?.name ?? identifier
    }

    // MARK: - 手动映射菜单用的分组

    public static let commonSlots = [
        "com.apple.coregraphics.Arrow",
        "com.apple.coregraphics.IBeam",
        "com.apple.cursor.13",   // 手型/链接
        "com.apple.cursor.7",    // 十字线
        "com.apple.cursor.3",    // 禁止
        "com.apple.coregraphics.Wait",
        "com.apple.coregraphics.Move",
        "com.apple.cursor.40",   // 帮助
        "com.apple.coregraphics.ArrowCtx",
        "com.apple.coregraphics.Copy",
        "com.apple.coregraphics.Alias",
    ]

    public static let resizeSlots = [
        "com.apple.cursor.23",   // 北-南
        "com.apple.cursor.19",   // 东-西
        "com.apple.cursor.34",   // 西北-东南
        "com.apple.cursor.30",   // 东北-西南
        "com.apple.cursor.17", "com.apple.cursor.18",
        "com.apple.cursor.21", "com.apple.cursor.22",
        "com.apple.cursor.39",
    ]

    public static let windowSlots = [
        "com.apple.cursor.27", "com.apple.cursor.28", "com.apple.cursor.29",
        "com.apple.cursor.31", "com.apple.cursor.32", "com.apple.cursor.33",
        "com.apple.cursor.35", "com.apple.cursor.36", "com.apple.cursor.37",
        "com.apple.cursor.38",
    ]

    public static var otherSlots: [String] {
        let used = Set(commonSlots + resizeSlots + windowSlots)
        return all.map { $0.identifier }.filter { !used.contains($0) }
    }

    /// (分组标题, 该组的标识符列表)
    public static var groups: [(title: String, identifiers: [String])] {
        [("常用", commonSlots), ("调整大小", resizeSlots),
         ("窗口边缘 / 角", windowSlots), ("其他", otherSlots)]
    }

    /// --slot 参数的简写
    public static let shorthand: [String: String] = [
        "arrow": "com.apple.coregraphics.Arrow",
        "ibeam": "com.apple.coregraphics.IBeam",
        "text": "com.apple.coregraphics.IBeam",
        "wait": "com.apple.coregraphics.Wait",
        "beachball": "com.apple.coregraphics.Wait",
        "move": "com.apple.coregraphics.Move",
        "ctx": "com.apple.coregraphics.ArrowCtx",
        "alias": "com.apple.coregraphics.Alias",
        "copy": "com.apple.coregraphics.Copy",
        "empty": "com.apple.coregraphics.Empty",
        "link": "com.apple.cursor.13",
        "hand": "com.apple.cursor.13",
        "pointing": "com.apple.cursor.13",
        "forbidden": "com.apple.cursor.3",
        "busy": "com.apple.cursor.4",
        "crosshair": "com.apple.cursor.7",
        "help": "com.apple.cursor.40",
        "resize-ns": "com.apple.cursor.23",
        "resize-ew": "com.apple.cursor.19",
        "window-ns": "com.apple.cursor.32",
        "window-ew": "com.apple.cursor.28",
        "nwse": "com.apple.cursor.34",
        "nesw": "com.apple.cursor.30",
        "closed-hand": "com.apple.cursor.11",
        "open-hand": "com.apple.cursor.12",
        "poof": "com.apple.cursor.25",
        "zoom-in": "com.apple.cursor.42",
        "zoom-out": "com.apple.cursor.43",
    ]

    /// 把 --slot 的值解析成标识符:支持简写、Windows 角色名、原始标识符
    public static func resolve(_ raw: String) -> [String]? {
        let key = raw.lowercased()
        if let id = shorthand[key] { return [id] }
        if let role = WinRole(rawValue: key) { return role.macIdentifiers }
        if raw.hasPrefix("com.apple.") { return [raw] }
        return nil
    }
}

/// Windows 光标主题的角色(按文件名识别,支持英文与常见中文命名)。
public enum WinRole: String, CaseIterable {
    case normal, help, working, busy, precision, text, handwriting
    case unavailable, vertical, horizontal, diagonal1, diagonal2
    case move, alternate, link, person, pin

    public var cnName: String {
        switch self {
        case .normal: return "正常选择"
        case .help: return "帮助选择"
        case .working: return "后台运行"
        case .busy: return "忙"
        case .precision: return "精确选择"
        case .text: return "文本选择"
        case .handwriting: return "手写"
        case .unavailable: return "不可用"
        case .vertical: return "垂直调整大小"
        case .horizontal: return "水平调整大小"
        case .diagonal1: return "对角线调整 1(↖↘)"
        case .diagonal2: return "对角线调整 2(↗↙)"
        case .move: return "移动"
        case .alternate: return "候选"
        case .link: return "链接选择"
        case .person: return "个人选择"
        case .pin: return "位置选择"
        }
    }

    /// 对应替换的 macOS 光标槽位;空数组表示 macOS 没有对应光标
    public var macIdentifiers: [String] {
        switch self {
        case .normal: return ["com.apple.coregraphics.Arrow"]
        case .help: return ["com.apple.cursor.40"]
        case .working: return ["com.apple.cursor.4"]
        case .busy: return ["com.apple.coregraphics.Wait"]
        case .precision: return ["com.apple.cursor.7"]
        case .text: return ["com.apple.coregraphics.IBeam"]
        case .unavailable: return ["com.apple.cursor.3"]
        case .vertical: return ["com.apple.cursor.23", "com.apple.cursor.32"]
        case .horizontal: return ["com.apple.cursor.19", "com.apple.cursor.28"]
        case .diagonal1: return ["com.apple.cursor.34", "com.apple.cursor.33", "com.apple.cursor.35"]
        case .diagonal2: return ["com.apple.cursor.30", "com.apple.cursor.29", "com.apple.cursor.37"]
        case .move: return ["com.apple.coregraphics.Move"]
        case .link: return ["com.apple.cursor.13"]
        case .handwriting, .alternate, .person, .pin: return []
        }
    }

    /// 识别顺序有讲究:先长关键词后短关键词,避免 handwriting 命中 hand、normal 命中 no 之类
    private static let detectionOrder: [(WinRole, [String])] = [
        (.diagonal1, ["diagonal1", "dgn1", "nwse", "对角线调整大小1", "对角线1"]),
        (.diagonal2, ["diagonal2", "dgn2", "nesw", "对角线调整大小2", "对角线2"]),
        (.vertical, ["vertical", "vert", "垂直"]),
        (.horizontal, ["horizontal", "horz", "horiz", "水平"]),
        (.handwriting, ["handwriting", "手写"]),
        (.person, ["person", "个人"]),
        (.pin, ["pin", "location", "位置"]),
        (.alternate, ["alternate", "候选"]),
        (.unavailable, ["unavailable", "forbidden", "unavail", "不可用"]),
        (.working, ["working", "appstarting", "后台"]),
        (.busy, ["busy", "wait", "忙"]),
        (.precision, ["precision", "crosshair", "cross", "精确"]),
        (.text, ["text", "ibeam", "beam", "文本"]),
        (.help, ["help", "帮助"]),
        (.move, ["move", "移动"]),
        (.link, ["link", "hand", "链接"]),
        (.normal, ["normal", "arrow", "default", "pointer", "正常"]),
    ]

    public static func detect(fromFileName fileName: String) -> WinRole? {
        let stem = (fileName as NSString).deletingPathExtension.lowercased()
        for (role, keywords) in detectionOrder {
            for kw in keywords where stem.contains(kw) {
                return role
            }
        }
        return nil
    }
}
