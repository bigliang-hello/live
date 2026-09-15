import SwiftUI

/// 添加自定义提醒的表单:名称 + 重复方式(每天/每周几/每月几号/每隔多久/单次)+ 时刻或间隔。
/// 单次的日期用自绘迷你月历挑选,不用系统图形化日期控件。
struct CustomReminderForm: View {
    @Bindable var store: WellnessStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var mode = RepeatMode.daily
    @State private var weekdays: Set<Int> = []
    @State private var monthDays: Set<Int> = []
    @State private var minuteOfDay = 9 * 60
    @State private var intervalMinutes = 30
    @State private var oneTimeDay = CustomReminderForm.defaultOnceDay(9 * 60)
    @State private var showCalendar = false

    /// 间隔提醒的档位:10 分钟到 4 小时。
    private static let intervalOptions = [10, 15, 20, 30, 45, 60, 90, 120, 180, 240]

    private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
    private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
    private let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    /// 单次默认日期:今天 09:00 还没过就选今天,否则选明天。
    private static func defaultOnceDay(_ minuteOfDay: Int) -> Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: .now)
        comps.hour = minuteOfDay / 60
        comps.minute = minuteOfDay % 60
        if (calendar.date(from: comps) ?? .now) > .now {
            return calendar.startOfDay(for: .now)
        }
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    /// 单次提醒的触发时刻:所选日期 + 所选时刻。
    private var onceFireDate: Date {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: oneTimeDay)
        comps.hour = minuteOfDay / 60
        comps.minute = minuteOfDay % 60
        return calendar.date(from: comps) ?? oneTimeDay
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch mode {
        case .daily: return true
        case .weekly: return !weekdays.isEmpty
        case .monthly: return !monthDays.isEmpty
        case .interval: return intervalMinutes > 0
        case .once: return onceFireDate > .now
        }
    }

    private var disableReason: String? {
        if trimmedName.isEmpty { return "先起个名字" }
        switch mode {
        case .daily: return nil
        case .weekly: return weekdays.isEmpty ? "至少选一个星期" : nil
        case .monthly: return monthDays.isEmpty ? "至少选一个日子" : nil
        case .interval: return nil
        case .once: return onceFireDate <= .now ? "选的时刻已过去" : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("添加自定义提醒")
                .font(.title3.bold())

            HStack(spacing: 12) {
                Text("名称")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .leading)
                TextField("比如:吃药、周会、下班拉伸", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Text("重复")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .leading)
                modePicker
                Spacer()
                Text(modeCaption)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            switch mode {
            case .daily:
                timeRow
            case .weekly:
                HStack(spacing: 12) {
                    Text("星期")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)
                    weekdayPicker
                }
                timeRow
            case .monthly:
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("几号")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)
                        Text("可多选;当月没有的日子(如 31)自动跳过")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    monthDayGrid
                        .padding(.leading, 54)
                }
                timeRow
            case .once:
                HStack(spacing: 12) {
                    Text("时刻")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)
                    dayButton
                    GentleTimePicker(label: "", minutes: $minuteOfDay)
                    Spacer()
                }
            case .interval:
                HStack(spacing: 12) {
                    Text("间隔")
                        .font(.callout).foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)
                    GentleLadderPicker(minutes: $intervalMinutes, options: Self.intervalOptions)
                    Spacer()
                }
            }

            Spacer(minLength: 0)

            Text(hint)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                if let reason = disableReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("添加") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 480, height: sheetHeight)
        .foregroundStyle(ink)
        .animation(.easeOut(duration: 0.18), value: mode)
    }

    private var sheetHeight: CGFloat {
        switch mode {
        case .daily: 330
        case .weekly: 380
        case .monthly: 520
        case .interval: 330
        case .once: 340
        }
    }

    private var modeCaption: String {
        switch mode {
        case .daily: "每个到达的时刻"
        case .weekly: "在所选日子的同一时刻"
        case .monthly: "在每月所选的日子"
        case .interval: "按间隔反复提醒"
        case .once: "到点只提醒一次"
        }
    }

    private var hint: String {
        mode == .once
            ? "到点会以居中弹窗提醒一次,之后自动从列表移除。"
            : "到点会以居中弹窗提醒;开关「提醒计划」页的总开关可暂停。"
    }

    // MARK: - 重复方式选择

    /// 胶囊轨道里的五枚文字药丸,风格与 GentleOptionPicker 一致。
    private var modePicker: some View {
        HStack(spacing: 3) {
            ForEach(RepeatMode.allCases, id: \.self) { candidate in
                let on = mode == candidate
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { mode = candidate }
                } label: {
                    Text(candidate.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(on ? ink : .secondary)
                        .frame(width: 44, height: 26)
                        .background(on ? Color.white : .clear, in: Capsule())
                        .shadow(color: .black.opacity(on ? 0.1 : 0), radius: 2, y: 1)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.05), in: Capsule())
    }

    // MARK: - 每周:星期药丸

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let on = weekdays.contains(day)
                Button {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(weekdayNames[day - 1])
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(on ? .white : .secondary)
                        .frame(width: 30, height: 30)
                        .background(on ? green : Color.black.opacity(0.05), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("周\(weekdayNames[day - 1])")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: - 每月:1–31 号多选网格

    private var monthDayGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(34), spacing: 6), count: 7), spacing: 6) {
            ForEach(1...31, id: \.self) { day in
                let on = monthDays.contains(day)
                Button {
                    if on { monthDays.remove(day) } else { monthDays.insert(day) }
                } label: {
                    Text("\(day)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(on ? .white : .secondary)
                        .frame(width: 34, height: 26)
                        .background(on ? green : Color.black.opacity(0.05), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day) 号")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: - 单次:日期胶囊 + 迷你月历

    private var dayButtonLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(oneTimeDay) { return "今天" }
        if calendar.isDateInTomorrow(oneTimeDay) { return "明天" }
        return oneTimeDay.formatted(
            .dateTime.locale(Locale(identifier: "zh_CN")).month().day().weekday(.abbreviated)
        )
    }

    private var dayButton: some View {
        Button {
            showCalendar = true
        } label: {
            HStack(spacing: 6) {
                Text(dayButtonLabel)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(green.opacity(0.08), in: Capsule())
            .overlay {
                Capsule().stroke(showCalendar ? green.opacity(0.5) : green.opacity(0.16))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showCalendar, arrowEdge: .bottom) {
            MiniCalendarView(date: $oneTimeDay)
        }
        .accessibilityLabel("提醒日期")
        .accessibilityValue(dayButtonLabel)
    }

    // MARK: - 时刻

    private var timeRow: some View {
        HStack(spacing: 12) {
            Text("时刻")
                .font(.callout).foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)
            GentleTimePicker(label: "", minutes: $minuteOfDay)
        }
    }

    private func save() {
        let reminder = CustomReminder(
            name: trimmedName,
            repeatMode: mode,
            weekdays: mode == .weekly ? weekdays : [],
            monthDays: mode == .monthly ? monthDays : [],
            minuteOfDay: minuteOfDay,
            intervalMinutes: mode == .interval ? intervalMinutes : 45,
            fireDate: mode == .once ? onceFireDate : nil,
            enabled: true
        )
        store.customReminders.append(reminder)
        store.showToast(store.running
            ? "已添加「\(reminder.name)」,到点会以居中弹窗提醒。"
            : "已添加「\(reminder.name)」,开启提醒后才会计时。")
        dismiss()
    }
}

/// 自绘迷你月历:只能选今天及以后的日期,选中日绿色胶囊,今天描一圈边。
private struct MiniCalendarView: View {
    @Binding var date: Date
    @State private var month: Date

    private let calendar = Calendar.current
    private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
    private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
    private let weekdayNames = ["日", "一", "二", "三", "四", "五", "六"]

    init(date: Binding<Date>) {
        _date = date
        let comps = calendar.dateComponents([.year, .month], from: date.wrappedValue)
        _month = State(initialValue: calendar.date(from: comps) ?? date.wrappedValue)
    }

    /// 网格单元格:前置空位 + 当月各天。
    private var cells: [(date: Date?, day: Int)] {
        guard let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        var result: [(Date?, Int)] = Array(repeating: (nil, 0), count: calendar.component(.weekday, from: first) - 1)
        for day in range {
            result.append((calendar.date(byAdding: .day, value: day - 1, to: first), day))
        }
        return result
    }

    private var todayStart: Date { calendar.startOfDay(for: .now) }
    private var currentMonthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            HStack(spacing: 0) {
                ForEach(weekdayNames, id: \.self) { name in
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                    dayCell(cell)
                }
            }
            Text("只能选今天及以后的日期")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 252)
    }

    private var header: some View {
        HStack {
            Button {
                moveMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(canGoBack ? ink.opacity(0.7) : Color.secondary.opacity(0.4))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canGoBack)
            .accessibilityLabel("上个月")

            Spacer()
            Text(month.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).year().month()))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Spacer()

            Button {
                moveMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下个月")
        }
    }

    private var canGoBack: Bool { month > currentMonthStart }

    private func moveMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: month) else { return }
        month = next
    }

    @ViewBuilder private func dayCell(_ cell: (date: Date?, day: Int)) -> some View {
        if let day = cell.date {
            let isToday = calendar.isDateInToday(day)
            let isSelected = calendar.isDate(day, inSameDayAs: date)
            let isPast = day < todayStart
            Button {
                date = day
            } label: {
                Text("\(cell.day)")
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .rounded).monospacedDigit())
                    .foregroundStyle(isSelected ? Color.white : isPast ? Color.secondary.opacity(0.35) : ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 26)
                    .background(isSelected ? green : .clear, in: Capsule())
                    .overlay {
                        if isToday && !isSelected {
                            Capsule().stroke(green.opacity(0.5))
                        }
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isPast)
            .accessibilityLabel("\(cell.day) 日")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Color.clear.frame(height: 26)
        }
    }
}
