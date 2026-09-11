public enum CaptureResult: Equatable, Sendable { case success, permissionDenied, displayUnavailable, failed }
public enum OverlayDecision: Equatable, Sendable { case show, hide }

public func overlayDecision(for result: CaptureResult) -> OverlayDecision {
    result == .success ? .show : .hide
}
