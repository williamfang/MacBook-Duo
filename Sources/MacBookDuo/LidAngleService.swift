import Foundation
import IOKit.hid
import MacBookDuoCore

@MainActor
final class LidAngleService {
    enum Status: Equatable { case stopped, connected, unavailable, readFailed }

    var onAngle: ((Double) -> Void)?
    var onUnavailable: (() -> Void)?
    private(set) var angle: Double?
    private(set) var status: Status = .stopped

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var timer: Timer?
    private var report = [UInt8](repeating: 0, count: 8)
    private var filter = AngleFilter(alpha: 0.4)
    private var consecutiveFailures = 0

    func start() {
        guard timer == nil else { return }
        connect()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let device { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }
        if let manager { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        device = nil
        manager = nil
        status = .stopped
    }

    private func connect() {
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, options)
        guard IOHIDManagerOpen(manager, options) == kIOReturnSuccess else {
            status = .unavailable
            return
        }
        self.manager = manager

        let exact: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x05AC,
            kIOHIDProductIDKey as String: 0x8104,
            kIOHIDDeviceUsagePageKey as String: 0x20,
            kIOHIDDeviceUsageKey as String: 0x8A
        ]
        IOHIDManagerSetDeviceMatching(manager, exact as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let sensor = devices.first,
              IOHIDDeviceOpen(sensor, options) == kIOReturnSuccess else {
            status = .unavailable
            return
        }
        device = sensor
        status = .connected
    }

    private func poll() {
        guard let device else { return }
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess,
              let raw = decodeLidAngle(bytes: Array(report.prefix(length))) else {
            consecutiveFailures += 1
            if consecutiveFailures == 61 {
                status = .readFailed
                onUnavailable?()
            }
            return
        }
        consecutiveFailures = 0
        status = .connected
        let smoothed = filter.push(raw)
        angle = smoothed
        onAngle?(smoothed)
    }
}
