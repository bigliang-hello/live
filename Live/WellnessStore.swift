import SwiftUI
import UserNotifications
import CoreGraphics

struct Reminder: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var subtitle: String
    var symbol: String
    var minutes: Int
    var enabled = true

    static let defaults = [
        Reminder(id: "water", title: "喝点水", subtitle: "给忙碌按一下暂停，喝几口水。", symbol: "drop.fill", minutes: 45),
        Reminder(id: "move", title: "起来走走", subtitle: "离开椅子，活动一下身体。", symbol: "figure.walk", minutes: 60),
        Reminder(id: "eyes", title: "让眼睛放个假", subtitle: "移开视线，看看远处。", symbol: "eye", minutes: 30, enabled: false)
    ]

    /// 间隔档位，自适应节奏建议在此基础上往后退一档。
    static let intervalLadder = [15, 20, 30, 45, 60, 90, 120]
}

struct CheckIn: Codable, Identifiable {
    var id = UUID()
    var kind: String
    var date = Date()
    var amount: Int?
}

/// 自适应节奏给出的温和建议：某项提醒今天被推迟太多次，建议放宽一档。
struct RhythmSuggestion: Identifiable {
    let reminder: Reminder
    let minutes: Int
    var id: String { reminder.id }
}

/// 一天的回顾数据。
struct DayTally: Identifiable {
    let date: Date
    let checkIns: Int
    let water: Int
    var id: Date { date }
}

@MainActor @Observable final class WellnessStore {
    static let shared = WellnessStore()

    var reminders: [Reminder] {
        didSet {
            save()
            applyReminderChanges(from: oldValue)
        }
    }
    var records: [CheckIn] { didSet { save() } }
    var nextFireDates: [String: Date] = [:]
    var running = false
    var busy = false
    var notice = "开启后，提醒会以应用浮窗出现在屏幕中央。"

    // 工作时段：开启后提醒只在工作窗口内出现，午休时段静默。
    var workHoursEnabled = false { didSet { persistWorkHours(); restartTasksIfRunning() } }
    var workStartMinutes = 9 * 60 { didSet { persistWorkHours(); restartTasksIfRunning() } }
    var workEndMinutes = 19 * 60 { didSet { persistWorkHours(); restartTasksIfRunning() } }
    var lunchEnabled = false { didSet { persistWorkHours(); restartTasksIfRunning() } }
    var lunchStartMinutes = 12 * 60 + 30 { didSet { persistWorkHours(); restartTasksIfRunning() } }
    var lunchEndMinutes = 13 * 60 + 30 { didSet { persistWorkHours(); restartTasksIfRunning() } }
    // 周末不提醒：配合工作时段使用，周六周日整体静默，周一窗口开始时恢复。
    var weekendSilenced = false { didSet { persistWorkHours(); restartTasksIfRunning() } }

    // 闲置检测：运动提醒到期时若用户不在电脑前，暂停等待，回来后再提醒。
    var moveWaitingForUser = false

    // 节奏：今天各提醒被推迟的次数（每日自动归零）。
    private(set) var snoozeCountsToday: [String: Int] = [:]

    private let defaults = UserDefaults.standard
    private var reminderTasks: [String: Task<Void, Never>] = [:]
    private var snoozeTasks: [Task<Void, Never>] = []
    private var bootstrapping = true

    init() {
        reminders = Self.read("reminders") ?? Reminder.defaults
        records = Self.read("records") ?? []
        running = UserDefaults.standard.bool(forKey: "running")
        loadWorkHours()
        loadSnoozeCounts()
        bootstrapping = false
    }

    private static func read<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func save() {
        defaults.set(try? JSONEncoder().encode(reminders), forKey: "reminders")
        defaults.set(try? JSONEncoder().encode(records), forKey: "records")
    }

    // MARK: - 今日与打卡

    var today: [CheckIn] {
        records.filter { Calendar.current.isDateInToday($0.date) }
    }

    func count(_ kind: String) -> Int {
        today.filter { $0.kind == kind }.count
    }

    var waterTotal: Int {
        today.filter { $0.kind == "water" }.compactMap(\.amount).reduce(0, +)
    }

    var formattedWaterTotal: String {
        waterTotal >= 1_000
            ? String(format: "%.1f L", Double(waterTotal) / 1_000)
            : "\(waterTotal) ml"
    }

    var activeReminderCount: Int {
        reminders.filter(\.enabled).count
    }

    func check(_ kind: String, amount: Int? = nil) {
        records.append(CheckIn(kind: kind, amount: amount))
    }

    func checkWater(_ amount: Int) {
        check("water", amount: amount)
        notice = "已记录 \(amount) ml，今天共摄入 \(formattedWaterTotal)。"
    }

    func undo(_ id: UUID) {
        records.removeAll { $0.id == id }
    }

    func title(forKind kind: String) -> String {
        if let reminder = reminders.first(where: { $0.id == kind }) { return reminder.title }
        switch kind {
        case "rest": return "白噪音小憩"
        default: return kind
        }
    }

    // MARK: - 连续天数与回顾

    private var careDaySet: Set<Date> {
        let calendar = Calendar.current
        return Set(records.map { calendar.startOfDay(for: $0.date) })
    }

    /// 温和版连续天数：今天还没打卡不打断连续，从昨天往回数。
    var currentStreak: Int {
        let calendar = Calendar.current
        let days = careDaySet
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while days.contains(day), streak < 3650 {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return streak
    }

    var weekCareDays: Int {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: .now) ?? DateInterval(start: .now, duration: 0)
        return careDaySet.filter { interval.contains($0) }.count
    }

    func tallies(days: Int) -> [DayTally] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { return nil }
            let dayRecords = records.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let water = dayRecords.filter { $0.kind == "water" }.compactMap(\.amount).reduce(0, +)
            return DayTally(date: day, checkIns: dayRecords.count, water: water)
        }
    }

    // MARK: - 白噪音小憩

    func finishNap(minutes: Int) {
        records.append(CheckIn(kind: "rest", amount: minutes))
        notice = "小憩了 \(minutes) 分钟，也记进了今天的照顾。"
    }

    // MARK: - 提醒调度

    func resumeRemindersIfNeeded() {
        removeLegacySystemNotifications()
        guard running else { return }
        startReminderTasks()
        notice = "居中提醒正在运行。关闭窗口后仍会按计划出现。"
    }

    func schedule() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }

        let active = reminders.filter(\.enabled)
        guard !active.isEmpty else {
            stop()
            notice = "先启用至少一种提醒。"
            return
        }

        startReminderTasks()
        running = true
        defaults.set(true, forKey: "running")
        notice = "提醒已开启。关闭窗口后仍会弹出；下班时可从菜单栏暂停。"
    }

    func stop() {
        reminderTasks.values.forEach { $0.cancel() }
        reminderTasks.removeAll()
        snoozeTasks.forEach { $0.cancel() }
        snoozeTasks.removeAll()
        nextFireDates.removeAll()
        moveWaitingForUser = false
        ReminderPopupController.shared.stopAll()
        removeLegacySystemNotifications()
        running = false
        defaults.set(false, forKey: "running")
        notice = "提醒已暂停，随时可以继续。"
    }

    func showWaterReminder() {
        ReminderPopupController.shared.show(.water)
    }

    func showMovementReminder(excluding id: String? = nil) {
        ReminderPopupController.shared.show(.move(randomExercise(excluding: id)))
    }

    private func showQueuedMovementReminder() {
        ReminderPopupController.shared.enqueue(.move(randomExercise(excluding: nil)))
    }

    private func randomExercise(excluding id: String?) -> OfficeExercise {
        let choices = OfficeExercise.library.filter { $0.id != id }
        return choices.randomElement() ?? OfficeExercise.library[0]
    }

    func showEyeReminder() {
        ReminderPopupController.shared.show(.eyes)
    }

    func snooze(_ kind: String, minutes: Int = 10) {
        snoozeCountsToday[kind, default: 0] += 1
        persistSnoozeCounts()
        let task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Double(minutes * 60)))
            guard !Task.isCancelled, let self else { return }
            self.showReminder(kind)
        }
        snoozeTasks.append(task)
        notice = "已推迟 \(minutes) 分钟。"
    }

    // MARK: - 工作时段

    func isInWorkHours(_ date: Date = .now) -> Bool {
        guard workHoursEnabled else { return true }
        if weekendSilenced, Calendar.current.isDateInWeekend(date) { return false }
        let minute = Self.minuteOfDay(date)
        guard minute >= workStartMinutes, minute < workEndMinutes else { return false }
        if lunchEnabled, minute >= lunchStartMinutes, minute < lunchEndMinutes { return false }
        return true
    }

    /// 下一个工作窗口的开始时刻；未开启工作时段时返回 nil（随时可提醒）。
    /// 周末静默时窗口可能相隔两天以上，扫描放宽到 4 天。
    func nextWorkWindowStart(after date: Date) -> Date? {
        guard workHoursEnabled else { return nil }
        let calendar = Calendar.current
        var probe = date
        for _ in 0..<(4 * 24 * 60) {
            guard let next = calendar.date(byAdding: .minute, value: 1, to: probe) else { break }
            probe = next
            if isInWorkHours(probe) { return probe }
        }
        return nil
    }

    /// 下次触发时间：先按间隔计算，若落在工作时段外则顺延到下一个窗口开始。
    func clampedFireDate(afterMinutes minutes: Int, from date: Date = .now) -> Date {
        let fire = date.addingTimeInterval(Double(max(1, minutes) * 60))
        guard !isInWorkHours(fire) else { return fire }
        return nextWorkWindowStart(after: fire) ?? fire
    }

    var workHoursStatus: String {
        guard workHoursEnabled else { return "未开启：全天都会按时提醒。" }
        func clock(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60 % 24, minutes % 60) }
        let lunch = lunchEnabled ? "，午休 \(clock(lunchStartMinutes))–\(clock(lunchEndMinutes)) 静默" : ""
        let weekend = weekendSilenced ? "，周末静默" : ""
        if isInWorkHours() {
            return "现在在工作时段内（\(clock(workStartMinutes))–\(clock(workEndMinutes))\(lunch)\(weekend)）。"
        }
        if let next = nextWorkWindowStart(after: .now) {
            // 恢复时刻在今天就只说时间，跨天（如周末后）带上星期。
            let time = Calendar.current.isDateInToday(next)
                ? next.formatted(.dateTime.hour().minute())
                : next.formatted(.dateTime.locale(Locale(identifier: "zh_CN")).weekday(.wide).hour().minute())
            return "现在不在提醒时段（\(clock(workStartMinutes))–\(clock(workEndMinutes))\(lunch)\(weekend)），将在 \(time) 恢复。"
        }
        return "工作时段设置有误，请检查起止时间。"
    }

    private static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func persistWorkHours() {
        defaults.set(workHoursEnabled, forKey: "work.enabled")
        defaults.set(workStartMinutes, forKey: "work.start")
        defaults.set(workEndMinutes, forKey: "work.end")
        defaults.set(lunchEnabled, forKey: "lunch.enabled")
        defaults.set(lunchStartMinutes, forKey: "lunch.start")
        defaults.set(lunchEndMinutes, forKey: "lunch.end")
        defaults.set(weekendSilenced, forKey: "work.weekend")
    }

    private func loadWorkHours() {
        if defaults.object(forKey: "work.enabled") != nil { workHoursEnabled = defaults.bool(forKey: "work.enabled") }
        if let value = defaults.object(forKey: "work.start") as? Int { workStartMinutes = value }
        if let value = defaults.object(forKey: "work.end") as? Int { workEndMinutes = value }
        if let value = defaults.object(forKey: "lunch.enabled") as? Bool { lunchEnabled = value }
        if let value = defaults.object(forKey: "lunch.start") as? Int { lunchStartMinutes = value }
        if let value = defaults.object(forKey: "lunch.end") as? Int { lunchEndMinutes = value }
        if let value = defaults.object(forKey: "work.weekend") as? Bool { weekendSilenced = value }
    }

    private func restartTasksIfRunning() {
        guard running, !bootstrapping else { return }
        startReminderTasks()
    }

    // MARK: - 节奏建议

    func snoozeCount(_ id: String) -> Int {
        snoozeCountsToday[id] ?? 0
    }

    var rhythmSuggestions: [RhythmSuggestion] {
        let ladder = Reminder.intervalLadder
        return reminders.compactMap { reminder in
            guard snoozeCount(reminder.id) >= 2,
                  let index = ladder.firstIndex(of: reminder.minutes),
                  index < ladder.count - 1 else { return nil }
            return RhythmSuggestion(reminder: reminder, minutes: ladder[index + 1])
        }
    }

    func applyRhythmSuggestion(_ suggestion: RhythmSuggestion) {
        guard let index = reminders.firstIndex(where: { $0.id == suggestion.reminder.id }) else { return }
        reminders[index].minutes = suggestion.minutes
        snoozeCountsToday[suggestion.reminder.id] = 0
        persistSnoozeCounts()
        notice = "已把「\(suggestion.reminder.title)」放宽到 \(suggestion.minutes) 分钟，试试新的节奏。"
    }

    private var snoozeDayKey: String {
        "snooze." + Date.now.formatted(.dateTime.year().month().day())
    }

    private func loadSnoozeCounts() {
        snoozeCountsToday = defaults.dictionary(forKey: snoozeDayKey) as? [String: Int] ?? [:]
    }

    private func persistSnoozeCounts() {
        defaults.set(snoozeCountsToday, forKey: snoozeDayKey)
    }

    // MARK: - 计时任务

    /// 只重启某一项提醒的计时：取消旧任务，按当前间隔重新倒数。
    /// 未启用则只取消，不新建任务。其他提醒不受影响。
    private func restartTask(for reminder: Reminder) {
        reminderTasks[reminder.id]?.cancel()
        reminderTasks[reminder.id] = nil
        nextFireDates[reminder.id] = nil
        guard reminder.enabled else { return }

        nextFireDates[reminder.id] = clampedFireDate(afterMinutes: reminder.minutes)
        reminderTasks[reminder.id] = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let fire = self.clampedFireDate(afterMinutes: reminder.minutes)
                self.nextFireDates[reminder.id] = fire
                try? await Task.sleep(for: .seconds(max(1, fire.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                if reminder.id == "move" { await self.waitForUserBack() }
                guard !Task.isCancelled else { return }
                self.showReminder(reminder.id)
            }
        }
    }

    /// 闲置等待（仅运动提醒）：用户离开超过 3 分钟时暂停，检测到回来再继续。
    private func waitForUserBack() async {
        while !Task.isCancelled && Self.userIdleSeconds() >= 180 {
            moveWaitingForUser = true
            try? await Task.sleep(for: .seconds(20))
        }
        moveWaitingForUser = false
    }

    static func userIdleSeconds() -> Double {
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let keys = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        return max(mouse, keys)
    }

    /// 列表里的间隔或开关被修改后立即生效，且只影响被改的那一项。
    private func applyReminderChanges(from old: [Reminder]) {
        guard running else { return }
        for (oldReminder, newReminder) in zip(old, reminders) where oldReminder != newReminder {
            restartTask(for: newReminder)
            notice = "已应用「\(newReminder.title)」的修改，其他提醒的倒计时不受影响。"
        }
    }

    private func startReminderTasks() {
        reminderTasks.values.forEach { $0.cancel() }
        reminderTasks.removeAll()
        removeLegacySystemNotifications()
        nextFireDates.removeAll()

        for reminder in reminders where reminder.enabled {
            restartTask(for: reminder)
        }
    }

    private func showReminder(_ kind: String) {
        switch kind {
        case "water": ReminderPopupController.shared.enqueue(.water)
        case "move": showQueuedMovementReminder()
        case "eyes": ReminderPopupController.shared.enqueue(.eyes)
        default: break
        }
    }

    private func removeLegacySystemNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
