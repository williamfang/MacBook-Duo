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
    private var controlWindow: NSWindow?
    private var windowAngleLabel: NSTextField?
    private var windowStatusLabel: NSTextField?
    private var permissionButton: NSButton?
    private var differenceValueLabel: NSTextField?
    private var isEnabled = true
    private var captureInFlight = false
    private var captureGeneration: UInt = 0
    private var latestAngle = 120.0
    private var escapeMonitor: Any?
    private var testHideTimer: Timer?
    private var verticalDifferencePercent: Double = {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "verticalDifferencePercent") == nil
            ? 25
            : min(max(defaults.double(forKey: "verticalDifferencePercent"), 0), 50)
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenu()
        configureControlWindow()
        overlay.setVerticalDifference(percent: verticalDifferencePercent)
        sensor.onAngle = { [weak self] angle in self?.receive(angle: angle) }
        sensor.onUnavailable = { [weak self] in self?.cancelOverlay() }
        sensor.start()
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { Task { @MainActor in self?.cancelOverlay() } }
        }
        refreshMenu()
        showControlWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow()
        return true
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
        windowAngleLabel?.stringValue = String(format: "当前屏幕角度：%.1f°", angle)
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
        item.button?.title = " Duo"
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

    private func configureControlWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacBook Duo"
        window.isReleasedWhenClosed = false

        let title = NSTextField(labelWithString: "MacBook Duo 正在运行")
        title.font = .systemFont(ofSize: 24, weight: .semibold)
        title.alignment = .center

        let detail = NSTextField(wrappingLabelWithString: "屏幕低于 85° 时自动冻结桌面并启动折叠效果，重新打开到 92° 以上恢复。")
        detail.alignment = .center
        detail.textColor = .secondaryLabelColor

        let angle = NSTextField(labelWithString: "当前屏幕角度：正在读取…")
        angle.font = .monospacedDigitSystemFont(ofSize: 18, weight: .medium)
        angle.alignment = .center
        windowAngleLabel = angle

        let status = NSTextField(labelWithString: "正在检查权限和传感器…")
        status.alignment = .center
        windowStatusLabel = status

        let permission = NSButton(title: "授予屏幕录制权限", target: self, action: #selector(requestCapturePermission))
        permission.bezelStyle = .rounded
        permission.keyEquivalent = "\r"
        permissionButton = permission

        let differenceTitle = NSTextField(labelWithString: "上下模糊差异")
        differenceTitle.font = .systemFont(ofSize: 13, weight: .medium)
        let differenceValue = NSTextField(labelWithString: "\(Int(verticalDifferencePercent))%")
        differenceValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        differenceValue.alignment = .right
        differenceValueLabel = differenceValue
        let differenceHeader = NSStackView(views: [differenceTitle, differenceValue])
        differenceHeader.orientation = .horizontal
        differenceHeader.distribution = .fill
        differenceHeader.widthAnchor.constraint(equalToConstant: 300).isActive = true
        let differenceSlider = NSSlider(value: verticalDifferencePercent, minValue: 0, maxValue: 50, target: self, action: #selector(verticalDifferenceChanged(_:)))
        differenceSlider.isContinuous = true
        differenceSlider.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let stack = NSStackView(views: [title, detail, angle, status, differenceHeader, differenceSlider, permission])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)
        ])
        controlWindow = window
    }

    private func showControlWindow() {
        controlWindow?.center()
        controlWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        refreshMenu()
    }

    private func refreshMenu() {
        let allowed = DesktopCaptureService.hasPermission
        permissionItem?.title = allowed ? "屏幕录制权限已授予" : "授予屏幕录制权限…"
        permissionItem?.isEnabled = !allowed
        sensorItem?.title = sensor.status == .connected ? "传感器已连接" : "传感器不可用"
        let sensorText = sensor.status == .connected ? "传感器已连接" : "正在连接传感器…"
        windowStatusLabel?.stringValue = allowed ? "\(sensorText) · 屏幕录制权限已授予" : "\(sensorText) · 需要屏幕录制权限"
        permissionButton?.isHidden = allowed
    }

    @objc private func toggleEnabled() {
        isEnabled.toggle()
        enableItem?.state = isEnabled ? .on : .off
        if !isEnabled { overlay.hide() }
        state = FoldStateMachine()
    }

    @objc func requestCapturePermission() {
        DesktopCaptureService.requestPermission()
        refreshMenu()
        if !DesktopCaptureService.hasPermission {
            let alert = NSAlert()
            alert.messageText = "请允许 MacBook Duo 录制屏幕"
            alert.informativeText = "在系统设置的“隐私与安全性 → 屏幕与系统音频录制”中启用 MacBook Duo，然后退出并重新打开应用。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "稍后")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
        }
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

    @objc private func verticalDifferenceChanged(_ sender: NSSlider) {
        verticalDifferencePercent = sender.doubleValue
        differenceValueLabel?.stringValue = "\(Int(sender.doubleValue.rounded()))%"
        UserDefaults.standard.set(verticalDifferencePercent, forKey: "verticalDifferencePercent")
        overlay.setVerticalDifference(percent: verticalDifferencePercent)
    }

    private func cancelOverlay() {
        captureGeneration &+= 1
        captureInFlight = false
        overlay.hide()
        state = FoldStateMachine()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}
