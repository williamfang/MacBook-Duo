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

    public func blurLOD(atVerticalPosition y: Double, verticalDifferencePercent: Double = 25) -> Double {
        let position = min(max(y, 0), 1)
        let difference = min(max(verticalDifferencePercent, 0), 50) / 100
        let onset = smoothstep(edge0: 0, edge1: 0.35, value: progress)
        let verticalStrength = 1 - difference * smoothstep(edge0: 0, edge1: 1, value: position)
        return 5.5 * verticalStrength * onset
    }

    private func smoothstep(edge0: Double, edge1: Double, value: Double) -> Double {
        let t = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
