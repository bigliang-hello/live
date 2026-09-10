import SwiftUI

/// 周/月回顾卡片：每日照顾次数柱状、水量均值、连续天数与心情洞察。
struct ReviewCard: View {
    let store: WellnessStore
    @State private var scope = 7

    private var tallies: [DayTally] { store.tallies(days: scope) }
    private var peak: Int { max(tallies.map(\.checkIns).max() ?? 1, 1) }
    private var total: Int { tallies.map(\.checkIns).reduce(0, +) }
    private var averageWaterLiters: Double {
        Double(tallies.map(\.water).reduce(0, +)) / 1000 / Double(scope)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("回望").font(.headline)
                    Text(scope == 7 ? "过去 7 天，你和自己相处的痕迹。" : "过去 30 天，慢慢累积的样子。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("范围", selection: $scope) {
                    Text("近 7 天").tag(7)
                    Text("近 30 天").tag(30)
                }
                .pickerStyle(.segmented)
                .frame(width: 176)
            }

            HStack(alignment: .bottom, spacing: scope == 7 ? 10 : 4) {
                ForEach(tallies) { day in
                    let isToday = Calendar.current.isDateInToday(day.date)
                    VStack(spacing: 6) {
                        Capsule()
                            .fill(day.checkIns > 0 ? Color(red: 0.18, green: 0.43, blue: 0.35) : Color(red: 0.18, green: 0.43, blue: 0.35).opacity(0.18))
                            .frame(width: scope == 7 ? 18 : 8, height: barHeight(day.checkIns))
                        Text(label(for: day.date))
                            .font(.system(size: 9, weight: isToday ? .semibold : .regular))
                            .foregroundStyle(isToday ? Color(red: 0.18, green: 0.43, blue: 0.35) : .secondary)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(height: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background {
                        if isToday {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.18, green: 0.43, blue: 0.35).opacity(0.07))
                                .padding(.horizontal, scope == 7 ? -4 : -1)
                        }
                    }
                }
            }
            .frame(height: 130, alignment: .bottom)

            HStack(spacing: 18) {
                Label("共 \(total) 次照顾", systemImage: "checkmark.circle")
                Label(String(format: "日均 %.1f L 水", averageWaterLiters), systemImage: "drop")
                Spacer()
                Text("连续第 \(store.currentStreak) 天")
            }
            .font(.callout)
        }
        .padding(22)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .animation(.easeOut(duration: 0.2), value: scope)
    }

    private func barHeight(_ count: Int) -> CGFloat {
        CGFloat(count) / CGFloat(peak) * 82 + (count > 0 ? 6 : 3)
    }

    private func label(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        guard scope == 7 else {
            let day = calendar.component(.day, from: date)
            return day % 5 == 0 ? "\(day)" : ""
        }
        let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
        return weekdays[calendar.component(.weekday, from: date) - 1]
    }
}
