public enum FoldTransition: Equatable, Sendable {
    case none
    case capture(progress: Double)
    case render(progress: Double)
    case blackout
    case hide
}

public struct FoldStateMachine: Sendable {
    public let triggerAngle: Double
    public let resetAngle: Double
    public let blackoutAngle: Double
    private var active = false

    public init(triggerAngle: Double = 85, resetAngle: Double = 92, blackoutAngle: Double = 15) {
        self.triggerAngle = triggerAngle
        self.resetAngle = resetAngle
        self.blackoutAngle = blackoutAngle
    }

    public mutating func update(angle: Double) -> FoldTransition {
        guard angle.isFinite, (0...180).contains(angle) else { return .none }

        if active, angle > resetAngle {
            active = false
            return .hide
        }
        guard active || angle < triggerAngle else { return .none }

        let progress = min(max((triggerAngle - angle) / (triggerAngle - blackoutAngle), 0), 1)
        if !active {
            active = true
            return .capture(progress: progress)
        }
        return angle <= blackoutAngle ? .blackout : .render(progress: progress)
    }
}
