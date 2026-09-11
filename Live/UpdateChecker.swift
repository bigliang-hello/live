import SwiftUI
import AppKit

/// 版本检查：请求 GitHub 最新 Release，与本地 CFBundleShortVersionString 比对。
/// 启动时每天静默检查一次；菜单栏可手动检查；发现新版在侧栏底部卡片提示。
@MainActor @Observable final class UpdateChecker {
    static let shared = UpdateChecker()

    struct Release: Equatable {
        let tag: String      // 如 "1.0.1"
        let pageURL: URL     // GitHub Release 页面
    }

    static let repository = URL(string: "https://github.com/bigliang-hello/live")!

    private(set) var latest: Release?
    private(set) var checking = false

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    /// 最新版本是否比当前安装的更新。
    var hasNewerVersion: Bool {
        guard let latest else { return false }
        return Self.isVersion(Self.currentVersion, olderThan: latest.tag)
    }

    // MARK: - 检查

    /// 启动静默检查：24 小时最多一次，失败不打扰。
    func checkSilentlyIfNeeded() async {
        let last = UserDefaults.standard.object(forKey: "update.lastAutoCheck") as? Date ?? .distantPast
        guard last.timeIntervalSinceNow < -24 * 3600 else { return }
        UserDefaults.standard.set(Date.now, forKey: "update.lastAutoCheck")
        await check()
    }

    /// 请求最新 Release。返回本次检查是否成功；有无新版本看 hasNewerVersion。
    func check() async -> Bool {
        guard !checking else { return false }
        checking = true
        defer { checking = false }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/bigliang-hello/live/releases/latest")!)
            request.timeoutInterval = 15
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let page = json["html_url"] as? String else { throw URLError(.cannotParseResponse) }
            latest = Release(tag: tag, pageURL: URL(string: page) ?? Self.repository)
            return true
        } catch {
            latest = nil
            return false
        }
    }

    func openDownload() {
        NSWorkspace.shared.open(latest?.pageURL ?? Self.repository)
    }

    // MARK: - 忽略本版本

    private var skippedTag: String? {
        get { UserDefaults.standard.string(forKey: "update.skipped") }
        set { UserDefaults.standard.set(newValue, forKey: "update.skipped") }
    }

    /// 侧栏提示是否该显示：有新版，且不是被忽略的那个版本。
    var shouldShowBanner: Bool {
        guard let latest, hasNewerVersion else { return false }
        return skippedTag != latest.tag
    }

    /// 忽略当前提示的版本，直到更新的版本出现。
    func skipCurrent() {
        if let latest { skippedTag = latest.tag }
    }

    // MARK: - 版本比较

    /// 点分数字比较："1.0" < "1.0.1" < "1.2"；带 v 前缀和非数字段会被宽容处理。
    static func isVersion(_ a: String, olderThan b: String) -> Bool {
        func parts(_ version: String) -> [Int] {
            let trimmed = version.hasPrefix("v") || version.hasPrefix("V") ? String(version.dropFirst()) : version
            return trimmed.split(separator: ".").map { Int($0) ?? 0 }
        }
        let left = parts(a), right = parts(b)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l < r }
        }
        return false
    }
}
