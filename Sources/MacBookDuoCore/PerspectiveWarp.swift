public enum PerspectiveWarp {
    public static let maximumAmount = 0.08

    public static func amount(progress: Double, enabled: Bool) -> Double {
        guard enabled else { return 0 }
        let value = min(max(progress, 0), 1)
        let eased = value * value * (3 - 2 * value)
        return maximumAmount * eased
    }
}
