public struct FoldAngleRange: Equatable, Sendable {
    public let start: Double
    public let complete: Double
    public var reset: Double { min(start + 7, 90) }

    public init(start: Double, complete: Double) {
        let safeStart = min(max(start, 5), 90)
        self.start = safeStart
        self.complete = min(max(complete, 0), safeStart - 5)
    }
}

public enum EffectDefaults {
    public static let foldRange = FoldAngleRange(start: 90, complete: 30)
    public static let verticalDifferencePercent = 30.0
    public static let perspectiveEnabled = true
}
