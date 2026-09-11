import AppKit
import MacBookDuoCore

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let sensor = LidAngleService()
    private let overlay = OverlayWindowController()
    private var state = FoldStateMachine()
    private var statusItem: NSStatusItem?
    private var angleItem: NSMenuItem?
    private var sensorItem: NSMenuItem?
    private var permissionItem: NSMenuItem?
    private var enableItem: NSMenuItem?
    private var slider: NSSlider?
    private var isEnabled = true
    private var captureInFlight = false
    private var captureGeneration: UInt = 0
    private var latestAngle = 120.0
    private var escapeMonitor: Any?
    private var testHideTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        sensor.onAngle = { [weak self] angle in self?.receive(angle: angle) }
        sensor.onUnavailable = { [weak self] in self?.cancelOverlay() }
        sensor.start()
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { Task { @MainActor in self?.cancelOverlay() } }
        }
        refreshMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sensor.stop()
        overlay.hide()
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        testHideTimer?.invalidate()
    }

    private func receive(angle: Double) {
        latestAngle = angle
        angleItem?.title = String(format: "屏幕角度  %.1f°", angle)
        sensorItem?.title = sensor.status == .connected ? "传感器已连接" : "传感器不可用"
        guard isEnabled else { return }

        switch state.update(angle: angle) {
        case .capture:
            captureAndShow()
        case .render:
            if overlay.isVisible { overlay.update(angle: angle) }
        case .blackout:
            if overlay.isVisible { overlay.update(angle: 0) }
        case .hide:
            overlay.hide()
        case .none:
            break
        }
    }

    private func captureAndShow() {
        guard !captureInFlight else { return }
        captureInFlight = true
        captureGeneration &+= 1
        let generation = captureGeneration
        Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == captureGeneration { captureInFlight = false }
            }
            do {
                let image = try await DesktopCaptureService.captureBuiltInDisplay()
                guard isEnabled, generation == captureGeneration, latestAngle <= 92 else { return }
                if !overlay.show(image: image, angle: latestAngle) {
                    overlay.hide()
                }
            } catch {
                overlay.hide()
                refreshMenu()
            }
        }
    }

    private func configureMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: "MacBook Duo")
        let menu = NSMenu()
        let title = NSMenuItem(title: "MacBook Duo", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let angle = NSMenuItem(title: "屏幕角度  --", action: nil, keyEquivalent: "")
        angle.isEnabled = false
        menu.addItem(angle)
        angleItem = angle

        let sensorStatus = NSMenuItem(title: "正在连接传感器…", action: nil, keyEquivalent: "")
        sensorStatus.isEnabled = false
        menu.addItem(sensorStatus)
        sensorItem = sensorStatus

        let permission = NSMenuItem(title: "授予屏幕录制权限…", action: #selector(requestCapturePermission), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)
        permissionItem = permission

        menu.addItem(.separator())
        let enabled = NSMenuItem(title: "启用自动折叠效果", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = .on
        menu.addItem(enabled)
        enableItem = enabled

        let sliderItem = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 42))
        let slider = NSSlider(value: 85, minValue: 15, maxValue: 85, target: self, action: #selector(testSliderChanged(_:)))
        slider.frame = NSRect(x: 16, y: 8, width: 208, height: 26)
        slider.toolTip = "测试折叠角度（松开后恢复）"
        container.addSubview(slider)
        sliderItem.view = container
        menu.addItem(sliderItem)
        self.slider = slider

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出 MacBook Duo", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    private func refreshMenu() {
        let allowed = DesktopCaptureService.hasPermission
        permissionItem?.title = allowed ? "屏幕录制权限已授予" : "授予屏幕录制权限…"
        permissionItem?.isEnabled = !allowed
        sensorItem?.title = sensor.status == .connected ? "传感器已连接" : "传感器不可用"
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enableItem?.state = isEnabled ? .on : .off
        if !isEnabled { overlay.hide() }
        state = FoldStateMachine()
    }

    @objc private func requestCapturePermission() {
        DesktopCaptureService.requestPermission()
        refreshMenu()
    }

    @objc private func testSliderChanged(_ sender: NSSlider) {
        let angle = sender.doubleValue
        testHideTimer?.invalidate()
        testHideTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancelOverlay() }
        }
        if overlay.isVisible {
            overlay.update(angle: angle)
        } else {
            latestAngle = angle
            captureAndShow()
        }
    }

    private func cancelOverlay() {
        captureGeneration &+= 1
        captureInFlight = false
        overlay.hide()
        state = FoldStateMachine()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
