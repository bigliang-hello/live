import SwiftUI
import ServiceManagement

/// 开机自启动：把主应用注册为登录项（SMAppService，macOS 13+）。
/// 无需沙盒或辅助程序，失败通常是系统「登录项」被管理策略限制。
@MainActor @Observable final class LoginItem {
    static let shared = LoginItem()

    private(set) var enabled = false

    init() {
        refresh()
    }

    func refresh() {
        enabled = SMAppService.mainApp.status == .enabled
    }

    /// 返回是否设置成功；失败时可提示用户到 系统设置 › 通用 › 登录项 检查。
    @discardableResult
    func setEnabled(_ value: Bool) -> Bool {
        defer { refresh() }
        do {
            if value {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
