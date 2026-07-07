import Foundation
import CoreGraphics

/// 主题目录里的一个光标文件及其映射结果。
public struct ThemeEntry {
    public let url: URL
    public let role: WinRole?
    public let identifiers: [String]

    public var fileName: String { url.lastPathComponent }
}

public enum Theme {
    /// 扫描目录(含一层子目录)下的 .cur/.ani 文件并按文件名识别角色。
    public static func scan(folder: URL) -> [ThemeEntry] {
        let fm = FileManager.default
        var files: [URL] = []
        if let it = fm.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                                  options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let u as URL in it {
                let ext = u.pathExtension.lowercased()
                if ext == "cur" || ext == "ani" { files.append(u) }
            }
        }
        files.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        return files.map { u in
            let role = WinRole.detect(fromFileName: u.lastPathComponent)
            return ThemeEntry(url: u, role: role, identifiers: role?.macIdentifiers ?? [])
        }
    }
}

// MARK: - 状态持久化(供 reapply / 开机自启使用)

public struct AppliedItem: Codable {
    public let file: String
    public let identifiers: [String]

    public init(file: String, identifiers: [String]) {
        self.file = file
        self.identifiers = identifiers
    }
}

public struct SavedState: Codable {
    public var pointSize: Double
    public var items: [AppliedItem]

    public init(pointSize: Double, items: [AppliedItem]) {
        self.pointSize = pointSize
        self.items = items
    }
}

public enum StateStore {
    public static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Hikari-Cursor", isDirectory: true)
    }
    public static var stateFile: URL { directory.appendingPathComponent("state.json") }

    public static func load() -> SavedState? {
        guard let data = try? Data(contentsOf: stateFile) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    public static func save(_ state: SavedState) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(state).write(to: stateFile)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: stateFile)
    }
}

// MARK: - 应用

public enum Applier {

    /// 把一个光标文件应用到若干系统槽位(含各槽位的别名),返回帧数。
    /// `themeProvided`:整套主题直接覆盖的槽位,这些不再被别名覆盖。
    /// 只要有一个槽位注册成功就算成功。
    @discardableResult
    public static func applyFile(_ url: URL, identifiers: [String], pointSize: CGFloat,
                                 themeProvided: Set<String> = []) throws -> Int {
        let parsed = try CursorFile.parse(url: url)
        let rendered = try StripBuilder.render(parsed, pointSize: pointSize)
        // 覆盖之前先把系统默认备份下来,恢复时用
        let aliasIds = identifiers.flatMap { Slots.aliases(for: $0) }.filter { !themeProvided.contains($0) }
        DefaultBackup.ensure(identifiers + aliasIds)
        var okCount = 0
        var lastError: Error? = nil
        for id in identifiers {
            do {
                try CGS.register(identifier: id, cursor: rendered)
                okCount += 1
            } catch {
                lastError = error
            }
        }
        guard okCount > 0 else {
            throw lastError ?? CGSBridgeError.callFailed("注册光标", -1)
        }
        // 别名(Tahoe 新标识符、浏览器标识符)尽力注册,失败不影响结果
        for id in identifiers {
            for alias in Slots.aliases(for: id) where !themeProvided.contains(alias) {
                try? CGS.register(identifier: alias, cursor: rendered)
            }
        }
        return rendered.frameCount
    }

    public struct ItemResult {
        public let item: AppliedItem
        public let frameCount: Int?
        public let error: Error?
    }

    /// 应用一组光标并保存状态。返回每项的结果。
    public static func applyAll(items: [AppliedItem], pointSize: CGFloat,
                                saveState: Bool = true) -> [ItemResult] {
        let provided = Set(items.flatMap { $0.identifiers })
        var results: [ItemResult] = []
        var succeeded: [AppliedItem] = []
        for item in items where !item.identifiers.isEmpty {
            do {
                let frames = try applyFile(URL(fileURLWithPath: item.file),
                                           identifiers: item.identifiers,
                                           pointSize: pointSize,
                                           themeProvided: provided)
                succeeded.append(item)
                results.append(ItemResult(item: item, frameCount: frames, error: nil))
            } catch {
                results.append(ItemResult(item: item, frameCount: nil, error: error))
            }
        }
        if saveState && !succeeded.isEmpty {
            try? StateStore.save(SavedState(pointSize: Double(pointSize), items: succeeded))
        }
        return results
    }

    /// 按保存的状态重新应用(登录后 WindowServer 可能尚未就绪,可重试等待)。
    public static func reapply(waitUpToSeconds: Int = 0) throws -> Int {
        guard let state = StateStore.load(), !state.items.isEmpty else { return 0 }
        let deadline = Date().addingTimeInterval(TimeInterval(waitUpToSeconds))
        while true {
            if CGS.connectionID() != nil { break }
            if Date() >= deadline { break }
            Thread.sleep(forTimeInterval: 2)
        }
        let provided = Set(state.items.flatMap { $0.identifiers })
        var applied = 0
        var lastError: Error? = nil
        for item in state.items {
            do {
                try applyFile(URL(fileURLWithPath: item.file),
                              identifiers: item.identifiers,
                              pointSize: CGFloat(state.pointSize),
                              themeProvided: provided)
                applied += 1
            } catch {
                lastError = error
            }
        }
        if applied == 0, let lastError { throw lastError }
        return applied
    }

    /// 恢复系统默认光标并清除保存的状态。
    /// 返回 (从备份恢复的数量, 无法恢复的标识符 —— 注销重登后自然还原)。
    @discardableResult
    public static func reset() throws -> (restored: Int, skipped: [String]) {
        let result = DefaultBackup.restoreAll()
        try CGS.unregisterAll()
        StateStore.clear()
        return result
    }
}

// MARK: - 开机自动应用(LaunchAgent)

public enum Agent {
    public static let label = "com.hikaricursor.reapply"

    public static var plistURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LaunchAgents/\(label).plist")
    }
    public static var installedCLI: URL {
        StateStore.directory.appendingPathComponent("mousecur")
    }
    public static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// 把 CLI 拷到固定位置并注册 LaunchAgent(登录时 reapply)。
    public static func install(cliSource: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: StateStore.directory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: installedCLI.path) {
            try fm.removeItem(at: installedCLI)
        }
        try fm.copyItem(at: cliSource, to: installedCLI)

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [installedCLI.path, "reapply", "--wait"],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try fm.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: plistURL)

        _ = shell("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"])   // 忽略失败
        let (code, out) = shell("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
        if code != 0 {
            throw NSError(domain: "CursorSwap", code: Int(code),
                          userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap 失败: \(out)"])
        }
    }

    public static func uninstall() throws {
        _ = shell("/bin/launchctl", ["bootout", "gui/\(getuid())/\(label)"])
        let fm = FileManager.default
        if fm.fileExists(atPath: plistURL.path) {
            try fm.removeItem(at: plistURL)
        }
    }

    @discardableResult
    private static func shell(_ path: String, _ args: [String]) -> (Int32, String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do { try p.run() } catch { return (-1, "\(error)") }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (p.terminationStatus, out)
    }
}
