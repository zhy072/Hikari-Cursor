import SwiftUI
import AppKit
import CursorKit

/// GUI 和菜单栏共用:定位内置的 mousecur CLI(打包在 App 里,或 `swift run` 时在同目录)。
func locateBundledCLI() -> URL? {
    if let u = Bundle.main.url(forResource: "mousecur", withExtension: nil) { return u }
    let sibling = URL(fileURLWithPath: CommandLine.arguments[0])
        .deletingLastPathComponent().appendingPathComponent("mousecur")
    return FileManager.default.fileExists(atPath: sibling.path) ? sibling : nil
}

/// 菜单栏下拉内容。关闭主窗口后 App 仍常驻在这里,提供不需要开窗口的快捷操作。
struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var lastMessage: String?

    private var savedState: SavedState? { StateStore.load() }

    private var statusLine: String {
        if let lastMessage { return lastMessage }
        guard let s = savedState, !s.items.isEmpty else { return "尚未应用主题" }
        return "已应用 \(s.items.count) 个光标 · \(Int(s.pointSize))pt"
    }

    var body: some View {
        Text(statusLine)

        Divider()

        Button("打开 Hikari-Cursor…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("重新应用上次主题") { reapply() }
            .disabled(savedState?.items.isEmpty ?? true)

        Button("恢复系统默认") { reset() }

        Divider()

        Toggle("登录时自动应用", isOn: Binding(
            get: { Agent.isInstalled },
            set: { toggleAgent($0) }
        ))

        Divider()

        Button("退出 Hikari-Cursor") {
            NSApp.terminate(nil)
        }
    }

    private func reapply() {
        do {
            let n = try Applier.reapply()
            lastMessage = n > 0 ? "✓ 已重新应用 \(n) 个光标" : "没有保存过的主题"
        } catch {
            lastMessage = "重新应用失败:\(error)"
        }
    }

    private func reset() {
        do {
            _ = try Applier.reset()
            lastMessage = "✓ 已恢复系统默认"
        } catch {
            lastMessage = "恢复失败:\(error)"
        }
    }

    private func toggleAgent(_ on: Bool) {
        do {
            if on {
                guard let cli = locateBundledCLI() else {
                    lastMessage = "找不到内置的 mousecur 命令行工具"
                    return
                }
                try Agent.install(cliSource: cli)
            } else {
                try Agent.uninstall()
            }
        } catch {
            lastMessage = "设置开机自启失败:\(error)"
        }
    }
}
