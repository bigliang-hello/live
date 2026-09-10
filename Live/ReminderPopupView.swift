import SwiftUI
import AppKit

enum ReminderPopupKind: Equatable {
    case water
    case move(OfficeExercise)
    case eyes
    case custom(String)

    var key: String {
        switch self {
        case .water: "water"
        case .move: "move"
        case .eyes: "eyes"
        case .custom(let name): "custom." + name
        }
    }

    var windowSize: NSSize {
        switch self {
        case .water: NSSize(width: 640, height: 450)
        case .move: NSSize(width: 760, height: 600)
        case .eyes: NSSize(width: 620, height: 430)
        case .custom: NSSize(width: 560, height: 350)
        }
    }
}

/// 弹窗文案池：同一种提醒换着说法出现，避免看久了变成"壁纸"。
struct ReminderCopy {
    let headline: String
    let message: String

    static func draw(for kindKey: String) -> ReminderCopy {
        switch kindKey {
        case "water": return water.randomElement() ?? water[0]
        case "eyes": return eyes.randomElement() ?? eyes[0]
        default: return move.randomElement() ?? move[0]
        }
    }

    static let water = [
        ReminderCopy(headline: "喝点水吧", message: "选一个接近的量，喝完就会计入今天。"),
        ReminderCopy(headline: "该补水了", message: "不用一口气喝完，小口慢饮就好。"),
        ReminderCopy(headline: "水杯在等你", message: "记录是为了看见，不是为了考核。"),
        ReminderCopy(headline: "来口水，继续", message: "喝几口，顺便让眼睛离开一会儿屏幕。"),
        ReminderCopy(headline: "给身体补点水", message: "随时选一个接近的量记下来就好。")
    ]

    static let eyes = [
        ReminderCopy(headline: "让眼睛放个假", message: "看向窗外或 6 米以外的地方，放松 20 秒。"),
        ReminderCopy(headline: "看看远处", message: "盯屏幕久了，给眼睛 20 秒的远方。"),
        ReminderCopy(headline: "眼睛也想休息", message: "抬眼看看最远的地方，眨眨眼。"),
        ReminderCopy(headline: "抬眼望望窗外", message: "让视线离开屏幕 20 秒，肩膀也一起松下来。")
    ]

    static let move = [
        ReminderCopy(headline: "起来走走", message: "椅子不是久留之地，起来活动一下。"),
        ReminderCopy(headline: "起来走走", message: "身体在等你站起来，给它两分钟。"),
        ReminderCopy(headline: "起来走走", message: "离开椅子换换姿势，它会还你一下午的清醒。"),
        ReminderCopy(headline: "起来走走", message: "坐着的时间够久了，起来转一转。")
    ]
}

@MainActor final class ReminderPopupController {
    static let shared = ReminderPopupController()

    private var panel: NSPanel?
    private var pending: [ReminderPopupKind] = []

    /// 定时提醒统一入口：当前没有弹窗时立即展示，否则按触发顺序排队，处理完一个再弹下一个。
    func enqueue(_ kind: ReminderPopupKind) {
        guard panel != nil else { present(kind); return }
        guard !pending.contains(where: { $0.key == kind.key }) else { return }
        pending.append(kind)
    }

    /// 用户主动打开（菜单栏、立即预览、换一个动作）：直接替换当前弹窗，不排队。
    func show(_ kind: ReminderPopupKind) {
        dismiss()
        present(kind)
    }

    /// 关闭当前弹窗；若还有排队的提醒，稍候展示下一个。
    func close() {
        dismiss()
        guard !pending.isEmpty else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.35))
            guard let self, self.panel == nil, let next = self.pending.first else { return }
            self.pending.removeFirst()
            self.present(next)
        }
    }

    /// 暂停全部提醒时调用：清空队列并关闭弹窗。
    func stopAll() {
        pending.removeAll()
        dismiss()
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func present(_ kind: ReminderPopupKind) {
        let rootView = ReminderPopupView(
            kind: kind,
            store: .shared,
            copy: ReminderCopy.draw(for: kind.key),
            queuedCount: pending.count
        ) { [weak self] in
            self?.close()
        }
        let hostingController = NSHostingController(rootView: rootView)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: kind.windowSize),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "活着提醒"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.titlebarSeparatorStyle = .none
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.contentViewController = hostingController
        panel.setContentSize(kind.windowSize)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow

        placeAtScreenCenter(panel)
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func placeAtScreenCenter(_ panel: NSPanel) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }
        let origin = CGPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.midY - panel.frame.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

struct ReminderPopupView: View {
    let kind: ReminderPopupKind
    @Bindable var store: WellnessStore
    var copy: ReminderCopy
    var queuedCount = 0
    let onClose: () -> Void

    private let deepGreen = Color(red: 0.10, green: 0.28, blue: 0.24)
    private let livingGreen = Color(red: 0.20, green: 0.48, blue: 0.36)
    private let mist = Color(red: 0.92, green: 0.96, blue: 0.93)
    private let paper = Color(red: 0.975, green: 0.985, blue: 0.975)

    var body: some View {
        ZStack {
            paper
            Circle()
                .fill(livingGreen.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 2)
                .offset(x: 250, y: -190)
            Circle()
                .fill(Color.blue.opacity(0.055))
                .frame(width: 230, height: 230)
                .offset(x: -280, y: 210)

            VStack(alignment: .leading, spacing: 0) {
                popupHeader
                    .padding(.bottom, 24)
                popupContent
                Spacer(minLength: 18)
                footer
            }
            .padding(30)
        }
        .foregroundStyle(deepGreen)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(deepGreen.opacity(0.10), lineWidth: 1)
        }
        .preferredColorScheme(.light)
    }

    private var popupHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            FourLeafMark(color: livingGreen)
                .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text("活着 · 此刻先照顾自己")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(livingGreen)
                Text(title)
                    .font(.system(size: 31, weight: .semibold, design: .rounded))
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(deepGreen.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭提醒")
        }
    }

    @ViewBuilder private var popupContent: some View {
        switch kind {
        case .water:
            waterContent
        case let .move(exercise):
            movementContent(exercise)
        case .eyes:
            eyesContent
        case .custom:
            customContent
        }
    }

    private var customContent: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle().fill(mist).frame(width: 136, height: 136)
                Image(systemName: "alarm.fill")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(livingGreen)
            }
            VStack(alignment: .leading, spacing: 13) {
                Text("你安排的时间到了。")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                Text("按自己的节奏处理就好。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("知道了") { onClose() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(livingGreen)
            }
        }
    }

    private var waterContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(copy.message)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach([150, 250, 350, 500], id: \.self) { amount in
                    Button {
                        store.checkWater(amount)
                        onClose()
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: amount >= 350 ? "mug.fill" : "drop.fill")
                                .font(.system(size: 20, weight: .medium))
                            Text("\(amount)")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                            Text("ml")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PopupChoiceButtonStyle(tint: amount == 250 ? livingGreen : deepGreen))
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "drop.fill").foregroundStyle(.blue)
                Text("今天已记录")
                Text(store.formattedWaterTotal).fontWeight(.semibold)
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(0.07), in: Capsule())
        }
    }

    private func movementContent(_ exercise: OfficeExercise) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(copy.message)\(exercise.summary)")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)

            ExerciseAnimationView(exercise: exercise)
                .frame(height: 255)

            HStack(spacing: 12) {
                Label(exercise.dose, systemImage: "timer")
                    .font(.callout.weight(.medium))
                Spacer()
                Button("换一个动作") {
                    store.showMovementReminder(excluding: exercise.id)
                }
                .buttonStyle(.bordered)
                Button("完成一次") {
                    store.check("move")
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .tint(livingGreen)
            }
        }
    }

    private var eyesContent: some View {
        HStack(spacing: 28) {
            ZStack {
                Circle().fill(mist).frame(width: 150, height: 150)
                Circle().stroke(livingGreen.opacity(0.18), lineWidth: 12).frame(width: 116, height: 116)
                Image(systemName: "eye.fill")
                    .font(.system(size: 43, weight: .light))
                    .foregroundStyle(livingGreen)
            }
            VStack(alignment: .leading, spacing: 13) {
                Text(copy.message)
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text("让视线离开屏幕，眨眨眼，肩膀也一起松下来。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("我看完远处了") {
                    store.check("eyes")
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(livingGreen)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(queuedCount > 0 ? "还有 \(queuedCount) 个提醒，关掉后会依次出现" : "按住标题区域可以移动弹窗")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("10 分钟后再提醒") {
                store.snooze(kind)
                onClose()
            }
            .buttonStyle(.plain)
            .font(.callout.weight(.medium))
            .foregroundStyle(livingGreen)
        }
    }

    private var title: String {
        switch kind {
        case .water, .eyes: copy.headline
        case let .move(exercise): exercise.title
        case .custom(let name): name
        }
    }
}

private struct FourLeafMark: View {
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? color : color.opacity(0.72))
                    .frame(width: 17, height: 24)
                    .offset(y: -8)
                    .rotationEffect(.degrees(Double(index) * 90))
            }
            Circle().fill(Color.white).frame(width: 7, height: 7)
        }
        .accessibilityHidden(true)
    }
}

private struct PopupChoiceButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .background(tint.opacity(configuration.isPressed ? 0.16 : 0.075), in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(tint.opacity(configuration.isPressed ? 0.35 : 0.13), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
