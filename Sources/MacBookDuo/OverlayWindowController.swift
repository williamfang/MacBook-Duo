import AppKit
import MetalKit

@MainActor
final class OverlayWindowController {
    private var window: NSWindow?
    private var renderer: MetalFoldRenderer?

    var isVisible: Bool { window?.isVisible == true }

    func show(image: CGImage, angle: Double) -> Bool {
        guard let screen = NSScreen.screens.first(where: { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
            return CGDisplayIsBuiltin(number) != 0
        }) else { return false }

        if window == nil {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = true
            window.isOpaque = true
            window.backgroundColor = .black
            window.hasShadow = false
            let view = MTKView(frame: window.contentView?.bounds ?? screen.frame)
            view.autoresizingMask = [.width, .height]
            window.contentView = view
            guard let renderer = MetalFoldRenderer(view: view) else { return false }
            self.window = window
            self.renderer = renderer
        }

        do { try renderer?.setImage(image) } catch { return false }
        renderer?.setAngle(angle)
        window?.setFrame(screen.frame, display: true)
        window?.orderFrontRegardless()
        return true
    }

    func update(angle: Double) { renderer?.setAngle(angle) }

    func hide() {
        window?.orderOut(nil)
    }
}
