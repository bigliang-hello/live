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
        NapSound(id: "bright-rain", name: "敞亮雨", category: "雨声", symbol: "sun.rain.fill"),
        // 自然
        NapSound(id: "waves", name: "海浪", category: "自然", symbol: "water.waves"),
        NapSound(id: "river", name: "河流", category: "自然", symbol: "water.waves.and.arrow.down"),
        NapSound(id: "waterfall", name: "瀑布", category: "自然", symbol: "drop.triangle.fill"),
        NapSound(id: "field", name: "田野", category: "自然", symbol: "sun.horizon.fill"),
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
        NapSound(id: "frog", name: "青蛙", category: "动物", symbol: "leaf.circle.fill"),
        NapSound(id: "dog-barking", name: "狗叫", category: "动物", symbol: "dog.fill"),
        NapSound(id: "whale", name: "鲸鸣", category: "动物", symbol: "fish.fill"),
        // 器物
        NapSound(id: "typewriter", name: "打字机", category: "器物", symbol: "keyboard"),
        NapSound(id: "keyboard", name: "键盘", category: "器物", symbol: "command.square.fill"),
        NapSound(id: "wind-chimes", name: "风铃", category: "器物", symbol: "music.note"),
        NapSound(id: "singing-bowl", name: "颂钵", category: "器物", symbol: "moon.dust.fill"),
        NapSound(id: "fan", name: "风扇", category: "器物", symbol: "fanblades.fill"),
        NapSound(id: "brown-noise", name: "布朗噪声", category: "器物", symbol: "waveform")
    ]

    static let categories: [String] = ["雨声", "自然", "动物", "器物"]

    static let fallback = catalog[0]
}

/// 混音里的一路声音：声音本身 + 它在组合里的音量（0–1）。
struct NapChannel: Identifiable, Equatable {
    let sound: NapSound
    var volume: Double
    var id: String { sound.id }
}

/// 一次小憩的计划：哪几路声音（音量已含总音量）、多长时间。
struct NapPlan: Identifiable {
    let channels: [NapChannel]
    let minutes: Int
    var id: String { channels.map(\.id).sorted().joined(separator: "+") + ":\(minutes)" }
}

/// 混音组合在偏好里的存档形式（NapSound 不落盘，按 id 回查目录）。
private struct StoredChannel: Codable {
    let id: String
    let volume: Double
}

/// 白噪音混音引擎：选中的每种声音各一个循环播放器，
/// 可单独调音量、单独停，整体支持暂停/恢复和淡出。
final class NapEngine {
    static let shared = NapEngine()

    private var players: [String: AVAudioPlayer] = [:]
    private var fadeTimers: [String: Timer] = [:]

    /// 是否有任意一路正在出声（暂停中算没在放）。
    var isPlaying: Bool { players.values.contains { $0.isPlaying } }

    private func url(for sound: NapSound) -> URL? {
        Bundle.main.url(forResource: sound.id, withExtension: "m4a")
            ?? Bundle.main.url(forResource: sound.id, withExtension: "m4a", subdirectory: "NapSounds")
    }

    /// 加入一路（已在放的就只更新音量），并立即播放。
    func start(sound: NapSound, volume: Double) {
        fadeTimers[sound.id]?.invalidate()
        fadeTimers[sound.id] = nil
        guard let url = url(for: sound) else { return }
        let player: AVAudioPlayer
        if let existing = players[sound.id] {
            player = existing
        } else if let created = try? AVAudioPlayer(contentsOf: url) {
            player = created
            player.numberOfLoops = -1
            player.prepareToPlay()
            players[sound.id] = player
        } else {
            return
        }
        player.volume = Float(volume)
        player.play()
    }

    /// 调某一路的音量，播放中即时生效。
    func setVolume(_ id: String, _ value: Double) {
        players[id]?.volume = Float(value)
    }

    /// 停掉某一路，带淡出；再 start 同一声音会从头循环。
    func stopChannel(_ id: String, fade seconds: Double = 0.8) {
        fadeTimers[id]?.invalidate()
        guard let player = players[id] else { return }
        guard seconds > 0 else {
            player.stop()
            players[id] = nil
            return
        }
        var remaining = max(1, Int(seconds / 0.06))
        fadeTimers[id] = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] timer in
            remaining -= 1
            player.volume = max(0, player.volume * 0.8)
            if remaining <= 0 {
                timer.invalidate()
                player.stop()
                self?.players[id] = nil
                self?.fadeTimers[id] = nil
            }
        }
    }

    func pause() {
        players.values.forEach { $0.pause() }
    }

    func resume() {
        players.values.forEach { $0.play() }
    }

    func stopAll(fade seconds: Double = 1.2) {
        for id in Array(players.keys) {
            stopChannel(id, fade: seconds)
        }
    }
}

/// 「小憩」标签页：28 种白噪音任意多选叠加，选几种就是几种的混音，
/// 试听满意就带着这个组合小睡一会儿。
struct NapTabView: View {
    @Bindable var store: WellnessStore
    @State private var mix = NapTabView.storedMix()
    /// 总播放/暂停；各路是否在混音里由 mix 决定，这里只管整体。
    @State private var previewing = false
    /// 总音量：与每路自己的音量相乘生效，沿用旧的 nap.volume 键。
    @State private var master = UserDefaults.standard.object(forKey: "nap.volume") as? Double ?? 0.6
    @State private var minutes = NapTabView.storedMinutes()
    @State private var napPlan: NapPlan?

    /// 上次的组合会记住：下次打开还是熟悉的声音、音量和时长。
    private static func storedMix() -> [NapChannel] {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "nap.mix"),
           let entries = try? JSONDecoder().decode([StoredChannel].self, from: data),
           !entries.isEmpty {
            let channels = entries.compactMap { entry in
                NapSound.catalog.first { $0.id == entry.id }
                    .map { NapChannel(sound: $0, volume: entry.volume) }
            }
            if !channels.isEmpty { return channels }
        }
        // 旧版本只存过单个声音：迁移成一路，音量交给总音量。
        if let id = defaults.string(forKey: "nap.sound"),
           let sound = NapSound.catalog.first(where: { $0.id == id }) {
            return [NapChannel(sound: sound, volume: 1)]
        }
        return []
    }

    private static func saveMix(_ mix: [NapChannel]) {
        let entries = mix.map { StoredChannel(id: $0.sound.id, volume: $0.volume) }
        UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: "nap.mix")
    }

    private static func storedMinutes() -> Int {
        let value = UserDefaults.standard.integer(forKey: "nap.minutes")
        return [3, 5, 10, 15, 30].contains(value) ? value : 5
    }

    private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
    private let green = Color(red: 0.18, green: 0.43, blue: 0.35)

    /// 某一路的实际音量 = 自己的音量 × 总音量。
    private func effectiveVolume(_ channel: NapChannel) -> Double {
        channel.volume * master
    }

    var body: some View {
        VStack(spacing: 0) {
            // 声音网格在滚动区里；混音台固定在页面底部，不用滚到底才能开始小憩。
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
            NapEngine.shared.stopAll(fade: 0)
        }
        .onChange(of: mix) { _, new in
            Self.saveMix(new)
        }
        .onChange(of: master) { _, new in
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
                Text("点几种声音叠在一起，配一个只属于你的角落。声音来自开源项目 XMSLEEP（Unlicense 公有领域）。")
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

    /// 点一张卡片 = 把这路声音加入/移出混音；加入时立刻出声试听。
    private func toggle(_ sound: NapSound) {
        if let index = mix.firstIndex(where: { $0.sound == sound }) {
            mix.remove(at: index)
            NapEngine.shared.stopChannel(sound.id)
            if mix.isEmpty { previewing = false }
        } else {
            mix.append(NapChannel(sound: sound, volume: 1))
            previewing = true
            // 整个组合一起启动:恢复出来的旧选中(或暂停中的各路)从来没播过,
            // 只放新点的一路会出现「显示混音、实际只有一路出声」。对已在播的
            // 播放器重复 play() 没有副作用,不会从头来。
            for channel in mix {
                NapEngine.shared.start(sound: channel.sound, volume: effectiveVolume(channel))
            }
        }
    }

    private func soundCard(_ sound: NapSound) -> some View {
        let isSelected = mix.contains { $0.sound == sound }
        return Button {
            toggle(sound)
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
        .animation(.easeOut(duration: 0.18), value: isSelected)
        .accessibilityLabel("\(sound.category)，\(sound.name)\(isSelected ? "，已在组合里" : "")\(previewing && isSelected ? "，正在播放" : "")")
    }

    // MARK: - 底部混音台

    private var playerBar: some View {
        HStack(spacing: 14) {
            masterButton

            if mix.isEmpty {
                Text("在上方点选几种声音，叠出你的专属组合")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // 选一种显示它的名字，选多种合起来就叫「混音」，底部不堆声道条。
                VStack(alignment: .leading, spacing: 4) {
                    Text(mix.count > 1 ? "混音" : mix[0].sound.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(mix.count > 1 ? "\(mix.count) 种声音" : mix[0].sound.category)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        if previewing {
                            PlayingBarsMark(color: green)
                                .frame(width: 14)
                        }
                    }
                }
                .frame(width: 82, alignment: .leading)
                Spacer(minLength: 0)
            }

            masterVolume

            HStack(spacing: 8) {
                Text("小憩时长")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                GentleOptionPicker(options: [3, 5, 10, 15, 30], selection: $minutes)
            }
            .frame(height: 44)

            Button {
                guard !mix.isEmpty else { return }
                previewing = false
                napPlan = NapPlan(
                    channels: mix.map { NapChannel(sound: $0.sound, volume: effectiveVolume($0)) },
                    minutes: minutes
                )
            } label: {
                Label("开始小憩", systemImage: "moon.zzz.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 14)
                    .frame(height: 42)
            }
            .buttonStyle(NapStartButtonStyle(color: green))
            .disabled(mix.isEmpty)
            .opacity(mix.isEmpty ? 0.55 : 1)
        }
    }

    /// 整体的播放/暂停：暂停保留各路，恢复继续放。
    private var masterButton: some View {
        Button {
            guard !mix.isEmpty else { return }
            previewing.toggle()
            if previewing {
                for channel in mix {
                    NapEngine.shared.start(sound: channel.sound, volume: effectiveVolume(channel))
                }
            } else {
                NapEngine.shared.pause()
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 13)
                    .fill(green.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: mix.count > 1 ? "waveform" : mix.first?.sound.symbol ?? "waveform")
                    .font(.system(size: 17, weight: .medium))
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
        .disabled(mix.isEmpty)
        .opacity(mix.isEmpty ? 0.5 : 1)
        .accessibilityLabel(previewing ? "暂停播放" : "播放当前组合")
    }

    private var masterVolume: some View {
        HStack(spacing: 8) {
            Image(systemName: master < 0.05 ? "speaker.slash.fill" : "speaker.wave.1.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Slider(value: $master, in: 0...1) { _ in
                for channel in mix {
                    NapEngine.shared.setVolume(channel.sound.id, effectiveVolume(channel))
                }
            }
            .frame(width: 80)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(Color.black.opacity(0.035), in: Capsule())
        .accessibilityLabel("音量")
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
                HStack(spacing: 6) {
                    ForEach(plan.channels.prefix(3)) { channel in
                        Image(systemName: channel.sound.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 26, height: 26)
                            .background(accent.opacity(0.10), in: Circle())
                    }
                    if plan.channels.count > 3 {
                        Text("+\(plan.channels.count - 3)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(plan.channels.map(\.sound.name).joined(separator: " + "))
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
            for channel in plan.channels {
                NapEngine.shared.start(sound: channel.sound, volume: channel.volume)
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(Double(plan.minutes * 60)))
            finish()
        }
        .onDisappear {
            NapEngine.shared.stopAll(fade: 0)
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
        NapEngine.shared.stopAll()
        store.finishNap(minutes: minutes)
        dismiss()
    }

    private static func clockString(_ interval: TimeInterval) -> String {
        let seconds = Int(interval.rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
