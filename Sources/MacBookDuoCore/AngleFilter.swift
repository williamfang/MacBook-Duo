public struct AngleFilter: Sendable {
    public let alpha: Double
    private var value: Double?

    public init(alpha: Double = 0.35) {
        self.alpha = min(max(alpha, 0.01), 1)
    }

    public mutating func push(_ sample: Double) -> Double {
        guard sample.isFinite, (0...180).contains(sample) else { return value ?? 0 }
        guard let current = value else {
            value = sample
            return sample
        }
        let next = current + (sample - current) * alpha
        value = next
        return next
    }
}
