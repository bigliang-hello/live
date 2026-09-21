import SwiftUI
import LunarSwift

private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
private let green = Color(red: 0.18, green: 0.43, blue: 0.35)
private let almanacRed = Color(red: 0.66, green: 0.18, blue: 0.13)
private let almanacCream = Color(red: 0.98, green: 0.96, blue: 0.91)
private let almanacGreen = Color(red: 0.85, green: 0.92, blue: 0.86)
private let workOrange = Color(red: 0.85, green: 0.45, blue: 0.06)

/// 「今日黄历」页:一整张老黄历日历牌——红头 + 左月历右详情。
/// 月份格子默认选中今天,点任意日期,右侧展示该日的农历、干支、
/// 宜忌、节气、冲煞、吉神方位等,数据全部来自 LunarSwift。
struct AlmanacTabView: View {
    @State private var monthAnchor = Date.now
    @State private var selected = Date.now
    @State private var cells: [DayCell?] = []

    var body: some View {
        sheet
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
            .onAppear { cells = Self.buildCells(for: monthAnchor) }
            .onChange(of: monthAnchor) { _, new in
                cells = Self.buildCells(for: new)
            }
    }

    // MARK: - 现代纸本黄历

    private var sheet: some View {
        VStack(spacing: 16) {
            dayHero
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    calendarPane
                        .frame(minWidth: 390, idealWidth: 520, maxWidth: .infinity)
                    almanacPane
                        .frame(width: 360)
                }
                VStack(spacing: 16) {
                    calendarPane
                    almanacPane
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: selected)
    }

    /// 日期是页面第一视觉：公历大字、农历说明、节日节气与生肖印章。
    private var dayHero: some View {
        let solar = Solar.fromDate(date: selected)
        let lunar = solar.lunar
        let badge = !lunar.jieQi.isEmpty
            ? lunar.jieQi
            : (lunar.festivals.first ?? solar.festivals.first)
        return HStack(spacing: 22) {
            VStack(spacing: 0) {
                Text("\(solar.day)")
                    .font(.system(size: 58, weight: .light, design: .rounded))
                    .foregroundStyle(almanacRed)
                    .contentTransition(.numericText())
                Text("\(solar.month) 月")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(almanacRed.opacity(0.72))
            }

            Rectangle()
                .fill(almanacRed.opacity(0.13))
                .frame(width: 1, height: 72)

            VStack(alignment: .leading, spacing: 7) {
                Text("\(lunar.monthInChinese)月\(lunar.dayInChinese)")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(ink)
                Text("\(solar.year)年 · 星期\(solar.weekInChinese) · \(solar.xingZuo)座")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ink.opacity(0.55))
                Text("\(lunar.yearInGanZhi)年　\(lunar.monthInGanZhi)月　\(lunar.dayInGanZhi)日")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(green)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 10) {
                if let badge {
                    Label(badge, systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(almanacRed)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.62), in: Capsule())
                }
                HStack(spacing: 8) {
                    Text("生肖")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ink.opacity(0.45))
                    Text(lunar.yearShengXiao)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(almanacRed)
                        .frame(width: 42, height: 42)
                        .background(almanacCream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(almanacRed.opacity(0.25), lineWidth: 1)
                        }
                        .rotationEffect(.degrees(-2))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [almanacCream, almanacGreen.opacity(0.88)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.62), lineWidth: 1)
        }
        .shadow(color: green.opacity(0.06), radius: 16, y: 7)
    }

    // MARK: - 左:月历

    private var monthTitle: String {
        let comps = Calendar.current.dateComponents([.year, .month], from: monthAnchor)
        return "\(comps.year ?? 0)年\(comps.month ?? 0)月"
    }

    private var monthSubTitle: String {
        let lunar = Solar.fromDate(date: monthAnchor).lunar
        return "\(lunar.yearInGanZhi)年 · 属\(lunar.yearShengXiao)"
    }

    private var calendarPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                navButton("chevron.left") { shiftMonth(-1) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(monthTitle)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                    Text(monthSubTitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ink.opacity(0.5))
                }
                navButton("chevron.right") { shiftMonth(1) }
                Spacer()
                Button {
                    monthAnchor = .now
                    selected = .now
                } label: {
                    Text("今天")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(almanacGreen.opacity(0.82), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(Array(["日", "一", "二", "三", "四", "五", "六"].enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(index == 0 || index == 6 ? almanacRed.opacity(0.6) : ink.opacity(0.4))
                            .frame(maxWidth: .infinity)
                    }
                }
                paneSeparator
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { index, cell in
                        Group {
                            if let cell {
                                CalendarDayButton(
                                    cell: cell,
                                    isSelected: Calendar.current.isDate(cell.date, inSameDayAs: selected)
                                ) {
                                    selected = cell.date
                                }
                            } else {
                                Color.clear.frame(height: 56)
                            }
                        }
                        .gridLines(leading: index % 7 != 0, top: index >= 7)
                    }
                }
            }
        }
        .padding(20)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(green.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: ink.opacity(0.035), radius: 14, y: 6)
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(green.opacity(0.78))
                .frame(width: 28, height: 28)
                .background(almanacGreen.opacity(0.72), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "chevron.left" ? "上一个月" : "下一个月")
    }

    /// 月份导航:LunarSwift 的数据范围在 1900–2100 年,夹在安全区间内。
    private func shiftMonth(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: monthAnchor) else { return }
        guard (1901 ... 2099).contains(Calendar.current.component(.year, from: next)) else { return }
        withAnimation(.easeOut(duration: 0.18)) { monthAnchor = next }
    }

    // MARK: - 右:当日黄历

    private var almanacPane: some View {
        let solar = Solar.fromDate(date: selected)
        let lunar = solar.lunar
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("当日黄历")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(almanacRed.opacity(0.75))
                    Text("\(lunar.monthInChinese)月\(lunar.dayInChinese)")
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(ink)
                    Text("\(lunar.yearInGanZhi)年 · \(lunar.yearNaYin)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ink.opacity(0.55))
                }
                Spacer()
                Text(lunar.dayShengXiao)
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(almanacRed)
                    .frame(width: 34, height: 34)
                    .background(almanacRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(almanacRed.opacity(0.22), lineWidth: 1)
                    }
            }

            HStack(spacing: 8) {
                ganZhiChip("年", lunar.yearInGanZhi)
                ganZhiChip("月", lunar.monthInGanZhi)
                ganZhiChip("日", lunar.dayInGanZhi)
                Spacer()
            }

            paneSeparator

            yiJiChips(label: "宜", items: lunar.dayYi, badge: green, text: green)
            yiJiChips(label: "忌", items: lunar.dayJi, badge: almanacRed, text: almanacRed.opacity(0.9))

            paneSeparator

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                alignment: .leading,
                spacing: 9
            ) {
                infoItem("冲煞", "冲\(lunar.dayChongDesc) 煞\(lunar.daySha)")
                infoItem("十二值星", lunar.zhiXing)
                infoItem("喜神方位", lunar.dayPositionXiDesc)
                infoItem("财神方位", lunar.dayPositionCaiDesc)
                infoItem("日纳音", lunar.dayNaYin)
                infoItem("星宿", lunar.xiu)
            }

            Text("彭祖百忌：\(lunar.pengZuGan)　\(lunar.pengZuZhi)")
                .font(.system(size: 11))
                .foregroundStyle(ink.opacity(0.5))

            nextJieQiLine(lunar)
        }
        .padding(20)
        .background(almanacCream.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(almanacRed.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: ink.opacity(0.035), radius: 14, y: 6)
    }

    private func ganZhiChip(_ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(value).font(.system(size: 12, weight: .medium, design: .rounded))
            Text(label).font(.system(size: 9)).opacity(0.5)
        }
        .foregroundStyle(ink.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 宜/忌一行:印章式方块字领头,事项做成一枚枚小签牌自然换行。
    private func yiJiChips(label: String, items: [String], badge: Color, text: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(badge, in: RoundedRectangle(cornerRadius: 7))
            Group {
                if items.isEmpty {
                    Text("—")
                        .font(.system(size: 12))
                        .foregroundStyle(ink.opacity(0.4))
                } else {
                    FlowLayout(lineSpacing: 7, itemSpacing: 6) {
                        ForEach(Array(items.prefix(9).enumerated()), id: \.offset) { _, item in
                            Text(item)
                                .font(.system(size: 11.5))
                                .foregroundStyle(text)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 6))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(text.opacity(0.3), lineWidth: 0.8)
                                }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(badge.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(badge.opacity(0.12), lineWidth: 0.8)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func infoItem(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ink.opacity(0.45))
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ink.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 10))
    }

    private func nextJieQiLine(_ lunar: Lunar) -> some View {
        let next = lunar.nextJieQi
        return HStack(spacing: 7) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 11))
                .foregroundStyle(almanacRed.opacity(0.75))
            Text("下一节气 \(next.name) · \(next.solar.month)月\(next.solar.day)日")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ink.opacity(0.62))
            Spacer()
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
    }

    private var paneSeparator: some View {
        Rectangle()
            .fill(ink.opacity(0.09))
            .frame(height: 1)
    }

    // MARK: - 月历格子数据

    /// 组装一个月的格子:月首对齐星期日起步,每格附农历日/节气/节日小字。
    private static func buildCells(for anchor: Date) -> [DayCell?] {
        let calendar = Calendar.current
        guard let month = calendar.dateInterval(of: .month, for: anchor) else { return [] }
        var result: [DayCell?] = Array(repeating: nil, count: calendar.component(.weekday, from: month.start) - 1)
        let today = calendar.startOfDay(for: .now)
        var cursor = month.start
        while cursor < month.end {
            let solar = Solar.fromDate(date: cursor)
            let lunar = solar.lunar
            let mark: DayCell.Mark
            let subtitle: String
            if let holiday = HolidayUtil.getHolidayByYmd(year: solar.year, month: solar.month, day: solar.day) {
                // 法定节假日及调休:调休上班的标「班」,休息的亮出假期名。
                mark = holiday.work ? .workday : .festival
                subtitle = holiday.work ? "班" : holiday.name
            } else if let festival = lunar.festivals.first ?? solar.festivals.first ?? lunar.otherFestivals.first {
                mark = .festival
                subtitle = festival
            } else if !lunar.jieQi.isEmpty {
                mark = .jieqi
                subtitle = lunar.jieQi
            } else if lunar.dayInChinese == "初一" {
                // 每月初一显示月份,是传统月历的惯例。
                mark = .monthStart
                subtitle = "\(lunar.monthInChinese)月"
            } else {
                mark = .plain
                subtitle = lunar.dayInChinese
            }
            let weekday = calendar.component(.weekday, from: cursor)
            result.append(DayCell(
                date: cursor,
                day: calendar.component(.day, from: cursor),
                isToday: calendar.isDate(cursor, inSameDayAs: today),
                isWeekend: weekday == 1 || weekday == 7,
                subtitle: subtitle,
                mark: mark
            ))
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? month.end
        }
        return result
    }
}

/// 月历里的一个日子:数字 + 农历小字,选中红圆、今日红圈、悬停淡红。
private struct CalendarDayButton: View {
    let cell: DayCell
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 3) {
                Text("\(cell.day)")
                    .font(.system(size: 15, weight: isSelected || cell.isToday ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white : cell.isWeekend ? almanacRed.opacity(0.75) : ink)
                    .frame(width: 27, height: 27)
                    .background {
                        if isSelected {
                            Circle().fill(almanacRed)
                        } else if hovered {
                            Circle().fill(almanacGreen.opacity(0.9))
                        }
                    }
                    .overlay {
                        if cell.isToday, !isSelected {
                            Circle().stroke(almanacRed.opacity(0.75), lineWidth: 1.2)
                        }
                    }
                Text(cell.subtitle)
                    .font(.system(size: 9.5, weight: cell.mark == .festival || cell.mark == .workday ? .semibold : .regular))
                    .foregroundStyle(isSelected ? almanacRed : markColor(cell.mark))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private func markColor(_ mark: DayCell.Mark) -> Color {
    switch mark {
    case .festival: almanacRed
    case .workday: workOrange
    case .jieqi: green
    case .monthStart: ink.opacity(0.62)
    case .plain: ink.opacity(0.4)
    }
}

private struct DayCell: Identifiable {
    enum Mark { case festival, workday, jieqi, monthStart, plain }

    let date: Date
    let day: Int
    let isToday: Bool
    let isWeekend: Bool
    let subtitle: String
    let mark: Mark
    var id: Date { date }
}

/// 纸面日历的淡红格线:内部画左线与顶线,行首列首由容器边框兜底。
private extension View {
    func gridLines(leading: Bool, top: Bool) -> some View {
        overlay(alignment: .leading) {
            if leading {
                Rectangle().fill(ink.opacity(0.045)).frame(width: 0.8)
            }
        }
        .overlay(alignment: .top) {
            if top {
                Rectangle().fill(ink.opacity(0.045)).frame(height: 0.8)
            }
        }
    }
}

/// 极简流式布局:宜忌小签牌按宽度自动换行。
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
