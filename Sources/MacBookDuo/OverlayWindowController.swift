import AppKit
import MetalKit
import QuartzCore
import MacBookDuoCore

@MainActor
final class OverlayWindowController {
    private var window: NSWindow?
    private var renderer: MetalFoldRenderer?
    private var metalView: MTKView?
    private var verticalDifferencePercent = 25.0
    private var angleRange = FoldAngleRange(start: 80, complete: 30)

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
            self.metalView = view
            renderer.setVerticalDifference(percent: verticalDifferencePercent)
            renderer.setAngleRange(angleRange)
        }

        do { try renderer?.setImage(image) } catch { return false }
        renderer?.setAngle(angle)
        window?.setFrame(screen.frame, display: true)
        let wasVisible = window?.isVisible == true
        if !wasVisible { window?.alphaValue = 0 }
        metalView?.draw()
        window?.orderFrontRegardless()
        if !wasVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window?.animator().alphaValue = 1
            }
        }
        return true
    }

    func update(angle: Double) { renderer?.setAngle(angle) }

    func setVerticalDifference(percent: Double) {
        verticalDifferencePercent = min(max(percent, 0), 50)
        renderer?.setVerticalDifference(percent: verticalDifferencePercent)
    }

    func setAngleRange(_ range: FoldAngleRange) {
        angleRange = range
        renderer?.setAngleRange(range)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
