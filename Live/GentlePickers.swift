import SwiftUI

private let ink = Color(red: 0.12, green: 0.26, blue: 0.24)
private let green = Color(red: 0.18, green: 0.43, blue: 0.35)

/// 胶囊分段选择：数字小药丸排在浅灰轨道里，选中项白色凸起。
/// 用于选项少且需要一眼切换的场景（如小憩时长）。
struct GentleOptionPicker: View {
    let options: [Int]
    @Binding var selection: Int
    var unit: String = "分钟"

    var body: some View {
        HStack(spacing: 6) {
            // 轨道里只放药丸，四边等距；单位作为后缀放在轨道外。
            HStack(spacing: 3) {
                ForEach(options, id: \.self) { value in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = value }
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(selection == value ? ink : .secondary)
                            .frame(width: 34, height: 26)
                            .background(selection == value ? Color.white : .clear, in: Capsule())
                            .shadow(color: .black.opacity(selection == value ? 0.1 : 0), radius: 2, y: 1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value) \(unit)")
                    .accessibilityAddTraits(selection == value ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.05), in: Capsule())

            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// 胶囊 + 气泡档位列表：紧凑显示当前档位，点开挑一档。
/// 用于选项较多的场景（如提醒间隔的 7 档阶梯）。
struct GentleLadderPicker: View {
    @Binding var minutes: Int
    let options: [Int]
    var unit: String = "分钟"
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: 6) {
                Text("\(minutes)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                Text(unit)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(green.opacity(0.08), in: Capsule())
            .overlay {
                Capsule().stroke(isPresented ? green.opacity(0.5) : green.opacity(0.16))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                ForEach(options, id: \.self) { value in
                    optionRow(value)
                }
            }
            .padding(8)
            .frame(minWidth: 150)
        }
        .accessibilityLabel("间隔 \(minutes) \(unit)")
        .accessibilityAddTraits(.isButton)
    }

    private func optionRow(_ value: Int) -> some View {
        let isSelected = value == minutes
        return Button {
            minutes = value
            isPresented = false
        } label: {
            HStack {
                Text("\(value) \(unit)")
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded).monospacedDigit())
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(isSelected ? green : ink.opacity(0.75))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(isSelected ? green.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 温和版时间选择：胶囊显示「HH:MM」，点开是时/分两根滚轮的气泡。
struct GentleTimePicker: View {
    let label: String
    @Binding var minutes: Int
    @State private var isPresented = false

    private var hour: Int { minutes / 60 % 24 }
    private var minute: Int { minutes % 60 }

    /// 分钟按 5 分钟一档；历史值不在档上时也把它列进去，避免滚轮空选。
    private var minuteValues: [Int] {
        var values = Array(stride(from: 0, to: 60, by: 5))
        if !values.contains(minute) {
            values.append(minute)
            values.sort()
        }
        return values
    }

    private var hourBinding: Binding<Int> {
        Binding(get: { hour }, set: { minutes = $0 * 60 + minute })
    }

    private var minuteBinding: Binding<Int> {
        Binding(get: { minute }, set: { minutes = hour * 60 + $0 })
    }

    var body: some View {
        HStack(spacing: 8) {
            if !label.isEmpty {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Button {
                isPresented = true
            } label: {
                HStack(spacing: 6) {
                    Text(String(format: "%02d:%02d", hour, minute))
                        .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(ink)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(green.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule().stroke(isPresented ? green.opacity(0.5) : green.opacity(0.16))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                wheels
                    .padding(16)
                    .frame(minWidth: 196)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)时间")
        .accessibilityValue(String(format: "%02d:%02d", hour, minute))
    }

    private var wheels: some View {
        HStack(spacing: 4) {
            WheelColumn(values: Array(0..<24), selection: hourBinding)
            Text(":")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
            WheelColumn(values: minuteValues, selection: minuteBinding)
        }
    }
}

/// 自绘滚轮列：点击一行即选中并居中，上下边缘淡出，中间一行带高亮条。
struct WheelColumn: View {
    let values: [Int]
    @Binding var selection: Int

    private let rowHeight: CGFloat = 44

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(Color(red: 0.85, green: 0.92, blue: 0.86).opacity(0.7))
                    .frame(height: rowHeight)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: 44)
                        ForEach(values, id: \.self) { value in
                            row(value).id(value)
                        }
                        Color.clear.frame(height: 44)
                    }
                }
                .frame(width: 78, height: rowHeight * 3)
                .clipped()
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .black, location: 0.3),
                            .init(color: .black, location: 0.7),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
            .onChange(of: selection) { _, value in
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(value, anchor: .center)
                }
            }
        }
    }

    private func row(_ value: Int) -> some View {
        Button {
            selection = value
        } label: {
            Text(String(format: "%02d", value))
                .font(.system(size: 16, weight: selection == value ? .semibold : .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(selection == value ? ink : .secondary)
                .frame(width: 72, height: rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
