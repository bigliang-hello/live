import SwiftUI
import LunarSwift

private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
private let paper = Color(red: 0.95, green: 0.97, blue: 0.95)

enum Page: String, CaseIterable {
    case today = "今日照顾", reminders = "提醒计划", guide = "健康指南", nap = "小憩", almanac = "今日黄历", decompress = "解压"
    var icon: String {
        switch self { case .today: "sun.max"; case .reminders: "bell"; case .guide: "book.closed"; case .nap: "moon.zzz.fill"; case .almanac: "calendar"; case .decompress: "party.popper.fill" }
    }
    var caption: String {
        switch self {
        case .today: "把自己，放回日程里。"
        case .reminders: "找到适合自己的节奏。"
        case .guide: "给健康多一点了解。"
        case .nap: "给耳朵一处安静的地方。"
        case .almanac: "顺着天时过日子。"
        case .decompress: "爽完再开工。"
        }
    }
}
struct ContentView: View {
    @Bindable var store: WellnessStore
    @State private var page = Page.today
    @State private var showWorkPopover = false
    @State private var showCustomForm = false
    @State private var pendingDelete: CustomReminder?
    @State private var loginItem = LoginItem.shared
    @State private var updater = UpdateChecker.shared
    @State private var showQuoteSplash = false
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    Text(page.rawValue).font(.headline)
                    Spacer()
                    if page == .today {
                        Button { page = .almanac } label: {
                            SolarTermBadge(date: .now)
                        }
                        .buttonStyle(.plain)
                        .help("查看今日黄历")
                    }
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
                            case .almanac: AlmanacTabView()
                            case .decompress: DecompressView()
                            default: EmptyView()
                            }
                        }.padding(36).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
                    }
                    .id(page)
                }
            }.background(paper)
                // 操作反馈统一走右上角吐司:飘几秒自动消失,点一下提前收起。
                .overlay(alignment: .topTrailing) {
                    if let toast = store.toast {
                        ToastCard(text: toast)
                            .padding(.top, 82)
                            .padding(.trailing, 34)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .onTapGesture { store.dismissToast() }
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.85), value: store.toast)
        }.foregroundStyle(ink).tint(green).frame(minWidth: 900, minHeight: 680)
            .preferredColorScheme(.light)

            // 每日一句开屏:盖在整窗最上层,点「收下」或 9 秒后自动收场。
            if showQuoteSplash {
                QuoteSplash(text: DailyQuotes.today()) {
                    withAnimation(.easeIn(duration: 0.28)) { showQuoteSplash = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
                .zIndex(10)
            }
        }
        .onAppear(perform: checkDailyQuoteSplash)
        // 常驻场景:窗口整夜开着不会重建视图,onAppear 不再触发;
        // 每次切回前台补查一次,保证「每天第一次看到主页」都能播。
        // macOS 上 scenePhase 不随前后台变化,要听系统的激活通知。
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkDailyQuoteSplash()
        }
    }

    /// 每天第一次展示主窗口时,放一次每日一句的全屏动画;当天内重开不再放。
    private func checkDailyQuoteSplash() {
        let day = Calendar.current.startOfDay(for: .now).timeIntervalSince1970 / 86_400
        guard UserDefaults.standard.double(forKey: "quote.splashDay") != day else { return }
        UserDefaults.standard.set(day, forKey: "quote.splashDay")
        showQuoteSplash = true
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
                    store.showToast("设置开机自启动没有成功，可以到 系统设置 › 通用 › 登录项 里检查。")
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

                if updater.shouldShowBanner {
                    Divider().opacity(0.4)
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(green)
                        Text("新版本 \(updater.latest?.tag ?? "") 可用")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("下载") { updater.openDownload() }
                            .buttonStyle(.link)
                            .font(.system(size: 11, weight: .semibold))
                        Button {
                            updater.skipCurrent()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("忽略此版本")
                    }
                    .transition(.opacity)
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
        dashboardHeader
        careSummaryCard
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

    private var dashboardHeader: some View {
        HStack(alignment: .bottom, spacing: 42) {
            VStack(alignment: .leading, spacing: 8) {
                Label("先把自己放回今天", systemImage: "leaf.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(green)

                VStack(alignment: .leading, spacing: 0) {
                    Text("工作很重要，")
                        .foregroundStyle(ink)
                    Text("你也是。")
                        .foregroundStyle(green)
                        .background(alignment: .bottomLeading) {
                            Capsule()
                                .fill(green.opacity(0.11))
                                .frame(width: 142, height: 11)
                                .offset(y: 1)
                        }
                }
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .lineSpacing(3)
            }

            Spacer(minLength: 18)

            VStack(alignment: .leading, spacing: 8) {
                Text("今日一句")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(green.opacity(0.8))
                Text(DailyQuotes.today())
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(ink.opacity(0.62))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 310, alignment: .leading)
            .padding(.leading, 18)
            .padding(.vertical, 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(green.opacity(0.22))
                    .frame(width: 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private var careSummaryCard: some View {
        HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("今日照顾")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.4)
                    Text(store.today.isEmpty ? "等待第一次回应" : "正在积累")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.58), in: Capsule())
                }

                HStack(alignment: .lastTextBaseline, spacing: 9) {
                    Text("\(store.today.count)")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .contentTransition(.numericText())
                    Text("次")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.72))
                }

                Text(dashboardCaption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ink.opacity(0.72))

                growthProgress

                Button { page = .reminders } label: {
                    HStack(spacing: 8) {
                        Text("安排我的提醒")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 15)
                    .frame(height: 36)
                    .background(green, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("前往提醒计划")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(green.opacity(0.11))
                .frame(width: 1, height: 190)

            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10))
                    Text("本周植物")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("\(min(store.weekCareDays, 5))/5")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.58), in: Capsule())
                }
                .foregroundStyle(green)
                .frame(width: 190)

                PlantGrowthView(caredDays: store.weekCareDays)
                    .frame(width: 190, height: 158)

                Text(plantCaption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink.opacity(0.52))
                    .frame(width: 190)
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 24)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.82, green: 0.91, blue: 0.84),
                            Color(red: 0.89, green: 0.95, blue: 0.90)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: green.opacity(0.07), radius: 18, y: 8)
    }

    private var growthProgress: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("本周成长")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.54))
                Spacer()
                Text("第 \(min(store.weekCareDays, 5)) 阶段")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(green)
            }

            HStack(spacing: 7) {
                ForEach(1...5, id: \.self) { stage in
                    Capsule()
                        .fill(stage <= store.weekCareDays ? green : .white.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .frame(height: 7)
                }
            }
        }
        .frame(maxWidth: 300)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本周植物成长第 \(min(store.weekCareDays, 5)) 阶段，共五个阶段")
    }
    private var dashboardCaption: String {
        if store.currentStreak >= 2 {
            return "连续照顾自己第 \(store.currentStreak) 天，植物成长 \(min(store.weekCareDays, 5))/5。"
        }
        if store.weekCareDays >= 1 {
            return "本周已照顾自己 \(store.weekCareDays) 天，植物成长 \(min(store.weekCareDays, 5))/5。"
        }
        return "今天的第一份照顾，就从现在开始。"
    }

    /// 植物按本周有照顾记录的天数成长，五天达到最大形态。
    private var plantCaption: String {
        let caredDays = min(store.weekCareDays, 5)
        if caredDays == 0 {
            return "本周照顾自己一次，它就会发芽"
        }
        if caredDays == 5 {
            return "本周照顾满 5 天，它长到最好了"
        }
        return "本周照顾 \(caredDays) 天 · 成长 \(caredDays)/5"
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
                    Text("每天、每周几、每月几号、每隔多久,或只提醒一次;到点以居中弹窗出现。").font(.caption).foregroundStyle(.secondary)
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
        // 删除自定义提醒前先确认,避免误触垃圾桶图标直接删掉。
        .alert(
            "删除「\(pendingDelete?.name ?? "")」？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            )
        ) {
            Button("删除", role: .destructive) {
                if let target = pendingDelete { store.removeCustomReminder(target.id) }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("删除后这条提醒不再计时。")
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
                pendingDelete = reminder.wrappedValue
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

    /// 行内副标题:每天 09:00 / 每周三、周五 18:30 / 每月1日、15日 09:00 /
    /// 每隔 45 分钟 / 9月15日 10:00(已过期)。
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
        case .interval:
            let minutes = reminder.intervalMinutes
            if minutes >= 60, minutes % 60 == 0 { return "每隔 \(minutes / 60) 小时" }
            return "每隔 \(minutes) 分钟"
        }
    }

    private func customSymbol(_ mode: RepeatMode) -> String {
        switch mode {
        case .daily: "clock.arrow.circlepath"
        case .weekly: "calendar"
        case .monthly: "calendar.circle"
        case .interval: "timer"
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

/// 首页顶栏的节气速览。节气当天突出“今日交节”，平日显示下一节气倒计时。
private struct SolarTermBadge: View {
    let date: Date

    private var status: (current: String, detail: String) {
        let solar = Solar.fromDate(date: date)
        let lunar = solar.lunar
        if !lunar.jieQi.isEmpty {
            return (lunar.jieQi, "今日交节")
        }

        let current = lunar.prevJieQi
        let next = lunar.nextJieQi
        let days = max(0, next.solar.subtract(solar: solar))
        let detail = days == 0 ? "今日 · \(next.name)" : "\(days)天后 · \(next.name)"
        return (current.name, detail)
    }

    var body: some View {
        let status = status
        HStack(spacing: 9) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(green)
                .frame(width: 28, height: 28)
                .background(green.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(status.current)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                Text(status.detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(ink.opacity(0.48))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(green.opacity(0.45))
        }
        .padding(.leading, 7)
        .padding(.trailing, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.72), in: Capsule())
        .overlay {
            Capsule().stroke(green.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("当前节气 \(status.current)，\(status.detail)，查看今日黄历")
    }
}

/// 右上角的短暂反馈卡片:操作结果在这里飘几秒,点一下提前收起。
private struct ToastCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(green)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 2)
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .padding(4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: 340, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.06))
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
        .contentShape(Rectangle())
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

private struct PlantGrowthView: View {
    let caredDays: Int

    private var stage: Int {
        min(max(caredDays, 1), 5)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 160, height: 160)

            Image("PlantGrowth\(stage)")
                .resizable()
                .scaledToFit()
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
        }
        .frame(width: 190, height: 175)
        .saturation(caredDays == 0 ? 0.72 : 1)
        .opacity(caredDays == 0 ? 0.82 : 1)
        .id(stage)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .animation(.easeInOut(duration: 0.35), value: stage)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard caredDays > 0 else {
            return "等待本周第一次照顾的植物幼芽"
        }
        return "本周已照顾 \(min(caredDays, 5)) 天，植物处于第 \(stage) 个成长阶段"
    }
}
