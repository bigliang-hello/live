import SwiftUI
import AVFoundation

/// 一种白噪音：资源名与 NapSounds/<id>.m4a 对应。
/// 音频来自开源项目 Tosencen/XMSLEEP（Unlicense 公有领域）。
struct NapSound: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let symbol: String

    static let catalog: [NapSound] = [
        // 雨声
        NapSound(id: "light-rain", name: "小雨", category: "雨声", symbol: "cloud.drizzle.fill"),
        NapSound(id: "heavy-rain", name: "大雨", category: "雨声", symbol: "cloud.heavyrain.fill"),
        NapSound(id: "rain-on-umbrella", name: "伞上的雨", category: "雨声", symbol: "umbrella"),
        NapSound(id: "rain-on-tent", name: "帐篷里的雨", category: "雨声", symbol: "tent.fill"),
        NapSound(id: "thunderstorm", name: "雷雨", category: "雨声", symbol: "cloud.bolt.rain.fill"),
        // 自然
        NapSound(id: "waves", name: "海浪", category: "自然", symbol: "water.waves"),
        NapSound(id: "waterfall", name: "瀑布", category: "自然", symbol: "drop.triangle.fill"),
        NapSound(id: "campfire", name: "篝火", category: "自然", symbol: "flame.fill"),
        NapSound(id: "wind", name: "风声", category: "自然", symbol: "wind"),
        NapSound(id: "wind-in-trees", name: "林间风", category: "自然", symbol: "tree.fill"),
        NapSound(id: "lake", name: "湖边", category: "自然", symbol: "drop.circle.fill"),
        NapSound(id: "walk-on-leaves", name: "踩过落叶", category: "自然", symbol: "leaf.fill"),
        NapSound(id: "walk-in-snow", name: "雪地漫步", category: "自然", symbol: "snowflake"),
        // 动物
        NapSound(id: "birds", name: "鸟鸣", category: "动物", symbol: "bird.fill"),
        NapSound(id: "crickets", name: "夏夜虫鸣", category: "动物", symbol: "moon.stars.fill"),
        NapSound(id: "cat-purring", name: "猫咪呼噜", category: "动物", symbol: "cat.fill"),
        NapSound(id: "owl", name: "猫头鹰", category: "动物", symbol: "moon.haze.fill"),
        NapSound(id: "whale", name: "鲸鸣", category: "动物", symbol: "fish.fill"),
        // 场所
        NapSound(id: "cafe", name: "咖啡馆", category: "场所", symbol: "cup.and.saucer.fill"),
        NapSound(id: "library", name: "图书馆", category: "场所", symbol: "books.vertical.fill"),
        NapSound(id: "office", name: "办公室", category: "场所", symbol: "briefcase.fill"),
        NapSound(id: "kitchen", name: "厨房", category: "场所", symbol: "fork.knife"),
        NapSound(id: "night-village", name: "夜晚的村落", category: "场所", symbol: "house.fill"),
        NapSound(id: "temple", name: "寺院", category: "场所", symbol: "building.columns.fill"),
        NapSound(id: "underwater", name: "水下", category: "场所", symbol: "figure.pool.swim"),
        // 器物
        NapSound(id: "typewriter", name: "打字机", category: "器物", symbol: "keyboard"),
        NapSound(id: "wind-chimes", name: "风铃", category: "器物", symbol: "music.note"),
        NapSound(id: "singing-bowl", name: "颂钵", category: "器物", symbol: "moon.dust.fill"),
        NapSound(id: "ceiling-fan", name: "吊扇", category: "器物", symbol: "fanblades.fill"),
        NapSound(id: "brown-noise", name: "布朗噪声", category: "器物", symbol: "waveform")
    ]

    static let categories: [String] = ["雨声", "自然", "动物", "场所", "器物"]

    static let fallback = catalog[0]
}

struct NapPlan: Identifiable {
    let sound: NapSound
    let minutes: Int
    let volume: Double
    var id: String { sound.id }
}

/// 白噪音引擎：AVAudioPlayer 循环播放本地资源，带淡出停止。
final class NapEngine {
    static let shared = NapEngine()

    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private(set) var isPlaying = false

    private func url(for sound: NapSound) -> URL? {
        Bundle.main.url(forResource: sound.id, withExtension: "m4a")
            ?? Bundle.main.url(forResource: sound.id, withExtension: "m4a", subdirectory: "NapSounds")
    }

    func play(_ sound: NapSound, volume: Double = 0.6) {
        stop(fade: 0)
        guard let url = url(for: sound) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = Float(volume)
            player.prepareToPlay()
            player.play()
            self.player = player
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func setVolume(_ value: Double) {
        player?.volume = Float(value)
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = player?.isPlaying == true
    }

    func stop(fade seconds: Double = 1.2) {
        fadeTimer?.invalidate()
        fadeTimer = nil
        guard let player else { return }
        guard seconds > 0 else {
            player.stop()
            self.player = nil
            isPlaying = false
            return
        }
        var remaining = max(1, Int(seconds / 0.06))
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] timer in
            remaining -= 1
            player.volume = max(0, player.volume * 0.8)
            if remaining <= 0 {
                timer.invalidate()
                player.stop()
                self?.player = nil
                self?.isPlaying = false
            }
        }
    }
}

/// 「小憩」标签页：30 种白噪音选一种，试听，然后带着呼吸节奏小睡一会儿。
struct NapTabView: View {
    @Bindable var store: WellnessStore
    @State private var selected = NapTabView.storedSound()
    @State private var previewing = false
    @State private var volume = UserDefaults.standard.object(forKey: "nap.volume") as? Double ?? 0.6
    @State private var minutes = NapTabView.storedMinutes()
    @State private var napPlan: NapPlan?

    /// 上次的选择会记住：下次打开还是熟悉的声音、音量和时长。
    private static func storedSound() -> NapSound {
        guard let id = UserDefaults.standard.string(forKey: "nap.sound") else { return .fallback }
        return NapSound.catalog.first { $0.id == id } ?? .fallback
    }

    private static func storedMinutes() -> Int {
        let value = UserDefaults.standard.integer(forKey: "nap.minutes")
        return [3, 5, 10, 15, 30].contains(value) ? value : 5
    }

    private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
    private let green = Color(red: 0.18, green: 0.43, blue: 0.35)

    var body: some View {
        VStack(spacing: 0) {
            // 声音网格在滚动区里；播放条固定在页面底部，不用滚到底才能开始小憩。
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    ForEach(NapSound.categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category).font(.title3.bold())
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                                ForEach(NapSound.catalog.filter { $0.category == category }) { sound in
                                    soundCard(sound)
                                }
                            }
                        }
                    }
                }
                .padding(36)
                .padding(.bottom, 8)
                .frame(maxWidth: 1100, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            playerBar
                .padding(.horizontal, 28)
                .padding(.vertical, 15)
                .background(Color.white.opacity(0.96))
                .overlay(alignment: .top) {
                    Rectangle().fill(ink.opacity(0.07)).frame(height: 1)
                }
                .shadow(color: .black.opacity(0.045), radius: 14, y: -5)
        }
        .sheet(item: $napPlan) { plan in
            NapSheet(plan: plan, store: store, onFinished: { previewing = false })
        }
        .onDisappear {
            previewing = false
            NapEngine.shared.stop(fade: 0)
        }
        .onChange(of: selected) { _, new in
            UserDefaults.standard.set(new.id, forKey: "nap.sound")
        }
        .onChange(of: volume) { _, new in
            UserDefaults.standard.set(new, forKey: "nap.volume")
        }
        .onChange(of: minutes) { _, new in
            UserDefaults.standard.set(new, forKey: "nap.minutes")
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("闭上眼，去一个安静的地方。")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                Text("挑一种声音试听，合适就带着它小憩。声音来自开源项目 XMSLEEP（Unlicense 公有领域）。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("今天已小憩 \(store.count("rest")) 次")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func soundCard(_ sound: NapSound) -> some View {
        let isSelected = sound == selected
        return Button {
            if isSelected {
                previewing.toggle()
                if previewing {
                    NapEngine.shared.play(sound, volume: volume)
                } else {
                    NapEngine.shared.pause()
                }
            } else {
                selected = sound
                previewing = true
                NapEngine.shared.play(sound, volume: volume)
            }
        } label: {
            VStack(spacing: 10) {
                Image(systemName: sound.symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : green)
                    .frame(width: 42, height: 42)
                    .background(isSelected ? green : Color(red: 0.85, green: 0.92, blue: 0.86), in: Circle())
                Text(sound.name)
                    .font(.callout.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isSelected ? green.opacity(0.09) : Color.white,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? green.opacity(0.45) : Color.black.opacity(0.045))
        }
        // 试听中：卡片高度不变，右下角浮一个跳动的音轨条。
        .overlay(alignment: .bottomTrailing) {
            if previewing && isSelected {
                PlayingBarsMark(color: green)
                    .padding(.trailing, 10)
                    .padding(.bottom, 9)
                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: previewing)
        .accessibilityLabel("\(sound.category)，\(sound.name)\(isSelected ? "，已选中" : "")\(previewing && isSelected ? "，正在试听" : "")")
    }

    private var playerBar: some View {
        HStack(spacing: 14) {
            Button {
                previewing.toggle()
                if previewing {
                    NapEngine.shared.play(selected, volume: volume)
                } else {
                    NapEngine.shared.pause()
                }
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(green.opacity(0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: selected.symbol)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(green)
                        .frame(width: 44, height: 44)
                    Circle()
                        .fill(green)
                        .frame(width: 21, height: 21)
                        .overlay {
                            Image(systemName: previewing ? "pause.fill" : "play.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(previewing ? "暂停试听" : "试听\(selected.name)")

            VStack(alignment: .leading, spacing: 4) {
                Text(selected.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(selected.category)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    if previewing {
                        PlayingBarsMark(color: green)
                            .frame(width: 14)
                    }
                }
            }
            .frame(width: 82, alignment: .leading)

            HStack(spacing: 8) {
                Image(systemName: volume < 0.05 ? "speaker.slash.fill" : "speaker.wave.1.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Slider(value: $volume, in: 0...1) { _ in
                    NapEngine.shared.setVolume(volume)
                }
                .frame(width: 86)
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.black.opacity(0.035), in: Capsule())
            .accessibilityLabel("试听音量")

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text("小憩时长")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                GentleOptionPicker(options: [3, 5, 10, 15, 30], selection: $minutes)
            }
            .frame(height: 44)

            Button {
                previewing = false
                napPlan = NapPlan(sound: selected, minutes: minutes, volume: volume)
            } label: {
                Label("开始小憩", systemImage: "moon.zzz.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 42)
            }
            .buttonStyle(NapStartButtonStyle(color: green))
        }
    }
}

private struct NapStartButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                color.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 13)
            )
            .shadow(color: color.opacity(configuration.isPressed ? 0.08 : 0.16), radius: 7, y: 3)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 试听中的小音轨条：三根按相位此起彼伏的竖条，放在卡片右下角。
private struct PlayingBarsMark: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: barHeight(t: t, index: index))
                }
            }
            .frame(height: 13, alignment: .bottom)
        }
        .accessibilityHidden(true)
    }

    private func barHeight(t: Double, index: Int) -> CGFloat {
        let phase = t * 2 * .pi * 0.9 + Double(index) * (2 * .pi / 3)
        return 4 + CGFloat((sin(phase) + 1) / 2) * 9
    }
}

/// 小憩进行中的界面：4-7-8 呼吸圆 + 剩余时间，结束（或提前结束）后记录一次照顾。
struct NapSheet: View {
    let plan: NapPlan
    @Bindable var store: WellnessStore
    var onFinished: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    @State private var startedAt = Date.now
    @State private var finished = false

    private let accent = Color(red: 0.20, green: 0.48, blue: 0.36)

    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Label(plan.sound.name, systemImage: plan.sound.symbol)
                    .font(.headline)
                Text("小憩 \(plan.minutes) 分钟 · 结束后自动停止并记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let phase = breathPhase(at: timeline.date)
                let end = startedAt.addingTimeInterval(Double(plan.minutes * 60))
                ZStack {
                    Circle().fill(accent.opacity(0.07)).frame(width: 210, height: 210)
                    Circle()
                        .fill(accent.opacity(0.15))
                        .frame(width: 170, height: 170)
                        .scaleEffect(phase.scale)
                    VStack(spacing: 5) {
                        Text(phase.label)
                            .font(.title3.weight(.semibold))
                        Text(Self.clockString(max(0, end.timeIntervalSince(timeline.date))))
                            .font(.system(size: 34, weight: .light, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(height: 220)

            Text("跟着圆的节奏做 4-7-8 呼吸：吸气 4 秒，屏息 7 秒，慢慢呼气 8 秒。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("提前结束小憩") { finish() }
                .buttonStyle(.bordered)
        }
        .padding(36)
        .frame(width: 460, height: 470)
        .onAppear {
            startedAt = .now
            NapEngine.shared.play(plan.sound, volume: plan.volume)
        }
        .task {
            try? await Task.sleep(for: .seconds(Double(plan.minutes * 60)))
            finish()
        }
        .onDisappear {
            NapEngine.shared.stop(fade: 0)
            // 覆盖所有关闭路径（含 Esc）：恢复标签页的试听状态。
            onFinished()
        }
    }

    /// 4-7-8 呼吸节奏：吸气 4 秒（胀）→ 屏息 7 秒（停）→ 呼气 8 秒（缩），19 秒一个循环。
    private func breathPhase(at date: Date) -> (label: String, scale: Double) {
        let elapsed = max(0, date.timeIntervalSince(startedAt))
        let t = elapsed.truncatingRemainder(dividingBy: 19)
        if t < 4 {
            return ("吸气", 0.88 + 0.24 * Self.smooth(t / 4))
        }
        if t < 11 {
            return ("屏息", 1.12)
        }
        return ("呼气", 1.12 - 0.24 * Self.smooth((t - 11) / 8))
    }

    /// 近似的 easeInOut 曲线，让胀缩起止都柔和。
    private static func smooth(_ progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return p * p * (3 - 2 * p)
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let minutes = max(1, Int((Date.now.timeIntervalSince(startedAt) / 60).rounded()))
        NapEngine.shared.stop()
        store.finishNap(minutes: minutes)
        dismiss()
    }

    private static func clockString(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
