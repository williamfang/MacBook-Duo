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

    public func blurLOD(atVerticalPosition y: Double) -> Double {
        let position = min(max(y, 0), 1)
        let coverage = smoothstep(edge0: -0.2, edge1: 0.2, value: progress - position)
        let onset = smoothstep(edge0: 0, edge1: 0.35, value: progress)
        return 5.5 * coverage * onset
    }

    private func smoothstep(edge0: Double, edge1: Double, value: Double) -> Double {
        let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
