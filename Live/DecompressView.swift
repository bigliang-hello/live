import SwiftUI
import AVFAudio

private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
private let woodLight = Color(red: 0.72, green: 0.5, blue: 0.32)
private let woodDeep = Color(red: 0.42, green: 0.26, blue: 0.14)
private let meritGold = Color(red: 0.72, green: 0.5, blue: 0.15)
private let warmPaper = Color(red: 0.97, green: 0.92, blue: 0.83)
private let bubbleMint = Color(red: 0.82, green: 0.91, blue: 0.89)

/// 「解压」页:电子木鱼、无限泡泡纸两件一分钟的小玩具。
/// 玩具音效全部运行时合成,不打包音频资源。
struct DecompressView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .bottom, spacing: 28) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("一分钟解压", systemImage: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(green)
                    Text("给脑子放个一分钟的假。")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text("敲一下、戳一颗，没有目标，也不需要坚持。")
                        .font(.system(size: 14))
                        .foregroundStyle(ink.opacity(0.56))
                }
                Spacer()
                Text("不计效率 · 只管手感")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(green)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(green.opacity(0.08), in: Capsule())
                    .overlay { Capsule().stroke(green.opacity(0.12), lineWidth: 1) }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    WoodFishCard().frame(maxWidth: .infinity)
                    BubbleWrapCard().frame(maxWidth: .infinity)
                }
                VStack(spacing: 16) {
                    WoodFishCard()
                    BubbleWrapCard()
                }
            }
        }
    }
}

/// 卡片抬头:图标、玩具名、说明与明确的操作提示。
private func toyHeader<Icon: View>(
    _ title: String,
    caption: String,
    action: String,
    accent: Color,
    @ViewBuilder icon: () -> Icon
) -> some View {
    HStack(spacing: 11) {
        icon()
            .foregroundStyle(accent)
            .frame(width: 36, height: 36)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(caption).font(.system(size: 11)).foregroundStyle(ink.opacity(0.5))
        }
        Spacer(minLength: 8)
        Text(action)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.white.opacity(0.58), in: Capsule())
    }
}

// MARK: - 电子木鱼

/// 头部使用的专属木鱼符号，避免把木鱼误读成普通锤子工具。
private struct WoodFishGlyph: View {
    var body: some View {
        ZStack {
            WoodFishBodyShape()
                .fill(
                    LinearGradient(
                        colors: [woodLight, woodDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 18)
                .offset(y: 2)
            WoodFishSlitShape()
                .fill(Color(red: 0.28, green: 0.17, blue: 0.08))
                .frame(width: 18, height: 8)
                .offset(x: 1, y: 1)
            Capsule()
                .fill(woodDeep)
                .frame(width: 13, height: 3)
                .rotationEffect(.degrees(-18))
                .offset(x: 7, y: -9)
            Circle()
                .fill(woodLight)
                .frame(width: 6, height: 6)
                .offset(x: 1, y: -7)
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }
}

/// 电子木鱼常见的侧视轮廓：上部拱起、右侧收尖、底部饱满。
private struct WoodFishBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.73))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.16),
            control1: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.55),
            control2: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.27)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.08),
            control1: CGPoint(x: rect.minX + rect.width * 0.43, y: rect.minY + rect.height * 0.02),
            control2: CGPoint(x: rect.minX + rect.width * 0.61, y: rect.minY + rect.height * 0.01)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.39),
            control1: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.13),
            control2: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.27)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.91, y: rect.minY + rect.height * 0.75),
            control1: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.47),
            control2: CGPoint(x: rect.minX + rect.width * 0.96, y: rect.minY + rect.height * 0.64)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.55, y: rect.minY + rect.height * 0.96),
            control1: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.91),
            control2: CGPoint(x: rect.minX + rect.width * 0.68, y: rect.minY + rect.height * 0.98)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.minY + rect.height * 0.88),
            control1: CGPoint(x: rect.minX + rect.width * 0.39, y: rect.minY + rect.height * 0.96),
            control2: CGPoint(x: rect.minX + rect.width * 0.25, y: rect.minY + rect.height * 0.88)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.73),
            control1: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.9),
            control2: CGPoint(x: rect.minX + rect.width * 0.03, y: rect.minY + rect.height * 0.81)
        )
        path.closeSubpath()
        return path
    }
}

/// 从左侧内腔延伸到右上方的楔形共鸣槽，与用户参考图的剪影一致。
private struct WoodFishSlitShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.72))
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.9, y: rect.minY + rect.height * 0.08),
            control1: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.minY + rect.height * 0.5),
            control2: CGPoint(x: rect.minX + rect.width * 0.72, y: rect.minY + rect.height * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.95, y: rect.minY + rect.height * 0.25),
            control1: CGPoint(x: rect.minX + rect.width * 0.94, y: rect.minY + rect.height * 0.1),
            control2: CGPoint(x: rect.minX + rect.width * 0.97, y: rect.minY + rect.height * 0.18)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.91),
            control1: CGPoint(x: rect.minX + rect.width * 0.69, y: rect.minY + rect.height * 0.36),
            control2: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.minY + rect.height * 0.77)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.72),
            control1: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.minY + rect.height * 0.91),
            control2: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.78)
        )
        path.closeSubpath()
        return path
    }
}

private struct WoodFishGrain: View {
    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                Ellipse()
                    .trim(from: 0.08, to: 0.73)
                    .stroke(woodDeep.opacity(0.14), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .frame(width: CGFloat(28 + index * 13), height: CGFloat(14 + index * 7))
                    .rotationEffect(.degrees(-10))
            }
        }
        .frame(width: 58, height: 34)
        .accessibilityHidden(true)
    }
}

private struct TempleCushion: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.08))
                .frame(width: 156, height: 12)
                .offset(y: 8)
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.56, green: 0.25, blue: 0.16), Color(red: 0.4, green: 0.15, blue: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 138, height: 22)
            HStack(spacing: 17) {
                ForEach(0 ..< 5, id: \.self) { _ in
                    Diamond()
                        .fill(meritGold.opacity(0.5))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(width: 160, height: 34)
        .accessibilityHidden(true)
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct WoodFishMallet: View {
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [woodDeep, Color(red: 0.66, green: 0.43, blue: 0.24)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 96, height: 7)
                .offset(x: 10)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.82, green: 0.64, blue: 0.44), woodDeep],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 14
                    )
                )
                .frame(width: 25, height: 25)
                .overlay { Circle().stroke(.white.opacity(0.16), lineWidth: 1) }
        }
        .frame(width: 108, height: 26, alignment: .leading)
        .shadow(color: woodDeep.opacity(0.12), radius: 3, y: 2)
        .accessibilityHidden(true)
    }
}

private struct WoodFishCard: View {
    @State private var todayCount = 0
    @State private var totalCount = 0
    @State private var knockDown = false
    @State private var blessings: [Blessing] = []

    private struct Blessing: Identifiable {
        let id: UUID
        let x: CGFloat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            woodFishHeader
            interactionArea
            meritBar
        }
        .padding(22)
        .frame(height: 404, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [warmPaper.opacity(0.9), Color.white.opacity(0.86)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(meritGold.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: woodDeep.opacity(0.06), radius: 16, y: 7)
        .onAppear(perform: loadMerit)
    }

    private var woodFishHeader: some View {
        toyHeader(
            "电子木鱼",
            caption: "一声清脆，先把杂念放下",
            action: "点击敲击",
            accent: woodDeep
        ) {
            WoodFishGlyph()
        }
    }

    private var interactionArea: some View {
        ZStack {
            resonanceRings
            animatedWoodenFish
            blessingLayer
        }
        .frame(height: 226)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: knock)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("电子木鱼，今日功德 \(todayCount)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("敲击")) {
            knock()
        }
    }

    private var animatedWoodenFish: some View {
        woodenFish
            .scaleEffect(1.18)
            .scaleEffect(
                x: knockDown ? 1.04 : 1,
                y: knockDown ? 0.93 : 1,
                anchor: .bottom
            )
    }

    private var blessingLayer: some View {
        ForEach(blessings) { blessing in
            BlessingText(x: blessing.x)
        }
    }

    private var meritBar: some View {
        HStack(spacing: 0) {
            meritStat("今日功德", value: todayCount, symbol: "sun.max.fill")
            Rectangle()
                .fill(woodDeep.opacity(0.1))
                .frame(width: 1, height: 34)
            meritStat("累计敲击", value: totalCount, symbol: "clock.arrow.circlepath")
        }
        .padding(.vertical, 11)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var resonanceRings: some View {
        ZStack {
            Circle()
                .stroke(meritGold.opacity(0.08), lineWidth: 1)
                .frame(width: 168, height: 168)
            Circle()
                .stroke(meritGold.opacity(0.1), lineWidth: 1)
                .frame(width: 128, height: 128)
            Circle()
                .stroke(meritGold.opacity(0.12), lineWidth: 1)
                .frame(width: 88, height: 88)
        }
    }

    private func meritStat(_ label: String, value: Int, symbol: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(meritGold)
                .frame(width: 28, height: 28)
                .background(meritGold.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ink.opacity(0.46))
                Text("\(value)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(woodDeep)
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    /// 木鱼本体:按照参考图绘制的侧视卵石轮廓与斜向共鸣槽。
    private var woodenFish: some View {
        ZStack {
            TempleCushion()
                .offset(y: 58)

            WoodFishBodyShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.49, blue: 0.28),
                            Color(red: 0.59, green: 0.31, blue: 0.16),
                            Color(red: 0.34, green: 0.14, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 166, height: 126)
                .offset(y: 3)
                .overlay {
                    WoodFishBodyShape().fill(
                        RadialGradient(
                            colors: [.white.opacity(0.29), .clear],
                            center: UnitPoint(x: 0.3, y: 0.18),
                            startRadius: 3,
                            endRadius: 88
                        )
                    )
                    .frame(width: 166, height: 126)
                    .offset(y: 3)
                }
                .overlay {
                    WoodFishBodyShape()
                        .stroke(woodDeep.opacity(0.3), lineWidth: 1)
                        .frame(width: 166, height: 126)
                        .offset(y: 3)
                }

            WoodFishGrain()
                .offset(x: -36, y: 31)

            // 深色楔形开口从左侧内腔延伸到右上方，形成典型电子木鱼剪影。
            WoodFishSlitShape()
                .fill(Color(red: 0.18, green: 0.065, blue: 0.035))
                .frame(width: 128, height: 66)
                .offset(x: 9, y: -4)
            WoodFishSlitShape()
                .stroke(
                    Color(red: 0.9, green: 0.66, blue: 0.4).opacity(0.42),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 124, height: 62)
                .offset(x: 9, y: -7)

            WoodFishMallet()
                // 落槌只触及开口上沿，避免槌头陷入共鸣腔。
                .rotationEffect(.degrees(knockDown ? -18 : 0), anchor: .trailing)
                .offset(x: 63, y: -75)

            ZStack {
                Capsule().frame(width: 3, height: 10).rotationEffect(.degrees(-28)).offset(x: -8)
                Capsule().frame(width: 3, height: 10).offset(y: -5)
                Capsule().frame(width: 3, height: 10).rotationEffect(.degrees(28)).offset(x: 8)
            }
            .foregroundStyle(meritGold)
            .offset(x: 22, y: -43)
            .opacity(knockDown ? 0.8 : 0)
        }
        .frame(width: 210, height: 176)
    }

    private func knock() {
        // 槌头先落到槽边，接触瞬间发声，再用弹簧回到准备位置。
        withAnimation(.easeIn(duration: 0.11)) {
            knockDown = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(110))
            FidgetSound.shared.playWood()
            try? await Task.sleep(for: .milliseconds(35))
            withAnimation(.spring(response: 0.3, dampingFraction: 0.58)) {
                knockDown = false
            }
        }

        let blessing = Blessing(id: UUID(), x: CGFloat.random(in: -34 ... 34))
        blessings.append(blessing)
        Task {
            try? await Task.sleep(for: .seconds(1))
            blessings.removeAll { $0.id == blessing.id }
        }
        recordMerit()
    }

    private func loadMerit() {
        let defaults = UserDefaults.standard
        totalCount = defaults.integer(forKey: "woodfish.total")
        todayCount = defaults.double(forKey: "woodfish.day") == Self.dayNumber
            ? defaults.integer(forKey: "woodfish.today")
            : 0
    }

    private func recordMerit() {
        let defaults = UserDefaults.standard
        if defaults.double(forKey: "woodfish.day") != Self.dayNumber {
            defaults.set(Self.dayNumber, forKey: "woodfish.day")
            todayCount = 0
        }
        todayCount += 1
        totalCount += 1
        defaults.set(todayCount, forKey: "woodfish.today")
        defaults.set(totalCount, forKey: "woodfish.total")
    }

    private static var dayNumber: Double {
        Calendar.current.startOfDay(for: .now).timeIntervalSince1970 / 86_400
    }
}

/// 飘起来的「功德 +1」。
private struct BlessingText: View {
    let x: CGFloat
    @State private var risen = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .bold))
            Text("功德 +1")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
            .foregroundStyle(woodDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.white.opacity(0.94), in: Capsule())
            .overlay {
                Capsule().stroke(meritGold.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: woodDeep.opacity(0.13), radius: 5, y: 2)
            .scaleEffect(risen ? 1.03 : 0.92)
            .offset(x: x, y: risen ? -112 : -76)
            .opacity(risen ? 0 : 1)
            .onAppear {
                Task {
                    try? await Task.sleep(for: .milliseconds(140))
                    withAnimation(.easeOut(duration: 0.72)) { risen = true }
                }
            }
    }
}

// MARK: - 无限泡泡纸

private struct BubbleWrapCard: View {
    @State private var popped: Set<Int> = []
    private let columns = 8
    private let rows = 6
    private var total: Int { columns * rows }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                toyHeader(
                    "无限泡泡纸",
                    caption: "点一下，或按住连续划过",
                    action: "拖动也可以",
                    accent: green
                ) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
            }

            GeometryReader { proxy in
                grid(size: proxy.size)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 13)
            .frame(height: CGFloat(rows) * 36 + 20)
            .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }

            VStack(spacing: 9) {
                ProgressView(value: Double(popped.count), total: Double(total))
                    .progressViewStyle(.linear)
                    .tint(green)

                HStack {
                    Text(popped.count >= total ? "全部戳破了，换一张继续" : "已戳破 \(popped.count) / \(total)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(popped.count >= total ? green : ink.opacity(0.5))
                        .contentTransition(.numericText())
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.25)) { popped.removeAll() }
                    } label: {
                        Label("铺新的一张", systemImage: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(green)
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(.white.opacity(0.65), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(22)
        .frame(height: 404, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [bubbleMint.opacity(0.88), Color.white.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(green.opacity(0.11), lineWidth: 1)
        }
        .shadow(color: green.opacity(0.06), radius: 16, y: 7)
    }

    private func grid(size: CGSize) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns), spacing: 6) {
            ForEach(0 ..< total, id: \.self) { index in
                bubble(popped.contains(index))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("泡泡 \(index + 1)")
                    .accessibilityValue(popped.contains(index) ? "已戳破" : "未戳破")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction(named: Text("戳破")) {
                        pop(index: index)
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in pop(at: value.location, in: size) }
        )
    }

    /// 把手指位置换算成格子下标,按住扫过时能一路戳下去。
    private func pop(at point: CGPoint, in size: CGSize) {
        let column = Int(point.x / (size.width / CGFloat(columns)))
        let row = Int(point.y / 36)
        guard (0 ..< rows).contains(row), (0 ..< columns).contains(column) else { return }
        guard point.y - CGFloat(row) * 36 <= 30 else { return }
        pop(index: row * columns + column)
    }

    private func pop(index: Int) {
        guard !popped.contains(index) else { return }
        popped.insert(index)
        FidgetSound.shared.playPop()
    }

    private func bubble(_ isPopped: Bool) -> some View {
        ZStack {
            // 没破:鼓起的泡泡,左上带一点高光。
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.94, green: 0.96, blue: 0.95), Color(red: 0.7, green: 0.78, blue: 0.76)],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 20
                        )
                    )
                    .frame(width: 24)
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 7)
                    .offset(x: -5, y: -5)
            }
            .opacity(isPopped ? 0 : 1)
            .shadow(color: .black.opacity(isPopped ? 0 : 0.07), radius: 2, y: 1)

            // 破了:瘪下去的浅坑。
            ZStack {
                Circle().fill(Color(red: 0.84, green: 0.87, blue: 0.85)).frame(width: 22)
                Circle().stroke(Color.black.opacity(0.08), lineWidth: 1).frame(width: 22)
                Circle().fill(Color.black.opacity(0.045)).frame(width: 11)
            }
            .opacity(isPopped ? 1 : 0)
            .scaleEffect(isPopped ? 1 : 0.8)
        }
        .frame(height: 30)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.24, dampingFraction: 0.6), value: isPopped)
    }
}

// MARK: - 合成音效

/// 运行时合成玩具音效:木鱼由短促敲击噪声激发多组木腔共振,泡泡是上扫短音。
/// 八枚播放节点轮转,按住扫泡泡时声音能叠在一起。
private final class FidgetSound {
    static let shared = FidgetSound()

    private let engine = AVAudioEngine()
    private let players = (0 ..< 8).map { _ in AVAudioPlayerNode() }
    private var cursor = 0
    private let recordedWood: AVAudioPCMBuffer?
    private let woods: [AVAudioPCMBuffer]
    private let pops: [AVAudioPCMBuffer]

    private init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        recordedWood = Self.loadWoodSample(format: format)
        woods = (0 ..< 4).map { Self.renderWood(format: format, variant: $0) }
        pops = (0 ..< 4).map { Self.renderPop(format: format, base: 300 + Double($0) * 85) }
        for player in players {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
        }
    }

    func playWood() {
        play(recordedWood ?? woods.randomElement()!, volume: recordedWood == nil ? 0.76 : 0.84)
    }
    func playPop() { play(pops.randomElement()!, volume: 0.4) }

    private func play(_ buffer: AVAudioPCMBuffer, volume: Float) {
        guard startIfNeeded() else { return }
        let node = players[cursor]
        cursor = (cursor + 1) % players.count
        node.stop()
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil)
        node.play()
    }

    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    /// 读取 CC0 实录木鱼采样并混为单声道。合成音只在资源缺失时兜底。
    private static func loadWoodSample(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let url = Bundle.main.url(forResource: "mokugyo", withExtension: "wav")
            ?? Bundle.main.url(forResource: "mokugyo", withExtension: "wav", subdirectory: "FidgetSounds")
        guard let url else { return nil }

        do {
            let file = try AVAudioFile(forReading: url)
            guard file.processingFormat.sampleRate == format.sampleRate else { return nil }
            let frameCount = AVAudioFrameCount(file.length)
            guard let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
                return nil
            }
            try file.read(into: source)
            guard
                let sourceChannels = source.floatChannelData,
                let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: source.frameLength),
                let outputChannel = output.floatChannelData?[0]
            else {
                return nil
            }

            output.frameLength = source.frameLength
            let channelCount = Int(source.format.channelCount)
            var peak: Float = 0
            for frame in 0 ..< Int(source.frameLength) {
                var mixed: Float = 0
                for channel in 0 ..< channelCount {
                    mixed += sourceChannels[channel][frame]
                }
                mixed /= Float(max(channelCount, 1))
                outputChannel[frame] = mixed
                peak = max(peak, abs(mixed))
            }

            // 留出余量，防止多个快速敲击叠加时削波。
            if peak > 0 {
                let gain = min(0.86 / peak, 1.6)
                for frame in 0 ..< Int(output.frameLength) {
                    outputChannel[frame] *= gain
                }
            }
            return output
        } catch {
            return nil
        }
    }

    /// 木鱼「笃」:极短的木槌冲击激发四个非整数倍共振峰。
    /// 高频衰减得更快，低频木腔多留几十毫秒，避免纯正弦叠加产生金属感。
    private static func renderWood(format: AVAudioFormat, variant: Int) -> AVAudioPCMBuffer {
        let count = Int(format.sampleRate * 0.22)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        let data = buffer.floatChannelData![0]
        let sampleRate = format.sampleRate
        let baseFrequencies = [412.0, 425.0, 439.0, 452.0]
        let base = baseFrequencies[variant % baseFrequencies.count]
        let ratios = [1.0, 1.47, 2.08, 2.73]
        let amplitudes = [0.78, 0.38, 0.18, 0.08]
        let decays = [0.105, 0.068, 0.043, 0.026]
        var phases = [Double](repeating: 0, count: ratios.count)
        var noiseState = 0.0
        var seed = UInt64(0x9E3779B97F4A7C15) &+ UInt64(variant * 97)

        for n in 0 ..< count {
            let t = Double(n) / sampleRate
            let pitchBend = 1 + 0.032 * exp(-t / 0.012)
            let bodyAttack = min(t / 0.0014, 1)
            var body = 0.0

            for index in ratios.indices {
                let frequency = base * ratios[index] * pitchBend
                phases[index] += 2 * .pi * frequency / sampleRate
                let envelope = bodyAttack * exp(-t / decays[index])
                body += amplitudes[index] * envelope * sin(phases[index])
            }

            // 相关噪声比白噪声更钝，保留木槌触碰木面的颗粒感。
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let whiteNoise = Double(seed >> 11) / 9_007_199_254_740_992.0 * 2 - 1
            noiseState = noiseState * 0.68 + whiteNoise * 0.32
            let impact = noiseState * exp(-t / 0.0055) * min(t / 0.00035, 1) * 0.5
            let thump = sin(2 * .pi * 184 * t) * exp(-t / 0.021) * 0.24
            let mixed = body + impact + thump
            data[n] = Float(tanh(mixed * 1.08) * 0.78)
        }
        return buffer
    }

    /// 泡泡「啵」:基频先往上扫,再短促衰减,听感像气泡破掉。
    private static func renderPop(format: AVAudioFormat, base: Double) -> AVAudioPCMBuffer {
        let count = Int(format.sampleRate * 0.07)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
        buffer.frameLength = AVAudioFrameCount(count)
        let data = buffer.floatChannelData![0]
        var phase = 0.0
        for n in 0 ..< count {
            let t = Double(n) / format.sampleRate
            let sweep = 1 + 1.15 * min(t / 0.02, 1)
            phase += 2 * .pi * base * sweep / format.sampleRate
            let envelope = min(t / 0.002, 1) * exp(-t / 0.022)
            data[n] = Float(sin(phase) * envelope * 0.9)
        }
        return buffer
    }
}
