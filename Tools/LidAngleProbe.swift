import Foundation
import IOKit.hid

let options = IOOptionBits(kIOHIDOptionsTypeNone)
let manager = IOHIDManagerCreate(kCFAllocatorDefault, options)
guard IOHIDManagerOpen(manager, options) == kIOReturnSuccess else {
    fputs("FAIL: cannot open IOHIDManager\n", stderr)
    exit(1)
}
let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x05AC,
    kIOHIDProductIDKey as String: 0x8104,
    kIOHIDDeviceUsagePageKey as String: 0x20,
    kIOHIDDeviceUsageKey as String: 0x8A
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
      let device = devices.first,
      IOHIDDeviceOpen(device, options) == kIOReturnSuccess else {
    fputs("FAIL: lid angle sensor unavailable\n", stderr)
    exit(2)
}
var report = [UInt8](repeating: 0, count: 8)
var length = report.count
let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
guard result == kIOReturnSuccess, length >= 3 else {
    fputs("FAIL: lid angle report unreadable (IOReturn \(result))\n", stderr)
    exit(3)
}
let angle = UInt16(report[2]) << 8 | UInt16(report[1])
guard angle <= 180 else {
    fputs("FAIL: implausible lid angle \(angle)\n", stderr)
    exit(4)
}
print("PASS: live lid angle \(angle)°")
IOHIDDeviceClose(device, options)
IOHIDManagerClose(manager, options)
