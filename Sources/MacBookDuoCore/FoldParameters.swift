import Foundation

public struct FoldParameters: Equatable, Sendable {
    public let progress: Double
    public let contentScale: Double
    public let blurRadius: Double
    public let darkness: Double
    public let glassTint: Double

    public static func make(angle: Double, trigger: Double = 85, blackout: Double = 15) -> Self {
        let t = min(max((trigger - angle) / (trigger - blackout), 0), 1)
        let eased = t * t * (3 - 2 * t)
        return .init(
            progress: t,
            contentScale: 1,
            blurRadius: 48 * eased,
            darkness: pow(t, 1.35),
            glassTint: sin(t * .pi) * 0.22
        )
    }
}
