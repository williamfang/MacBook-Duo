import CoreGraphics
import ScreenCaptureKit

enum DesktopCaptureError: Error { case permissionDenied, builtInDisplayUnavailable, captureFailed }

struct DesktopCaptureService {
    static var hasPermission: Bool { CGPreflightScreenCaptureAccess() }

    static func requestPermission() { _ = CGRequestScreenCaptureAccess() }

    static func captureBuiltInDisplay() async throws -> CGImage {
        guard hasPermission else { throw DesktopCaptureError.permissionDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) else {
            throw DesktopCaptureError.builtInDisplayUnavailable
        }
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        configuration.capturesAudio = false
        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw DesktopCaptureError.captureFailed
        }
    }
}
