import SwiftUI
import AppKit

/// 检查更新结果的独立小浮窗:弹在屏幕中央,
/// 主窗口没开(只剩菜单栏)时也能看到,点按钮或等几秒自动关闭。
@MainActor final class UpdatePanelController {
    static let shared = UpdatePanelController()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func showUpToDate(current: String) {
        show(
            symbol: "checkmark.seal.fill",
            tint: Color(red: 0.18, green: 0.43, blue: 0.35),
            title: "已是最新版本",
            subtitle: "当前 \(current)，继续保持。",
            buttonTitle: "好",
            action: nil
        )
    }

    func showAvailable(tag: String, current: String) {
        show(
            symbol: "arrow.down.circle.fill",
            tint: Color(red: 0.18, green: 0.43, blue: 0.35),
            title: "发现新版本 \(tag)",
            subtitle: "当前 \(current)，点击前往下载。",
            buttonTitle: "前往下载",
            action: { UpdateChecker.shared.openDownload() }
        )
    }

    func showFailure() {
        show(
            symbol: "wifi.exclamationmark",
            tint: .orange,
            title: "检查更新失败",
            subtitle: "请检查网络后重试。",
            buttonTitle: "好",
            action: nil
        )
    }

    private func show(
        symbol: String,
        tint: Color,
        title: String,
        subtitle: String,
        buttonTitle: String,
        action: (() -> Void)?
    ) {
        dismissTask?.cancel()

        let size = NSSize(width: 320, height: 250)
        let card = UpdatePanelCard(
            symbol: symbol,
            tint: tint,
            title: title,
            subtitle: subtitle,
            buttonTitle: buttonTitle
        ) {
            self.close()
            action?()
        }

        let panel = panel ?? Self.makePanel()
        self.panel = panel
        panel.contentViewController = NSHostingController(rootView: card)
        panel.setContentSize(size)
        if let visible = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(CGPoint(
                x: visible.midX - size.width / 2,
                y: visible.midY - size.height / 2
            ))
        }
        panel.orderFrontRegardless()
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        dismissTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            close()
        }
    }

    func close() {
        dismissTask?.cancel()
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.completionHandler = { panel.orderOut(nil) }
            panel.animator().alphaValue = 0
        })
    }

    /// 与居中提醒弹窗同款面板配置:隐藏标题栏的 titled 窗口,
    /// 比 borderless 更稳——透明圆角处不会露出窗口背板的灰角。
    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        return panel
    }
}

/// 居中的结果卡片:顶部小标 + 渐变圆徽章 + 标题说明 + 整宽按钮,入场带弹性缩放。
private struct UpdatePanelCard: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let buttonTitle: String
    let onButton: () -> Void

    @State private var appeared = false

    private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)

    var body: some View {
        VStack(spacing: 0) {
            Text("活着 · 检查更新")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
                .foregroundStyle(.tertiary)

            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(tint.gradient, in: Circle())
                .shadow(color: tint.opacity(0.32), radius: 12, y: 5)
                .padding(.top, 16)

            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(ink)
                .padding(.top, 16)

            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            Button(action: onButton) {
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
            .padding(.top, 20)
        }
        .padding(.horizontal, 26)
        .padding(.top, 26)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.black.opacity(0.06))
        }
        .preferredColorScheme(.light)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) { appeared = true }
        }
    }
}
