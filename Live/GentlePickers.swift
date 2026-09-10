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
