import SwiftUI

struct OfficeExercise: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let summary: String
    let dose: String
    let frameLabels: [String]

    static let library: [OfficeExercise] = [
        OfficeExercise(
            id: "neck-side",
            title: "颈部侧伸展",
            summary: "坐直，肩膀放松，让耳朵缓慢靠近肩膀；不要抬肩。",
            dose: "左右各停留 10 秒",
            frameLabels: ["坐直", "向左", "向右"]
        ),
        OfficeExercise(
            id: "shoulder-open",
            title: "肩胛后收",
            summary: "手肘弯曲，肩胛骨缓慢向后、向下夹紧，再放松。",
            dose: "缓慢重复 8 次",
            frameLabels: ["放松", "向后夹", "放松"]
        ),
        OfficeExercise(
            id: "calf-raise",
            title: "站立提踵",
            summary: "扶稳桌边，脚跟缓慢抬起，再有控制地落下。",
            dose: "缓慢重复 12 次",
            frameLabels: ["站稳", "抬脚跟", "慢慢落下"]
        ),
        OfficeExercise(
            id: "chest-open",
            title: "扩胸运动",
            summary: "坐直或站直，双臂从身前缓慢打开，避免耸肩。",
            dose: "打开时停留 3 秒，重复 6 次",
            frameLabels: ["手臂向前", "慢慢打开", "充分展开"]
        )
    ]

    static func find(_ id: String) -> OfficeExercise? {
        library.first { $0.id == id }
    }
}

struct ExerciseAnimationView: View {
    let exercise: OfficeExercise

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date.now

    private let accent = Color(red: 0.20, green: 0.48, blue: 0.36)

    /// 演示节奏中的一个步骤：先移动到目标姿势，再停留感受拉伸。
    private struct DemoStep {
        let label: String
        let target: Int
        let move: Double
        let hold: Double

        var duration: Double { move + hold }
    }

    private struct DemoState {
        var phase: Double
        var ghostPhase: Double
        var ghostAlpha: Double
        var instruction: String
        var isHolding: Bool
        var stepProgress: Double
        var frameIndex: Int

        static let still = DemoState(
            phase: 0, ghostPhase: 0, ghostAlpha: 0,
            instruction: "动作起始姿势", isHolding: false,
            stepProgress: 0, frameIndex: 0
        )
    }

    private var demoSteps: [DemoStep] {
        switch exercise.id {
        case "neck-side":
            return [
                DemoStep(label: "向左侧倾", target: 1, move: 1.3, hold: 2.2),
                DemoStep(label: "回正", target: 0, move: 1.3, hold: 0.5),
                DemoStep(label: "向右侧倾", target: 2, move: 1.3, hold: 2.2),
                DemoStep(label: "回正", target: 0, move: 1.3, hold: 0.5)
            ]
        case "shoulder-open":
            return [
                DemoStep(label: "肩胛向后夹", target: 1, move: 1.2, hold: 1.8),
                DemoStep(label: "放松", target: 0, move: 1.2, hold: 0.9)
            ]
        case "calf-raise":
            return [
                DemoStep(label: "抬起脚跟", target: 1, move: 1.1, hold: 1.5),
                DemoStep(label: "慢慢落下", target: 0, move: 1.1, hold: 1.0)
            ]
        default:
            return [
                DemoStep(label: "手臂慢慢打开", target: 1, move: 1.4, hold: 1.2),
                DemoStep(label: "充分展开", target: 2, move: 1.1, hold: 2.0),
                DemoStep(label: "轻轻收回", target: 0, move: 1.3, hold: 0.7)
            ]
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let state = playbackState(at: timeline.date)
            VStack(spacing: 12) {
                ExercisePoseCanvas(
                    exerciseID: exercise.id,
                    phase: state.phase,
                    ghostPhase: state.ghostPhase,
                    ghostAlpha: state.ghostAlpha
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 10) {
                    Image(systemName: reduceMotion ? "figure.stand" : state.isHolding ? "pause.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(accent)
                    Text(reduceMotion ? DemoState.still.instruction : state.instruction)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .contentTransition(.opacity)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<exercise.frameLabels.count, id: \.self) { index in
                            stepDot(index: index, state: state)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white.opacity(0.72), in: Capsule())
            }
            .padding(18)
            .background(Color(red: 0.91, green: 0.95, blue: 0.92), in: RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(exercise.title)动画示意，当前步骤：\(state.instruction)")
        }
        .onAppear { startedAt = .now }
    }

    private func stepDot(index: Int, state: DemoState) -> some View {
        let isActive = index == state.frameIndex
        return Capsule()
            .fill(.secondary.opacity(0.18))
            .frame(width: isActive ? 28 : 6, height: 6)
            .overlay(alignment: .leading) {
                if isActive {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(accent)
                            .frame(width: proxy.size.width * state.stepProgress)
                    }
                }
            }
            .animation(.easeOut(duration: 0.2), value: state.frameIndex)
    }

    private func playbackState(at date: Date) -> DemoState {
        guard !reduceMotion else { return .still }

        let steps = demoSteps
        let loop = steps.reduce(0.0) { $0 + $1.duration }
        let elapsed = max(0, date.timeIntervalSince(startedAt)).truncatingRemainder(dividingBy: loop)

        var consumed = 0.0
        for (index, step) in steps.enumerated() {
            let from = Double(steps[(index + steps.count - 1) % steps.count].target)
            let to = Double(step.target)
            let moveEnd = consumed + step.move
            let stepEnd = consumed + step.duration

            if elapsed < moveEnd {
                let progress = (elapsed - consumed) / step.move
                let eased = (1 - cos(progress * .pi)) / 2
                let phase = from + (to - from) * eased
                return DemoState(
                    phase: phase,
                    ghostPhase: from + (phase - from) * 0.82,
                    ghostAlpha: sin(progress * .pi),
                    instruction: step.label,
                    isHolding: false,
                    stepProgress: (elapsed - consumed) / step.duration,
                    frameIndex: step.target
                )
            }
            if elapsed < stepEnd {
                return DemoState(
                    phase: to,
                    ghostPhase: to,
                    ghostAlpha: 0,
                    instruction: "\(step.label) · 保持",
                    isHolding: true,
                    stepProgress: (elapsed - consumed) / step.duration,
                    frameIndex: step.target
                )
            }
            consumed = stepEnd
        }

        return .still
    }
}

private struct ExercisePoseCanvas: View {
    let exerciseID: String
    let phase: Double
    let ghostPhase: Double
    let ghostAlpha: Double

    private enum ActivePart { case neck, arms, legs }

    private var activePart: ActivePart {
        switch exerciseID {
        case "neck-side": .neck
        case "calf-raise": .legs
        default: .arms
        }
    }

    private let ink = Color(red: 0.12, green: 0.34, blue: 0.29)
    private let accent = Color(red: 0.20, green: 0.48, blue: 0.36)

    var body: some View {
        Canvas { context, size in
            var floor = Path()
            floor.move(to: CGPoint(x: size.width * 0.25, y: size.height * 0.90))
            floor.addLine(to: CGPoint(x: size.width * 0.75, y: size.height * 0.90))
            context.stroke(floor, with: .color(.secondary.opacity(0.22)), lineWidth: 2)

            if ghostAlpha > 0.01 {
                drawFigure(
                    interpolatedPose(for: exerciseID, phase: ghostPhase),
                    in: &context,
                    size: size,
                    color: ink.opacity(0.14 * ghostAlpha),
                    activeColor: accent.opacity(0.16 * ghostAlpha),
                    showsFocus: false
                )
            }
            drawFigure(
                interpolatedPose(for: exerciseID, phase: phase),
                in: &context,
                size: size,
                color: ink,
                activeColor: accent,
                showsFocus: true
            )
        }
        .padding(.horizontal, 90)
        .padding(.vertical, 2)
    }

    /// 画一个人形：activeColor 标出这个动作主要活动的部位，focus 光圈提示发力点。
    private func drawFigure(
        _ pose: ExercisePose,
        in context: inout GraphicsContext,
        size: CGSize,
        color: Color,
        activeColor: Color,
        showsFocus: Bool
    ) {
        func point(_ value: CGPoint) -> CGPoint {
            CGPoint(x: value.x * size.width, y: value.y * size.height)
        }
        func segment(_ from: CGPoint, _ to: CGPoint, active: Bool) {
            var path = Path()
            path.move(to: point(from))
            path.addLine(to: point(to))
            context.stroke(
                path,
                with: .color(active ? activeColor : color),
                style: StrokeStyle(lineWidth: active ? 7 : 6, lineCap: .round, lineJoin: .round)
            )
        }
        func focus(_ center: CGPoint) {
            let radius = min(size.width, size.height) * 0.085
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(activeColor.opacity(0.13))
            )
        }

        if showsFocus {
            switch activePart {
            case .neck: focus(point(pose.head))
            case .arms: focus(point(pose.leftHand)); focus(point(pose.rightHand))
            case .legs: focus(point(pose.leftFoot)); focus(point(pose.rightFoot))
            }
        }

        let armsActive = activePart == .arms
        let legsActive = activePart == .legs

        segment(pose.shoulder, pose.hip, active: false)
        segment(pose.shoulder, pose.head, active: activePart == .neck)
        segment(pose.shoulder, pose.leftElbow, active: armsActive)
        segment(pose.leftElbow, pose.leftHand, active: armsActive)
        segment(pose.shoulder, pose.rightElbow, active: armsActive)
        segment(pose.rightElbow, pose.rightHand, active: armsActive)
        segment(pose.hip, pose.leftKnee, active: legsActive)
        segment(pose.leftKnee, pose.leftFoot, active: legsActive)
        segment(pose.hip, pose.rightKnee, active: legsActive)
        segment(pose.rightKnee, pose.rightFoot, active: legsActive)

        let headSize = min(size.width, size.height) * 0.14
        let headPoint = point(pose.head)
        context.fill(
            Path(ellipseIn: CGRect(
                x: headPoint.x - headSize / 2,
                y: headPoint.y - headSize / 2,
                width: headSize,
                height: headSize
            )),
            with: .color(activePart == .neck ? activeColor : color)
        )
    }

    private func interpolatedPose(for id: String, phase: Double) -> ExercisePose {
        let lowerFrame = max(0, min(2, Int(floor(phase))))
        let upperFrame = max(0, min(2, Int(ceil(phase))))
        let progress = phase - Double(lowerFrame)
        return pose(for: id, frame: lowerFrame).interpolated(
            to: pose(for: id, frame: upperFrame),
            progress: progress
        )
    }

    private func pose(for id: String, frame: Int) -> ExercisePose {
        var value = ExercisePose(
            head: CGPoint(x: 0.50, y: 0.16),
            shoulder: CGPoint(x: 0.50, y: 0.29),
            hip: CGPoint(x: 0.50, y: 0.57),
            leftElbow: CGPoint(x: 0.40, y: 0.42),
            leftHand: CGPoint(x: 0.40, y: 0.59),
            rightElbow: CGPoint(x: 0.60, y: 0.42),
            rightHand: CGPoint(x: 0.60, y: 0.59),
            leftKnee: CGPoint(x: 0.43, y: 0.72),
            leftFoot: CGPoint(x: 0.39, y: 0.87),
            rightKnee: CGPoint(x: 0.57, y: 0.72),
            rightFoot: CGPoint(x: 0.61, y: 0.87)
        )

        switch id {
        case "neck-side":
            value.head.x = frame == 1 ? 0.43 : frame == 2 ? 0.57 : 0.50
            value.head.y = frame == 0 ? 0.16 : 0.19
        case "shoulder-open":
            if frame == 1 {
                value.leftElbow = CGPoint(x: 0.34, y: 0.37)
                value.leftHand = CGPoint(x: 0.46, y: 0.43)
                value.rightElbow = CGPoint(x: 0.66, y: 0.37)
                value.rightHand = CGPoint(x: 0.54, y: 0.43)
            }
        case "calf-raise":
            if frame == 1 {
                value.head.y -= 0.05
                value.shoulder.y -= 0.05
                value.hip.y -= 0.05
                value.leftKnee.y -= 0.05
                value.rightKnee.y -= 0.05
                value.leftFoot = CGPoint(x: 0.42, y: 0.83)
                value.rightFoot = CGPoint(x: 0.58, y: 0.83)
            }
        case "chest-open":
            if frame == 0 {
                value.leftElbow = CGPoint(x: 0.46, y: 0.39)
                value.leftHand = CGPoint(x: 0.49, y: 0.48)
                value.rightElbow = CGPoint(x: 0.54, y: 0.39)
                value.rightHand = CGPoint(x: 0.51, y: 0.48)
            } else if frame == 1 {
                value.leftElbow = CGPoint(x: 0.34, y: 0.36)
                value.leftHand = CGPoint(x: 0.25, y: 0.37)
                value.rightElbow = CGPoint(x: 0.66, y: 0.36)
                value.rightHand = CGPoint(x: 0.75, y: 0.37)
            } else {
                value.leftElbow = CGPoint(x: 0.31, y: 0.30)
                value.leftHand = CGPoint(x: 0.18, y: 0.24)
                value.rightElbow = CGPoint(x: 0.69, y: 0.30)
                value.rightHand = CGPoint(x: 0.82, y: 0.24)
            }
        default:
            break
        }
        return value
    }
}

private struct ExercisePose {
    var head: CGPoint
    var shoulder: CGPoint
    var hip: CGPoint
    var leftElbow: CGPoint
    var leftHand: CGPoint
    var rightElbow: CGPoint
    var rightHand: CGPoint
    var leftKnee: CGPoint
    var leftFoot: CGPoint
    var rightKnee: CGPoint
    var rightFoot: CGPoint

    func interpolated(to other: ExercisePose, progress: Double) -> ExercisePose {
        func point(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
            CGPoint(
                x: start.x + (end.x - start.x) * progress,
                y: start.y + (end.y - start.y) * progress
            )
        }

        return ExercisePose(
            head: point(head, other.head),
            shoulder: point(shoulder, other.shoulder),
            hip: point(hip, other.hip),
            leftElbow: point(leftElbow, other.leftElbow),
            leftHand: point(leftHand, other.leftHand),
            rightElbow: point(rightElbow, other.rightElbow),
            rightHand: point(rightHand, other.rightHand),
            leftKnee: point(leftKnee, other.leftKnee),
            leftFoot: point(leftFoot, other.leftFoot),
            rightKnee: point(rightKnee, other.rightKnee),
            rightFoot: point(rightFoot, other.rightFoot)
        )
    }
}
