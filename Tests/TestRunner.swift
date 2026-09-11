import Foundation
import MacBookDuoCore

private var failures = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures += 1
        fputs("FAIL: \(message)\n", stderr)
    }
}

private func close(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.0001) -> Bool {
    abs(lhs - rhs) <= tolerance
}

func runStateTests() {
    var state = FoldStateMachine()
    expect(state.update(angle: 100) == .none, "open screen stays idle")
    expect(state.update(angle: 84) == .capture(progress: 1.0 / 70.0), "first threshold crossing captures")
    expect(state.update(angle: 70) == .render(progress: 15.0 / 70.0), "active fold renders")
    expect(state.update(angle: 84) == .render(progress: 1.0 / 70.0), "active fold does not recapture")
    expect(state.update(angle: 90) == .render(progress: 0), "hysteresis keeps overlay active")
    expect(state.update(angle: 93) == .hide, "reset threshold hides overlay")
    expect(state.update(angle: 15) == .capture(progress: 1), "a new fold first captures even at blackout angle")
    expect(state.update(angle: 15) == .blackout, "subsequent sample blacks out")
}

func runFilterTests() {
    var filter = AngleFilter(alpha: 0.5)
    expect(close(filter.push(100), 100), "first filter sample is immediate")
    expect(close(filter.push(80), 90), "filter smooths toward input")
    expect(close(filter.push(80), 85), "filter converges")
    expect(close(filter.push(.nan), 85), "invalid sample is ignored")
}

func runDecodingTests() {
    expect(decodeLidAngle(bytes: [1, 85, 0]) == 85, "little-endian HID angle decodes")
    expect(decodeLidAngle(bytes: [1, 120, 0, 0]) == 120, "extra report bytes are accepted")
    expect(decodeLidAngle(bytes: [1, 181, 0]) == nil, "out-of-range HID angle is rejected")
    expect(decodeLidAngle(bytes: [1, 85]) == nil, "short HID report is rejected")
}

func runParameterTests() {
    let open = FoldParameters.make(angle: 85)
    expect(close(open.progress, 0), "trigger angle starts at zero progress")
    expect(close(open.blurRadius, 0), "trigger angle is sharp")
    expect(close(open.blurLOD(atVerticalPosition: 0), 0), "trigger angle is sharp at the top edge")
    let middle = FoldParameters.make(angle: 50)
    expect(close(middle.progress, 0.5), "mid angle maps to half progress")
    expect(close(middle.contentScale, 1), "fold effect never changes screen-edge geometry")
    let topBlur = middle.blurLOD(atVerticalPosition: 0)
    let centerBlur = middle.blurLOD(atVerticalPosition: 0.5)
    let bottomBlur = middle.blurLOD(atVerticalPosition: 1)
    expect(topBlur > centerBlur && centerBlur > bottomBlur, "blur progresses smoothly from top edge downward")
    expect(bottomBlur / topBlur >= 0.70 && bottomBlur / topBlur <= 0.80, "top-to-bottom blur difference stays near 25 percent")
    let closed = FoldParameters.make(angle: 15)
    expect(close(closed.progress, 1), "blackout angle completes progress")
    expect(closed.darkness > 0.9, "blackout angle is dark")
    expect(close(closed.blurLOD(atVerticalPosition: 0), 5.5), "blackout angle reaches maximum blur at top")
}

func runCaptureDecisionTests() {
    expect(overlayDecision(for: .success) == .show, "successful capture shows overlay")
    expect(overlayDecision(for: .permissionDenied) == .hide, "denied permission fails open")
    expect(overlayDecision(for: .displayUnavailable) == .hide, "missing display fails open")
    expect(overlayDecision(for: .failed) == .hide, "capture failure fails open")
}

runStateTests()
runFilterTests()
runDecodingTests()
runParameterTests()
runCaptureDecisionTests()
if failures == 0 {
    print("PASS: all core tests")
} else {
    exit(1)
}
