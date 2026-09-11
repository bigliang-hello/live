import SwiftUI

private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
private let paper = Color(red: 0.95, green: 0.97, blue: 0.95)

enum Page: String, CaseIterable {
    case today = "今日照顾", reminders = "提醒计划", guide = "健康指南", nap = "小憩"
    var icon: String {
        switch self { case .today: "sun.max"; case .reminders: "bell"; case .guide: "book.closed"; case .nap: "moon.zzz.fill" }
    }
    var caption: String {
        switch self {
        case .today: "把自己，放回日程里。"
        case .reminders: "找到适合自己的节奏。"
        case .guide: "给健康多一点了解。"
        case .nap: "给耳朵一处安静的地方。"
        }
    }
}
struct ContentView: View {
    @Bindable var store: WellnessStore
    @State private var page = Page.today
    @State private var showWorkPopover = false
    @State private var showCustomForm = false
    @State private var loginItem = LoginItem.shared
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(page.rawValue).font(.headline)
                    Spacer()
                    Text(Date.now.formatted(
                        .dateTime
                            .locale(Locale(identifier: "zh_CN"))
                            .month(.wide)
                            .day()
                            .weekday(.wide)
                    ))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }.padding(.horizontal, 36).padding(.vertical, 25)
                Divider().opacity(0.5)
                if page == .nap {
                    // 小憩页自带滚动区与固定在底部的播放条，不套外层 ScrollView。
                    NapTabView(store: store)
                        .id(page)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 26) {
                            switch page {
                            case .today: dashboard
                            case .reminders: reminderSettings
                            case .guide: GuideView()
                            default: EmptyView()
                            }
                        }.padding(36).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
                    }
                    .id(page)
                }
            }.background(paper)
        }.foregroundStyle(ink).tint(green).frame(minWidth: 900, minHeight: 680)
            .preferredColorScheme(.light)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 36) {
            HStack(spacing: 12) {
                Image(systemName: "leaf.fill").font(.title2).foregroundStyle(green)
                Text("活着").font(.system(size: 28, weight: .bold, design: .rounded)).tracking(3)
            }.padding(.top, 34).padding(.horizontal, 14)
            VStack(alignment: .leading, spacing: 8) {
                Text("自己的生活，值得惦记。").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.bottom, 15)
                ForEach(Page.allCases, id: \.self) { item in
                    Button { page = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.icon).frame(width: 20)
                            Text(item.rawValue)
                            Spacer()
                            if page == item { Circle().fill(green).frame(width: 5, height: 5) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SidebarTabStyle(selected: page == item))
                    .frame(maxWidth: .infinity)
                    .accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }
            Spacer()
            sidebarReminderControl
        }.padding(18).frame(width: 200).background(Color.white.opacity(0.8))
    }

    private var loginBinding: Binding<Bool> {
        Binding(
            get: { loginItem.enabled },
            set: { value in
                if !loginItem.setEnabled(value) {
                    store.notice = "设置开机自启动没有成功，可以到 系统设置 › 通用 › 登录项 里检查。"
                }
            }
        )
    }

    private var sidebarReminderControl: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: store.running ? "bell.and.waves.left.and.right.fill" : "bell.slash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(store.running ? green : ink.opacity(0.48))
                        .frame(width: 32, height: 32)
                        .background(store.running ? green.opacity(0.11) : Color.black.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.running ? "提醒运行中" : "提醒未开启")
                            .font(.system(size: 12, weight: .semibold))
                        Text(store.running ? "\(store.activeReminderCount) 项正在计时" : "需要时再打开")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    if store.running { store.stop() } else { Task { await store.schedule() } }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: store.running ? "pause.fill" : "play.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(store.running ? "暂停提醒" : "开启提醒")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Text(store.running ? "ON" : "OFF")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .opacity(0.65)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .contentShape(Rectangle())
                }
                .buttonStyle(SidebarReminderButtonStyle(running: store.running))
                .disabled(store.busy)
                .accessibilityLabel(store.running ? "暂停全部提醒" : "开启全部提醒")

                Divider().opacity(0.4)

                HStack(spacing: 8) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(loginItem.enabled ? green : .secondary)
                    Text("开机自启动")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("开机自启动", isOn: loginBinding)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(store.running ? green.opacity(0.18) : Color.black.opacity(0.055))
            }
            .shadow(color: .black.opacity(0.035), radius: 10, y: 4)

            Text("慢慢来，也很好")
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(.tertiary)
        }
    }
    @ViewBuilder private var dashboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("工作很重要，\n你也是。") .font(.system(size: 35, weight: .semibold, design: .rounded)).lineSpacing(5)
            Text("不用一下子改变生活。先从照顾此刻的自己开始。").foregroundStyle(.secondary).padding(.top, 5)
        }
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 15) {
                Text("TODAY · 今日的小小积累").font(.system(size: 10, weight: .semibold)).tracking(2)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(store.today.count)").font(.system(size: 60, weight: .light, design: .rounded)).contentTransition(.numericText())
                    Text("次照顾自己").font(.title3)
                }
                Text(dashboardCaption).font(.callout)
                Button { page = .reminders } label: { Label("安排我的提醒", systemImage: "arrow.right") }.buttonStyle(.plain).font(.callout.bold())
            }
            Spacer()
            VStack(spacing: 2) {
                PlantView(level: min(store.currentStreak, 6), todayCount: store.today.count).frame(width: 190, height: 185)
                Text(plantCaption)
                    .font(.system(size: 11))
                    .foregroundStyle(ink.opacity(0.55))
                    .frame(width: 190)
            }
        }.padding(28).background(Color(red: 0.85, green: 0.92, blue: 0.86), in: RoundedRectangle(cornerRadius: 22))
        HStack { Text("给身体一点回应").font(.title3.bold()); Spacer(); Text("按自己的节奏就好").font(.caption).foregroundStyle(.secondary) }
        HStack(alignment: .top, spacing: 14) {
            ForEach(store.reminders) { reminder in
                VStack(alignment: .leading, spacing: 13) {
                    Image(systemName: reminder.symbol).font(.system(size: 24)).foregroundStyle(reminder.id == "water" ? .blue : green).frame(height: 32)
                    Text(reminder.title).font(.headline)
                    Text(reminder.id == "water" ? "今日共摄入 \(store.formattedWaterTotal)" : "今日 \(store.count(reminder.id)) 次")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button {
                        withAnimation {
                            if reminder.id == "water" { store.showWaterReminder() }
                            else if reminder.id == "move" { store.showMovementReminder() }
                            else { store.check(reminder.id) }
                        }
                    } label: {
                        Label(
                            reminder.id == "water" ? "记录水量" : reminder.id == "move" ? "随机动作" : "记一次",
                            systemImage: reminder.id == "move" ? "figure.mind.and.body" : "plus"
                        )
                        .frame(maxWidth: .infinity)
                    }.buttonStyle(.bordered).controlSize(.large)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        ReviewCard(store: store)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "bell.badge").font(.callout)
            Text(store.notice).font(.callout).foregroundStyle(.secondary)
        }
        if !store.today.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text("今天的足迹").font(.headline)
                ForEach(store.today.reversed().prefix(6)) { record in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(green)
                        Text(recordTitle(record))
                        Spacer()
                        Text(record.date, style: .time).foregroundStyle(.secondary)
                        Button("撤销") { store.undo(record.id) }.buttonStyle(.borderless)
                    }.font(.callout)
                }
            }.padding(22).background(.white, in: RoundedRectangle(cornerRadius: 18))
        }
    }
    private var dashboardCaption: String {
        if store.currentStreak >= 2 {
            return "连续照顾自己第 \(store.currentStreak) 天，本周 \(store.weekCareDays)/7 天。"
        }
        if store.weekCareDays >= 1 {
            return "本周已照顾自己 \(store.weekCareDays) 天，每一次都算数。"
        }
        return "今天的第一份照顾，就从现在开始。"
    }

    /// 植物旁的小提示：让人知道它跟着连续天数长大。
    private var plantCaption: String {
        if store.currentStreak == 0 {
            return "今天照顾自己一次，它就会发芽"
        }
        if store.currentStreak >= 6 {
            return "已连续照顾 \(store.currentStreak) 天，它开出了花"
        }
        return "已连续照顾 \(store.currentStreak) 天，它在慢慢长大"
    }

    @ViewBuilder private var reminderSettings: some View {
        Text(page.caption).font(.system(size: 30, weight: .semibold, design: .rounded))
        Text("修改间隔或开关会立即生效，只重启这一项；其他提醒的倒计时不受影响。").foregroundStyle(.secondary)
        workHoursCard
        ForEach($store.reminders) { $reminder in
            HStack(spacing: 20) {
                Image(systemName: reminder.symbol).font(.title).frame(width: 44).foregroundStyle(green)
                VStack(alignment: .leading, spacing: 8) { Text(reminder.title).font(.headline); Text(reminder.subtitle).font(.callout).foregroundStyle(.secondary) }
                Spacer()
                if reminder.id == "move", store.moveWaitingForUser {
                    Text("你不在电脑前，计时已暂停")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 72, alignment: .trailing)
                        .padding(.trailing, 8)
                } else if reminder.enabled, let fire = store.nextFireDates[reminder.id] {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("下次提醒").font(.system(size: 10)).tracking(1).foregroundStyle(.secondary)
                        Text(fire, style: .timer)
                            .font(.system(size: 17, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(green)
                            .contentTransition(.numericText())
                    }
                    .frame(minWidth: 72, alignment: .trailing)
                    .padding(.trailing, 8)
                    .help("距离下一次\(reminder.title)提醒")
                }
                GentleLadderPicker(minutes: $reminder.minutes, options: Reminder.intervalLadder)
                Toggle("启用", isOn: $reminder.enabled).labelsHidden().toggleStyle(.switch).accessibilityLabel("启用\(reminder.title)")
            }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 18))
        }
        customReminderCard
        if !store.rhythmSuggestions.isEmpty {
            rhythmCard
        }
        HStack {
            Button(store.running ? "全部重新计时" : "开启提醒") { Task { await store.schedule() } }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.busy)
            if store.running { Button("暂停全部") { store.stop() }.controlSize(.large) }
        }
        Text(store.notice).font(.callout).foregroundStyle(.secondary)
        Text("关闭主窗口不会暂停提醒。提醒会按间隔重复；完全退出“活着”后计时停止，重新打开会按开关状态自动继续。开启工作时段后只在时段内提醒；离开电脑超过 3 分钟时，「起来走走」会暂停等你回来。")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// 单行卡片：状态随时显示，具体时段设置收进气泡，避免展开后占太多屏。
    private var workHoursCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock.badge.checkmark")
                .font(.title3)
                .foregroundStyle(green)
                .frame(width: 40, height: 40)
                .background(Color(red: 0.85, green: 0.92, blue: 0.86), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                Text("工作时段感知").font(.headline)
                Text(store.workHoursStatus).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.workHoursEnabled {
                Button {
                    showWorkPopover = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(green)
                        .frame(width: 32, height: 32)
                        .background(green.opacity(0.08), in: Circle())
                        .overlay {
                            Circle().stroke(showWorkPopover ? green.opacity(0.5) : green.opacity(0.16))
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showWorkPopover, arrowEdge: .bottom) {
                    workHoursPopover
                }
                .accessibilityLabel("设置工作时段")
            }
            Toggle("只在工作时段提醒", isOn: $store.workHoursEnabled)
                .accessibilityLabel("只在工作时段提醒")
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var workHoursPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("工作时段").font(.headline)
            HStack(spacing: 20) {
                GentleTimePicker(label: "开始", minutes: $store.workStartMinutes)
                GentleTimePicker(label: "结束", minutes: $store.workEndMinutes)
            }
            Divider().opacity(0.5)
            HStack(spacing: 20) {
                Toggle("午休静默", isOn: $store.lunchEnabled)
                Toggle("周末不提醒", isOn: $store.weekendSilenced)
            }
            if store.lunchEnabled {
                HStack(spacing: 20) {
                    GentleTimePicker(label: "从", minutes: $store.lunchStartMinutes)
                    GentleTimePicker(label: "到", minutes: $store.lunchEndMinutes)
                }
            }
            Text("时段外的提醒会顺延到下一个工作窗口的开始，不会丢；跨天时第二天的计时从开始时间重新算满一个间隔。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 348)
        .animation(.easeOut(duration: 0.2), value: store.lunchEnabled)
    }

    // MARK: - 自定义提醒

    private var customReminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("自定义提醒").font(.headline)
                    Text("每天、每周几、每月几号或只提醒一次;到点以居中弹窗出现。").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showCustomForm = true
                } label: {
                    Label("添加提醒", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if store.customReminders.isEmpty {
                Text("还没有自定义提醒。适合放吃药、周会、下班拉伸这类固定安排。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            ForEach($store.customReminders) { $reminder in
                customReminderRow($reminder)
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .sheet(isPresented: $showCustomForm) {
            CustomReminderForm(store: store)
        }
    }

    private func customReminderRow(_ reminder: Binding<CustomReminder>) -> some View {
        HStack(spacing: 16) {
            Image(systemName: customSymbol(reminder.wrappedValue.repeatMode))
                .font(.title3)
                .foregroundStyle(green)
                .frame(width: 40, height: 40)
                .background(Color(red: 0.85, green: 0.92, blue: 0.86), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 6) {
                Text(reminder.wrappedValue.name).font(.headline)
                Text(customSubtitle(reminder.wrappedValue)).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if reminder.wrappedValue.enabled, let fire = store.customNextFireDates[reminder.wrappedValue.id] {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("下次提醒").font(.system(size: 10)).tracking(1).foregroundStyle(.secondary)
                    Text(fire, style: .timer)
                        .font(.system(size: 17, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(green)
                        .contentTransition(.numericText())
                }
                .frame(minWidth: 72, alignment: .trailing)
                .padding(.trailing, 8)
                .help("距离下一次「\(reminder.wrappedValue.name)」提醒")
            }
            Toggle("启用", isOn: reminder.enabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityLabel("启用\(reminder.wrappedValue.name)")
            Button {
                store.removeCustomReminder(reminder.wrappedValue.id)
            } label: {
                Image(systemName: "trash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("删除\(reminder.wrappedValue.name)")
        }
        .padding(16)
        .background(Color(red: 0.97, green: 0.98, blue: 0.97), in: RoundedRectangle(cornerRadius: 14))
    }

    /// 行内副标题:每天 09:00 / 每周三、周五 18:30 / 每月1日、15日 09:00 / 9月15日 10:00(已过期)。
    private func customSubtitle(_ reminder: CustomReminder) -> String {
        let time = String(format: "%02d:%02d", reminder.minuteOfDay / 60, reminder.minuteOfDay % 60)
        switch reminder.repeatMode {
        case .once:
            guard let fire = reminder.fireDate else { return "未设置时间" }
            let text = fire.formatted(
                .dateTime.locale(Locale(identifier: "zh_CN")).month().day().hour().minute()
            )
            return fire > .now ? text : "\(text) · 已过期"
        case .daily:
            return "每天 \(time)"
        case .weekly:
            let names = ["日", "一", "二", "三", "四", "五", "六"]
            let days = reminder.weekdays.sorted().map { names[$0 - 1] }.joined(separator: "、")
            return "每周\(days) \(time)"
        case .monthly:
            let days = reminder.monthDays.sorted().map { "\($0)日" }.joined(separator: "、")
            return "每月\(days) \(time)"
        }
    }

    private func customSymbol(_ mode: RepeatMode) -> String {
        switch mode {
        case .daily: "clock.arrow.circlepath"
        case .weekly: "calendar"
        case .monthly: "calendar.circle"
        case .once: "calendar.badge.clock"
        }
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("节奏小建议", systemImage: "waveform.path.ecg")
                .font(.headline)
            ForEach(store.rhythmSuggestions) { suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Text("今天你把「\(suggestion.reminder.title)」推迟了 \(store.snoozeCount(suggestion.reminder.id)) 次，要不要放宽到 \(suggestion.minutes) 分钟？")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("放宽到 \(suggestion.minutes) 分钟") {
                        store.applyRhythmSuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Text("只是建议，不会悄悄改你的设置。")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }


    private func recordTitle(_ record: CheckIn) -> String {
        switch record.kind {
        case "rest":
            return "白噪音小憩 · \(record.amount ?? 0) 分钟"
        default:
            let title = store.title(forKind: record.kind)
            guard record.kind == "water", let amount = record.amount else { return title }
            return "\(title) · \(amount) ml"
        }
    }
}

private struct SidebarTabStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                selected
                    ? green.opacity(0.11)
                    : configuration.isPressed ? green.opacity(0.06) : .clear,
                in: RoundedRectangle(cornerRadius: 12)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SidebarReminderButtonStyle: ButtonStyle {
    let running: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(running ? green : .white)
            .background(
                running
                    ? green.opacity(configuration.isPressed ? 0.16 : 0.085)
                    : green.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay {
                if running {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(green.opacity(0.16))
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PlantView: View {
    /// 连续照顾天数对应的成长阶段，0–6。
    let level: Int
    let todayCount: Int

    private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
    private let deepGreen = Color(red: 0.36, green: 0.58, blue: 0.40)

    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.32)).frame(width: 170)
            plant
            pot
        }
        .accessibilityLabel(accessibilityText)
    }

    private var stemTop: CGFloat {
        148 - (18 + CGFloat(level) * 18)
    }

    @ViewBuilder private var plant: some View {
        if level == 0 {
            // 刚破土的小芽
            Circle().fill(green).frame(width: 9, height: 9).position(x: 97, y: 143)
            Ellipse().fill(green).frame(width: 17, height: 8).rotationEffect(.degrees(-32)).position(x: 90, y: 137)
        } else {
            Path { path in
                path.move(to: CGPoint(x: 97, y: 148))
                path.addQuadCurve(to: CGPoint(x: 94, y: stemTop), control: CGPoint(x: 102, y: (148 + stemTop) / 2))
            }
            .stroke(green, style: StrokeStyle(lineWidth: 4, lineCap: .round))

            ForEach(0..<min(level, 5), id: \.self) { index in
                let leafCount = min(level, 5)
                let ratio = Double(index + 1) / Double(leafCount + 1)
                let y = 148 - ratio * (148 - stemTop - 10)
                let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
                let size: CGFloat = 36 + CGFloat(index % 3) * 7
                Ellipse()
                    .fill(index.isMultiple(of: 2) ? green : deepGreen)
                    .frame(width: size, height: size / 2.2)
                    .rotationEffect(.degrees(Double(side) * (28 + CGFloat(index) * 4)))
                    .position(x: 97 + side * (size / 2.4 + 3), y: y)
            }

            if level >= 6 {
                Circle().fill(green.opacity(0.2)).frame(width: 26).position(x: 94, y: stemTop - 2)
                Circle().fill(green).frame(width: 11).position(x: 94, y: stemTop - 2)
            }
        }
        if todayCount > 0, level > 0 {
            // 今天长出的新叶
            Ellipse()
                .fill(green.opacity(0.85))
                .frame(width: 30, height: 14)
                .rotationEffect(.degrees(-18))
                .position(x: 116, y: stemTop + 14)
        }
    }

    private var pot: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(red: 0.72, green: 0.79, blue: 0.67))
                .frame(width: 55, height: 39)
                .position(x: 97, y: 157)
            Ellipse()
                .fill(Color(red: 0.55, green: 0.47, blue: 0.38).opacity(0.55))
                .frame(width: 47, height: 10)
                .position(x: 97, y: 140)
        }
    }

    private var accessibilityText: String {
        if level == 0 {
            return todayCount > 0 ? "今天已有照顾，小植物即将发芽" : "等待第一份照顾的小种子"
        }
        var text = "被连续照顾 \(level) 天、越长越大的小植物"
        if todayCount > 0 { text += "，今天又长出了新叶" }
        return text
    }
}
