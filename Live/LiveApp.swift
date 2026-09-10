import SwiftUI
import UserNotifications

@main
struct LiveApp: App {
    @State private var store = WellnessStore.shared
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var applicationDelegate
    var body: some Scene {
        WindowGroup("活着", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 1120, height: 780)
        .windowStyle(.hiddenTitleBar)
        MenuBarExtra("活着", systemImage: "leaf") {
            MenuContent(store: store)
        }
    }
}
struct MenuContent: View {
    @Bindable var store: WellnessStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text("活着 · 今天也照顾好自己")
        Button("喝点水 · 打开居中弹窗") { store.showWaterReminder() }
        Button("起来走走 · 随机动作") { store.showMovementReminder() }
        Button("让眼睛放个假") { store.showEyeReminder() }
        Divider()
        Button(store.running ? "暂停提醒" : "开启提醒") {
            if store.running { store.stop() } else { Task { await store.schedule() } }
        }.disabled(store.busy)
        Toggle("开机自启动", isOn: Binding(
            get: { LoginItem.shared.enabled },
            set: { value in
                if !LoginItem.shared.setEnabled(value) {
                    store.notice = "设置开机自启动没有成功，可以到 系统设置 › 通用 › 登录项 里检查。"
                }
            }
        ))
        Button("打开活着") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("退出并暂停提醒") { store.stop(); NSApp.terminate(nil) }
    }
}

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        Task { @MainActor in
            WellnessStore.shared.resumeRemindersIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func windowDidClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, !(window is NSPanel) else { return }
        DispatchQueue.main.async {
            let hasVisibleMainWindow = NSApp.windows.contains {
                $0.isVisible && !($0 is NSPanel) && $0.level == .normal
            }
            if !hasVisibleMainWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
