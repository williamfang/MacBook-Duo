public func decodeLidAngle(bytes: [UInt8]) -> Double? {
    guard bytes.count >= 3 else { return nil }
    let raw = UInt16(bytes[2]) << 8 | UInt16(bytes[1])
    let angle = Double(raw)
    return (0...180).contains(angle) ? angle : nil
}
