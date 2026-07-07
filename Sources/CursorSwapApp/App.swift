import SwiftUI
import AppKit
import CursorKit
import UniformTypeIdentifiers

/// Hikari-Cursor 是菜单栏常驻工具:关闭主窗口不退出 App,
/// Dock 里不显示图标,始终能从右上角菜单栏找回来。
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 由菜单栏 label 视图在启动时注入(那里才拿得到 openWindow 环境值)
    static var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// App 已在运行时用户又双击了图标:把主窗口弹回来
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            Self.openMainWindow?()
            NSApp.activate(ignoringOtherApps: true)
        }
        return false
    }
}

/// 菜单栏图标。常驻于状态栏,借它的 onAppear 把 openWindow 能力交给 AppDelegate。
struct MenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: "cursorarrow")
            .onAppear {
                AppDelegate.openMainWindow = { openWindow(id: "main") }
            }
    }
}

@main
struct CursorSwapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .frame(minWidth: 560, minHeight: 480)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.presented)   // 每次启动都弹出主窗口
        .restorationBehavior(.disabled)      // 不要“恢复上次关着窗口”的状态

        MenuBarExtra {
            MenuBarContentView()
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.menu)
    }
}

struct EntryVM: Identifiable {
    let id = UUID()
    let url: URL
    let role: WinRole?
    /// 按文件名自动识别出的目标槽位(可能为空)
    let autoIdentifiers: [String]
    /// 实际要应用的目标槽位,用户可在菜单里改。空数组 = 不映射。
    var targetIdentifiers: [String]
    var include: Bool
    var thumbnail: NSImage?
    var isAnimated = false
    /// 同名文件时用所在子文件夹区分(例如 "03. amber")
    var locationHint: String? = nil

    var isAuto: Bool { targetIdentifiers == autoIdentifiers }

    /// 右侧映射菜单的按钮文字
    var targetLabel: String {
        guard let first = targetIdentifiers.first else { return "不映射" }
        let name = targetIdentifiers.count > 1
            ? "\(Slots.name(for: first)) 等 \(targetIdentifiers.count) 项"
            : Slots.name(for: first)
        return (isAuto ? "自动 · " : "") + name
    }
}

struct ContentView: View {
    @State private var folderURL: URL?
    @State private var entries: [EntryVM] = []
    @State private var pointSize: Double = 32
    @State private var status = "选择一个包含 .cur / .ani 文件的主题文件夹开始。"
    @State private var busy = false
    @State private var agentOn = Agent.isInstalled
    @State private var apiOK = CGS.diagnostics().allSatisfy { $0.ok }
    /// 记住上次选的主题文件夹,启动时自动恢复
    @AppStorage("lastThemeFolder") private var lastThemeFolder = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hikari-Cursor").font(.title2.bold())
                    Text("把 Windows 的 .cur / .ani 指针主题用到 macOS 上")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("选择主题文件夹…", action: pickFolder)
            }

            if !apiOK {
                Label("当前系统缺少所需接口,无法替换光标(详见命令行 mousecur doctor)",
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            if let folderURL {
                Text(folderURL.path).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            List($entries) { $entry in
                HStack(spacing: 10) {
                    Toggle("", isOn: $entry.include)
                        .labelsHidden()
                        .disabled(entry.targetIdentifiers.isEmpty)
                    Group {
                        if let t = entry.thumbnail {
                            Image(nsImage: t).resizable().interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(entry.url.lastPathComponent)
                            if entry.isAnimated {
                                Text("动画").font(.caption2).padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(.blue.opacity(0.15), in: Capsule())
                            }
                        }
                        Text([entry.role?.cnName ?? "未识别角色", entry.locationHint]
                                .compactMap { $0 }.joined(separator: "  ·  "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if entry.include, entry.targetIdentifiers.contains(where: conflictingSlots.contains) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2).foregroundStyle(.orange)
                            .help("多个文件映射到同一 macOS 光标,只有最后一个会生效")
                    }
                    Image(systemName: "arrow.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                    mappingMenu($entry)
                }
                .opacity(entry.include ? 1 : 0.55)
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView("未加载主题",
                                           systemImage: "cursorarrow",
                                           description: Text("点右上角「选择主题文件夹…」或把文件夹拖进来"))
                }
            }

            HStack {
                Text("光标大小")
                Slider(value: $pointSize, in: 24...64, step: 2).frame(width: 180)
                Text("\(Int(pointSize)) pt").monospacedDigit().frame(width: 44, alignment: .leading)
                Spacer()
                Toggle("登录时自动应用", isOn: $agentOn)
                    .onChange(of: agentOn) { _, on in toggleAgent(on) }
            }

            HStack {
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                Spacer()
                Button("恢复系统默认") { resetCursors() }
                    .disabled(busy || !apiOK)
                Button("应用主题") { applyTheme() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy || !apiOK || entries.allSatisfy { !$0.include || $0.targetIdentifiers.isEmpty })
            }
        }
        .padding(16)
        .onAppear(perform: restoreOnLaunch)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { DispatchQueue.main.async { load(folder: url) } }
            }
            return true
        }
    }

    /// 每行右侧的「映射到哪个 macOS 光标」菜单。旁边带 macOS 光标预览图。
    @ViewBuilder
    private func mappingMenu(_ entry: Binding<EntryVM>) -> some View {
        let e = entry.wrappedValue
        Menu {
            if !e.autoIdentifiers.isEmpty {
                Button {
                    setTarget(entry, e.autoIdentifiers)
                } label: {
                    Label("自动(\(e.autoIdentifiers.map { Slots.name(for: $0) }.joined(separator: "、")))",
                          systemImage: "wand.and.stars")
                }
            }
            Button {
                setTarget(entry, [])
            } label: {
                Label("不映射", systemImage: "slash.circle")
            }
            Divider()
            ForEach(Slots.groups, id: \.title) { group in
                Menu(group.title) {
                    ForEach(group.identifiers, id: \.self) { id in
                        Button {
                            setTarget(entry, [id])
                        } label: {
                            if let img = MacCursorGlyph.image(for: id) {
                                Image(nsImage: img)
                            }
                            Text(Slots.name(for: id))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let first = e.targetIdentifiers.first,
                   let img = MacCursorGlyph.image(for: first) {
                    Image(nsImage: img)
                } else {
                    Image(systemName: "slash.circle").foregroundStyle(.orange)
                }
                Text(e.targetLabel)
                    .lineLimit(1)
                    .foregroundStyle(e.targetIdentifiers.isEmpty ? Color.orange : .primary)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .frame(width: 210, alignment: .trailing)
    }

    private func setTarget(_ entry: Binding<EntryVM>, _ ids: [String]) {
        entry.wrappedValue.targetIdentifiers = ids
        entry.wrappedValue.include = !ids.isEmpty
    }

    /// 文件所在目录相对所选主题文件夹的路径,用于区分同名文件
    private func relativeParent(of url: URL, base: URL) -> String {
        let parent = url.deletingLastPathComponent()
        if parent.path == base.path { return base.lastPathComponent }
        let prefix = base.path.hasSuffix("/") ? base.path : base.path + "/"
        var rel = parent.path
        if rel.hasPrefix(prefix) { rel = String(rel.dropFirst(prefix.count)) }
        return rel.isEmpty ? parent.lastPathComponent : rel
    }

    /// 被多个已勾选文件同时映射的槽位(冲突:实际只有最后应用的生效)
    private var conflictingSlots: Set<String> {
        var count: [String: Int] = [:]
        for e in entries where e.include {
            for id in e.targetIdentifiers { count[id, default: 0] += 1 }
        }
        return Set(count.filter { $0.value > 1 }.keys)
    }

    /// 启动时恢复:优先加载上次选过的文件夹;没有就从已应用状态(state.json)反推;
    /// 同时把光标大小和「当前已应用」信息同步到界面。
    private func restoreOnLaunch() {
        guard entries.isEmpty else { return }
        let saved = StateStore.load()
        if let saved { pointSize = saved.pointSize }

        let fm = FileManager.default
        var candidate: URL? = nil
        if !lastThemeFolder.isEmpty, fm.fileExists(atPath: lastThemeFolder) {
            candidate = URL(fileURLWithPath: lastThemeFolder, isDirectory: true)
        } else if let first = saved?.items.first, fm.fileExists(atPath: first.file) {
            candidate = URL(fileURLWithPath: first.file).deletingLastPathComponent()
        }
        if let candidate { load(folder: candidate) }

        if let saved, !saved.items.isEmpty {
            status = "当前已应用 \(saved.items.count) 个光标(\(Int(saved.pointSize)) pt)。"
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        panel.message = "选择包含 .cur / .ani 文件的主题文件夹"
        if panel.runModal() == .OK, let url = panel.url {
            load(folder: url)
        }
    }

    private func load(folder: URL) {
        var dir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &dir), dir.boolValue else {
            status = "拖入的不是文件夹。"
            return
        }
        folderURL = folder
        lastThemeFolder = folder.path
        let scanned = Theme.scan(folder: folder)
        // 已保存的映射(上次成功应用的),按文件路径叠加,让用户的手动指定跨启动保留
        let saved = StateStore.load()
        // 同名文件(如多套配色各有一个 busy.ani)用所在子文件夹区分
        let nameCounts = Dictionary(grouping: scanned) { $0.url.lastPathComponent }.mapValues(\.count)
        entries = scanned.map { s in
            var vm = EntryVM(url: s.url, role: s.role,
                             autoIdentifiers: s.identifiers,
                             targetIdentifiers: s.identifiers,
                             include: !s.identifiers.isEmpty, thumbnail: nil)
            if let match = saved?.items.first(where: { $0.file == s.url.path }) {
                vm.targetIdentifiers = match.identifiers
                vm.include = !match.identifiers.isEmpty
            }
            if nameCounts[s.url.lastPathComponent, default: 0] > 1 {
                vm.locationHint = relativeParent(of: s.url, base: folder)
            }
            return vm
        }
        status = scanned.isEmpty ? "这个文件夹里没有 .cur / .ani 文件。"
                                 : "找到 \(scanned.count) 个光标文件。可在每行右侧改映射目标。"
        loadThumbnails()
    }

    private func loadThumbnails() {
        let snapshot = entries
        DispatchQueue.global(qos: .userInitiated).async {
            for (i, e) in snapshot.enumerated() {
                guard let parsed = try? CursorFile.parse(url: e.url, firstFrameOnly: true),
                      let frame = parsed.frames.first else { continue }
                let img = NSImage(cgImage: frame.image,
                                  size: NSSize(width: 28, height: 28))
                let animated = parsed.isAnimated
                DispatchQueue.main.async {
                    guard i < entries.count, entries[i].url == e.url else { return }
                    entries[i].thumbnail = img
                    entries[i].isAnimated = animated
                }
            }
        }
    }

    private func applyTheme() {
        let items = entries.filter { $0.include && !$0.targetIdentifiers.isEmpty }
            .map { AppliedItem(file: $0.url.path, identifiers: $0.targetIdentifiers) }
        guard !items.isEmpty else { return }
        busy = true
        status = "正在应用…"
        let size = CGFloat(pointSize)
        DispatchQueue.global(qos: .userInitiated).async {
            let results = Applier.applyAll(items: items, pointSize: size)
            let ok = results.filter { $0.error == nil }.count
            let failed = results.count - ok
            DispatchQueue.main.async {
                busy = false
                status = failed == 0 ? "✓ 已替换 \(ok) 个光标。移动一下鼠标看看效果吧!"
                                     : "替换了 \(ok) 个,失败 \(failed) 个:\(results.first { $0.error != nil }?.error.map { "\($0)" } ?? "")"
            }
        }
    }

    private func resetCursors() {
        do {
            let r = try Applier.reset()
            status = (r.restored > 0 && r.skipped.isEmpty)
                ? "✓ 已恢复 macOS 默认光标。"
                : "✓ 已恢复默认。个别光标如未还原,注销重新登录即可。"
        } catch {
            status = "恢复失败:\(error)"
        }
    }

    private func toggleAgent(_ on: Bool) {
        do {
            if on {
                guard let cli = locateBundledCLI() else {
                    status = "找不到内置的 mousecur 命令行工具。"
                    agentOn = false
                    return
                }
                try Agent.install(cliSource: cli)
                status = "✓ 已开启登录时自动应用。"
            } else {
                try Agent.uninstall()
                status = "已关闭登录时自动应用。"
            }
        } catch {
            status = "设置开机自启失败:\(error)"
            agentOn = Agent.isInstalled
        }
    }
}
