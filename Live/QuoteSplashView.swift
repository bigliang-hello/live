import SwiftUI

/// 每日一句的全屏开屏动画,只在每天第一次展示主窗口时播放一次。
/// 走拼多多式的喜庆路子:大红底、旋转金色光芒、彩带雨、逐字弹出的
/// 大号金字,配一枚会跳的「收下」按钮;点任意处或 9 秒后自动收场。
struct QuoteSplash: View {
    let text: String
    var onDismiss: () -> Void

    @State private var appeared = false
    @State private var spin = false
    @State private var bounce = false
    @State private var pulse = false
    @State private var finished = false

    private let goldLight = Color(red: 1.00, green: 0.90, blue: 0.52)
    private let gold = Color(red: 1.00, green: 0.82, blue: 0.35)
    private let goldDeep = Color(red: 0.93, green: 0.55, blue: 0.10)

    var body: some View {
        ZStack {
            background
            rays
            ConfettiRain()
            content
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
        .onExitCommand(perform: dismiss)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { appeared = true }
            withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) { spin = true }
            withAnimation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true)) { bounce = true }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
        .task {
            try? await Task.sleep(for: .seconds(9))
            dismiss()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日打气签:\(text)。点任意处收起。")
    }

    // MARK: - 背景与光芒

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.91, green: 0.17, blue: 0.13), Color(red: 0.62, green: 0.04, blue: 0.07)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(colors: [gold.opacity(0.30), .clear], center: .center, startRadius: 30, endRadius: 460)
        }
    }

    /// 从中心铺开的 14 根金色光柱,整体缓慢旋转,像转动的太阳光。
    private var rays: some View {
        ZStack {
            ForEach(0..<14, id: \.self) { index in
                RoundedRectangle(cornerRadius: 60)
                    .fill(gold.opacity(0.08))
                    .frame(width: 1400, height: 54)
                    .offset(y: -600)
                    .rotationEffect(.degrees(Double(index) / 14 * 360))
            }
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .allowsHitTesting(false)
    }

    // MARK: - 正片

    private var content: some View {
        VStack(spacing: 26) {
            Text("🔥")
                .font(.system(size: 62))
                .scaleEffect(bounce ? 1.14 : 0.92)
                .rotationEffect(.degrees(bounce ? -6 : 6))
                .padding(.bottom, 4)

            badge

            quoteText

            Button(action: dismiss) {
                Text("收下 · 开工大吉")
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.55, green: 0.06, blue: 0.06))
                    .padding(.horizontal, 46)
                    .frame(height: 58)
                    .background(
                        LinearGradient(colors: [goldLight, gold, goldDeep], startPoint: .top, endPoint: .bottom),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule().stroke(.white.opacity(0.55), lineWidth: 1.5)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
            }
            .buttonStyle(.plain)
            .scaleEffect(pulse ? 1.045 : 0.97)
            .padding(.top, 16)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("收下今日打气签")

            Text("点任意处收起")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 2)
        }
        .padding(44)
        .scaleEffect(appeared ? 1 : 0.86)
        .opacity(appeared ? 1 : 0)
    }

    /// 金边小胶囊:标出这是「今日打气签」。
    private var badge: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles.fill").font(.system(size: 12))
            Text("今 日 打 气 签").font(.system(size: 14, weight: .heavy)).tracking(3)
            Image(systemName: "sparkles.fill").font(.system(size: 12))
        }
        .foregroundStyle(gold)
        .padding(.horizontal, 22)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .overlay {
            Capsule().stroke(gold.opacity(0.7), lineWidth: 1.2)
        }
    }

    /// 语录逐字弹出:每个字带一点旋转地从缩小态弹到位,依次错开。
    private var quoteText: some View {
        let chars = Array(text)
        let size: CGFloat = chars.count > 26 ? 34 : chars.count > 14 ? 44 : 54
        return FlowLayout(lineSpacing: 16, itemSpacing: 2) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [goldLight, gold, goldDeep], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: Color(red: 0.45, green: 0.05, blue: 0.05).opacity(0.55), radius: 3, y: 2)
                    .scaleEffect(appeared ? 1 : 0.1)
                    .rotationEffect(.degrees(appeared ? 0 : -25))
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.58).delay(0.25 + Double(index) * 0.045),
                        value: appeared
                    )
            }
        }
        .frame(maxWidth: 720)
    }

    private func dismiss() {
        guard !finished else { return }
        finished = true
        onDismiss()
    }
}

/// 彩带雨:Canvas 里按时间推算每条彩带的位置,种子伪随机保证形状稳定不闪。
private struct ConfettiRain: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<64 {
                    let x = Self.rand(index, 1) * size.width
                    let speed = 70 + Self.rand(index, 2) * 150
                    let rawY = Self.rand(index, 3) * size.height + t * speed
                    let y = rawY.truncatingRemainder(dividingBy: size.height + 70) - 35
                    let rotation = Angle.degrees(
                        t * 160 * (Self.rand(index, 4) - 0.5) * 4 + Self.rand(index, 5) * 360
                    )
                    let w = 5 + Self.rand(index, 6) * 4
                    let h = 10 + Self.rand(index, 7) * 6
                    var ctx = context
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: rotation)
                    ctx.opacity = 0.55 + Self.rand(index, 8) * 0.45
                    let color = Self.palette[Int(Self.rand(index, 9) * 4) % 4]
                    if Self.rand(index, 10) > 0.55 {
                        ctx.fill(Circle().path(in: CGRect(x: -w / 2, y: -w / 2, width: w, height: w)), with: .color(color))
                    } else {
                        ctx.fill(Path(CGRect(x: -w / 2, y: -h / 2, width: w, height: h)), with: .color(color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.86, blue: 0.40),
        .white,
        Color(red: 1.00, green: 0.46, blue: 0.36),
        Color(red: 1.00, green: 0.65, blue: 0.18)
    ]

    /// 稳定的伪随机:同 (index, seed) 永远同值,不随帧抖动。
    private static func rand(_ i: Int, _ seed: Double) -> Double {
        let value = sin(Double(i) * 127.1 + seed * 311.7) * 43758.5453
        return value - value.rounded(.down)
    }
}

/// 极简流式布局:逐字弹出的一串文字按宽度自动换行。
private struct FlowLayout: Layout {
    var lineSpacing: CGFloat = 12
    var itemSpacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxLine: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, maxWidth > 0, x + size.width > maxWidth {
                maxLine = max(maxLine, x - itemSpacing)
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            x += size.width + itemSpacing
            lineHeight = max(lineHeight, size.height)
        }
        maxLine = max(maxLine, x - (subviews.isEmpty ? 0 : itemSpacing))
        return CGSize(width: maxWidth > 0 ? maxWidth : maxLine, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + itemSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
