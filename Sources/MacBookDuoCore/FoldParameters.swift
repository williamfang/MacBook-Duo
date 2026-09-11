import Foundation

public struct FoldParameters: Equatable, Sendable {
    public let progress: Double
    public let verticalScale: Double
    public let blurRadius: Double
    public let darkness: Double
    public let glassTint: Double

    public static func make(angle: Double, trigger: Double = 85, blackout: Double = 15) -> Self {
        let t = min(max((trigger - angle) / (trigger - blackout), 0), 1)
        let eased = t * t * (3 - 2 * t)
        return .init(
            progress: t,
            verticalScale: max(sin(max(angle, 0) * .pi / 180), 0.035),
            blurRadius: 28 * eased,
            darkness: 0.92 * pow(t, 1.35),
            glassTint: sin(t * .pi) * 0.22
        )
    }
}
