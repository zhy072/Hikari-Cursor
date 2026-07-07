import Foundation
import CoreGraphics
import ImageIO
import CursorKit

let helpText = """
mousecur — 在 macOS 上使用 Windows 鼠标指针(.cur / .ani)

用法:
  mousecur apply <主题文件夹>  [--size N]           按文件名自动映射并应用整套主题
  mousecur apply <光标文件>    [--slot 槽位] [--size N]   应用单个光标
  mousecur reset                                   恢复 macOS 默认光标
  mousecur reapply [--wait]                        重新应用上次保存的主题
  mousecur agent install|uninstall                 登录时自动重新应用(LaunchAgent)
  mousecur info <光标文件>                          查看文件信息(帧数、尺寸、热点)
  mousecur preview <光标文件> [--out 目录]          把每一帧导出成 PNG
  mousecur slots                                   列出可用的 macOS 光标槽位
  mousecur doctor                                  检查系统接口可用性

说明:
  --size   光标显示宽度(pt),默认 32
  --slot   可用简写(arrow/ibeam/wait/link/busy/forbidden/crosshair/help/move…)、
           Windows 角色名(normal/text/busy…)或原始标识符 com.apple.*
  提示: 光标替换对整个系统生效,注销或重启后失效;
        用 `mousecur agent install` 可在每次登录时自动恢复。
"""

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(("错误: " + msg + "\n").data(using: .utf8)!)
    exit(1)
}

func optionValue(_ args: inout [String], _ name: String) -> String? {
    guard let i = args.firstIndex(of: name) else { return nil }
    guard i + 1 < args.count else { fail("\(name) 缺少参数值") }
    let v = args[i + 1]
    args.removeSubrange(i...(i + 1))
    return v
}

func flag(_ args: inout [String], _ name: String) -> Bool {
    guard let i = args.firstIndex(of: name) else { return false }
    args.remove(at: i)
    return true
}

func parseSize(_ args: inout [String]) -> CGFloat {
    guard let raw = optionValue(&args, "--size") else { return 32 }
    guard let v = Double(raw), v >= 8, v <= 128 else { fail("--size 应为 8~128 之间的数字") }
    return CGFloat(v)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw CursorParseError.corrupt("无法创建 \(url.lastPathComponent)")
    }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        throw CursorParseError.corrupt("PNG 写入失败: \(url.lastPathComponent)")
    }
}

func describe(_ url: URL) throws {
    let parsed = try CursorFile.parse(url: url)
    let kind = parsed.isAnimated ? "动画光标(ANI)" : "静态光标(CUR)"
    print("文件: \(url.lastPathComponent)")
    print("类型: \(kind)")
    print("尺寸: \(parsed.pixelWidth)×\(parsed.pixelHeight) 像素")
    print("帧数: \(parsed.frames.count) 帧 / \(parsed.steps.count) 步")
    if parsed.isAnimated {
        print(String(format: "帧率: 每步 %.0f 毫秒(约 %.1f fps)",
                     parsed.stepDuration * 1000, 1.0 / parsed.stepDuration))
    }
    if let f = parsed.frames.first {
        print("热点: (\(f.hotspotX), \(f.hotspotY))")
    }
    if let role = WinRole.detect(fromFileName: url.lastPathComponent) {
        let ids = role.macIdentifiers
        let mapped = ids.isEmpty ? "macOS 无对应光标,整套应用时会跳过"
                                 : ids.map { Slots.name(for: $0) }.joined(separator: "、")
        print("识别角色: \(role.cnName) → \(mapped)")
    }
}

func applyThemeFolder(_ folder: URL, pointSize: CGFloat) {
    let entries = Theme.scan(folder: folder)
    if entries.isEmpty { fail("目录里没有找到 .cur / .ani 文件: \(folder.path)") }

    print("在 \(folder.lastPathComponent) 里找到 \(entries.count) 个光标文件,大小 \(Int(pointSize)) pt:\n")
    var items: [AppliedItem] = []
    var skipped: [ThemeEntry] = []
    for e in entries {
        if e.identifiers.isEmpty { skipped.append(e); continue }
        items.append(AppliedItem(file: e.url.path, identifiers: e.identifiers))
    }

    let results = Applier.applyAll(items: items, pointSize: pointSize)
    var okCount = 0
    for r in results {
        let name = (r.item.file as NSString).lastPathComponent
        let slots = r.item.identifiers.map { Slots.name(for: $0) }.joined(separator: "、")
        if let frames = r.frameCount {
            let anim = frames > 1 ? "\(frames) 帧动画" : "静态"
            print("  ✓ \(name)(\(anim)) → \(slots)")
            okCount += 1
        } else if let err = r.error {
            print("  ✗ \(name): \(err)")
        }
    }
    for e in skipped {
        let roleDesc = e.role.map { "\($0.cnName),macOS 无对应光标" } ?? "无法识别角色"
        print("  - 跳过 \(e.fileName)(\(roleDesc))")
    }

    if okCount == 0 { fail("没有任何光标应用成功") }
    print("\n完成:\(okCount) 个光标已全局替换。")
    print("恢复默认: mousecur reset")
    if !Agent.isInstalled {
        print("注销/重启后会还原,开机自动应用: mousecur agent install")
    }
}

func applySingleFile(_ url: URL, args: inout [String], pointSize: CGFloat) {
    let identifiers: [String]
    if let raw = optionValue(&args, "--slot") {
        var ids: [String] = []
        for part in raw.split(separator: ",") {
            guard let resolved = Slots.resolve(String(part)) else {
                fail("无法识别槽位 \(part),用 mousecur slots 查看可用值")
            }
            ids.append(contentsOf: resolved)
        }
        identifiers = ids
    } else if let role = WinRole.detect(fromFileName: url.lastPathComponent), !role.macIdentifiers.isEmpty {
        identifiers = role.macIdentifiers
        print("按文件名识别为「\(role.cnName)」")
    } else {
        identifiers = ["com.apple.coregraphics.Arrow"]
        print("未指定 --slot,默认替换箭头光标")
    }

    do {
        let frames = try Applier.applyFile(url, identifiers: identifiers, pointSize: pointSize)
        // 单文件应用也记入状态,便于 reapply
        var state = StateStore.load() ?? SavedState(pointSize: Double(pointSize), items: [])
        state.items.removeAll { $0.identifiers.contains(where: identifiers.contains) }
        state.items.append(AppliedItem(file: url.path, identifiers: identifiers))
        state.pointSize = Double(pointSize)
        try? StateStore.save(state)

        let slots = identifiers.map { Slots.name(for: $0) }.joined(separator: "、")
        print("✓ 已应用 \(url.lastPathComponent)(\(frames > 1 ? "\(frames) 帧动画" : "静态")) → \(slots)")
        print("恢复默认: mousecur reset")
    } catch {
        fail("\(error)")
    }
}

// MARK: - 入口

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    print(helpText)
    exit(0)
}
args.removeFirst()

switch command {
case "help", "--help", "-h":
    print(helpText)

case "slots":
    print("macOS 可替换的光标槽位:\n")
    for s in Slots.all {
        print("  \(s.identifier.padding(toLength: 34, withPad: " ", startingAt: 0)) \(s.name)")
    }
    print("\n--slot 支持的简写: " + Slots.shorthand.keys.sorted().joined(separator: ", "))

case "doctor":
    print("系统接口检查(macOS \(ProcessInfo.processInfo.operatingSystemVersionString)):\n")
    var allOK = true
    for (name, ok) in CGS.diagnostics() {
        print("  \(ok ? "✓" : "✗") \(name)")
        if !ok { allOK = false }
    }
    print(allOK ? "\n一切正常,可以替换光标。"
                : "\n存在问题:私有接口缺失或无法连接 WindowServer。")
    exit(allOK ? 0 : 1)

case "info":
    guard let path = args.first else { fail("用法: mousecur info <光标文件>") }
    do { try describe(URL(fileURLWithPath: path)) } catch { fail("\(error)") }

case "preview":
    guard !args.isEmpty else { fail("用法: mousecur preview <光标文件> [--out 目录]") }
    let outDir = optionValue(&args, "--out") ?? FileManager.default.currentDirectoryPath
    let url = URL(fileURLWithPath: args[0])
    do {
        let parsed = try CursorFile.parse(url: url)
        let dir = URL(fileURLWithPath: outDir, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stem = url.deletingPathExtension().lastPathComponent
        for (i, frame) in parsed.frames.enumerated() {
            let out = dir.appendingPathComponent(String(format: "%@_%02d.png", stem, i))
            try writePNG(frame.image, to: out)
        }
        print("已导出 \(parsed.frames.count) 帧到 \(dir.path)")
    } catch { fail("\(error)") }

case "apply":
    let size = parseSize(&args)
    guard let path = args.first else { fail("用法: mousecur apply <文件夹或文件> [--slot 槽位] [--size N]") }
    args.removeFirst()
    let url = URL(fileURLWithPath: path)
    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
        fail("路径不存在: \(url.path)")
    }
    if isDir.boolValue {
        applyThemeFolder(url, pointSize: size)
    } else {
        applySingleFile(url, args: &args, pointSize: size)
    }

case "reset":
    do {
        let r = try Applier.reset()
        print("✓ 已恢复 macOS 默认光标。")
        if r.restored == 0 || !r.skipped.isEmpty {
            print("提示: 如个别光标样式未立即还原,注销重新登录即可完全恢复。")
        }
    } catch { fail("\(error)") }

case "reapply":
    let wait = flag(&args, "--wait")
    do {
        let n = try Applier.reapply(waitUpToSeconds: wait ? 60 : 0)
        print(n > 0 ? "✓ 已重新应用 \(n) 个光标。" : "没有保存过的主题,先用 mousecur apply。")
    } catch { fail("\(error)") }

case "agent":
    switch args.first {
    case "install":
        do {
            let selfPath = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
            try Agent.install(cliSource: selfPath)
            print("✓ 已安装开机自动应用(\(Agent.plistURL.path))。")
        } catch { fail("\(error)") }
    case "uninstall":
        do {
            try Agent.uninstall()
            print("✓ 已移除开机自动应用。")
        } catch { fail("\(error)") }
    default:
        fail("用法: mousecur agent install|uninstall")
    }

case "_current":
    // 隐藏调试命令:把屏幕上正在显示的光标存成 PNG
    guard let out = args.first else { fail("_current <输出.png>") }
    do {
        let img = try CGS.currentDisplayedCursor()
        try writePNG(img, to: URL(fileURLWithPath: out))
        print("当前光标 \(img.width)×\(img.height)px 已保存到 \(out)")
    } catch { fail("\(error)") }

case "_dump":
    // 隐藏调试命令:把 WindowServer 里注册的光标读出来存成 PNG
    guard args.count >= 2 else { fail("_dump <标识符|简写> <输出.png>") }
    let ident = Slots.resolve(args[0])?.first ?? args[0]
    do {
        let r = try CGS.copyRegistered(identifier: ident)
        print("标识符: \(ident)")
        print("尺寸: \(r.size)  热点: \(r.hotspot)  帧数: \(r.frameCount)  帧时长: \(r.frameDuration)s")
        print("图像数: \(r.images.count)" + r.images.enumerated().map { "  [\($0.0)] \($0.1.width)×\($0.1.height)px" }.joined())
        if let first = r.images.first {
            try writePNG(first, to: URL(fileURLWithPath: args[1]))
            print("已保存第一张到 \(args[1])")
        }
    } catch { fail("\(error)") }

default:
    fail("未知命令 \(command),用 mousecur help 查看用法")
}
