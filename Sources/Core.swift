// BatStats — Battery Status
// Baterai Mac, iPhone & iPad dalam satu ikon di menu bar.
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Core: pembaca baterai iPhone/iPad (MobileDevice.framework) dan baterai Mac (IOKit).

import AppKit
import Foundation
import IOKit.ps

// MARK: - Baterai Mac sendiri

struct MacBattery {
    var level: Int
    var charging: Bool
    var pluggedIn: Bool
    var full: Bool
    var minutesToEmpty: Int?
    var minutesToFull: Int?

    static func read() -> MacBattery? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            let cur = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = max(d[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            let tte = d[kIOPSTimeToEmptyKey] as? Int
            let ttf = d[kIOPSTimeToFullChargeKey] as? Int
            return MacBattery(
                level: Int((Double(cur) / Double(max) * 100).rounded()),
                charging: d[kIOPSIsChargingKey] as? Bool ?? false,
                pluggedIn: (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
                full: d[kIOPSIsChargedKey] as? Bool ?? false,
                minutesToEmpty: (tte ?? -1) > 0 ? tte : nil,
                minutesToFull: (ttf ?? -1) > 0 ? ttf : nil)
        }
        return nil
    }

    var statusLine: String {
        func dur(_ m: Int) -> String { m >= 60 ? "\(m / 60) j \(m % 60) m" : "\(m) m" }
        if full { return "Penuh · terhubung ke charger" }
        if charging { return "Mengisi daya" + (minutesToFull.map { " · penuh dalam \(dur($0))" } ?? "") }
        if pluggedIn { return "Terhubung ke charger · tidak mengisi" }
        return "Memakai baterai" + (minutesToEmpty.map { " · sisa \(dur($0))" } ?? "")
    }

    /// Bentuk Reading supaya bisa memakai tampilan baris yang sama.
    var asReading: Reading {
        Reading(udid: "this-mac", name: Host.current().localizedName ?? "Mac ini", deviceClass: "Mac",
                level: level, charging: charging || full, fullyCharged: full, viaWiFi: false, updated: Date())
    }
}

let macPowerChanged = Notification.Name("batstats.macPowerChanged")

// MARK: - Jembatan ke MobileDevice.framework

typealias AMDeviceRef = UnsafeMutableRawPointer

// Struct C: { AMDeviceRef device; uint32_t message; }  message 1 = tersambung, 2 = terputus
typealias AMNotificationCallback = @convention(c) (UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Void

enum MD {
    static let handle = dlopen("/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice", RTLD_NOW)

    static func sym<T>(_ name: String, as _: T.Type) -> T {
        guard let h = handle, let p = dlsym(h, name) else { fatalError("MobileDevice: \(name) tidak ditemukan") }
        return unsafeBitCast(p, to: T.self)
    }

    typealias SubscribeFn = @convention(c) (AMNotificationCallback, UInt32, UInt32, UnsafeMutableRawPointer?, UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int32
    typealias DevIntFn = @convention(c) (AMDeviceRef) -> Int32
    typealias DevPtrFn = @convention(c) (AMDeviceRef) -> UnsafeMutableRawPointer?
    typealias DevVoidFn = @convention(c) (AMDeviceRef) -> Void
    typealias CopyValueFn = @convention(c) (AMDeviceRef, CFString?, CFString) -> Unmanaged<CFTypeRef>?
    typealias CopyIdFn = @convention(c) (AMDeviceRef) -> Unmanaged<CFString>?

    static let subscribe = sym("AMDeviceNotificationSubscribe", as: SubscribeFn.self)
    static let connect = sym("AMDeviceConnect", as: DevIntFn.self)
    static let disconnect = sym("AMDeviceDisconnect", as: DevIntFn.self)
    static let isPaired = sym("AMDeviceIsPaired", as: DevIntFn.self)
    static let validatePairing = sym("AMDeviceValidatePairing", as: DevIntFn.self)
    static let startSession = sym("AMDeviceStartSession", as: DevIntFn.self)
    static let stopSession = sym("AMDeviceStopSession", as: DevIntFn.self)
    static let interfaceType = sym("AMDeviceGetInterfaceType", as: DevIntFn.self)
    static let retain = sym("AMDeviceRetain", as: DevPtrFn.self)
    static let release = sym("AMDeviceRelease", as: DevVoidFn.self)
    static let copyValue = sym("AMDeviceCopyValue", as: CopyValueFn.self)
    static let copyIdentifier = sym("AMDeviceCopyDeviceIdentifier", as: CopyIdFn.self)
}

// MARK: - Model

struct Reading: Codable {
    var udid: String
    var name: String
    var deviceClass: String   // "iPhone", "iPad", "iPod"
    var level: Int            // 0–100
    var charging: Bool
    var fullyCharged: Bool
    var viaWiFi: Bool
    var updated: Date
    var online: Bool = true
}

enum QueryResult {
    case ok(Reading)
    case notTrusted(String)
    case failed
}

final class DeviceLink {
    let ref: AMDeviceRef
    let udid: String
    let wifi: Bool
    init(ref: AMDeviceRef, udid: String, wifi: Bool) {
        self.ref = ref; self.udid = udid; self.wifi = wifi
    }
}

// MARK: - Pemantau perangkat

final class DeviceMonitor {
    static let shared = DeviceMonitor()

    private let queue = DispatchQueue(label: "batstats.md")
    private var links: [String: DeviceLink] = [:]     // kunci: udid|usb atau udid|wifi
    private var subscription: UnsafeMutableRawPointer?
    var onChange: (() -> Void)?

    private(set) var readings: [String: Reading] = [:]
    private(set) var untrusted: Set<String> = []

    private let storeKey = "readings.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let saved = try? JSONDecoder().decode([String: Reading].self, from: data) {
            readings = saved.mapValues { var r = $0; r.online = false; return r }
        }
    }

    func start() {
        let cb: AMNotificationCallback = { info, _ in
            guard let info = info,
                  let dev = info.load(as: UnsafeMutableRawPointer?.self) else { return }
            let message = info.load(fromByteOffset: MemoryLayout<UnsafeRawPointer>.size, as: UInt32.self)
            DeviceMonitor.shared.handle(device: dev, message: message)
        }
        _ = MD.subscribe(cb, 0, 0, nil, &subscription)
    }

    private func handle(device: AMDeviceRef, message: UInt32) {
        guard let udid = MD.copyIdentifier(device)?.takeRetainedValue() as String? else { return }
        let wifi = MD.interfaceType(device) == 2
        let key = "\(udid)|\(wifi ? "wifi" : "usb")"
        queue.async {
            if message == 1 {
                if let old = self.links[key] { MD.release(old.ref) }
                _ = MD.retain(device)
                self.links[key] = DeviceLink(ref: device, udid: udid, wifi: wifi)
                // Tepat setelah tersambung, iPhone kadang belum siap (mis. masih terkunci),
                // jadi coba beberapa kali.
                for delay in [1.0, 4.0, 10.0, 25.0] {
                    self.queue.asyncAfter(deadline: .now() + delay) { self.refresh(udid: udid) }
                }
            } else if message == 2 {
                // Hanya hapus jika memang koneksi yang sama (hindari salah hapus saat putus-sambung cepat).
                if let old = self.links[key], old.ref == device {
                    self.links.removeValue(forKey: key)
                    MD.release(old.ref)
                }
                let stillThere = self.links.values.contains { $0.udid == udid }
                if !stillThere {
                    DispatchQueue.main.async {
                        self.untrusted.remove(udid)
                        self.readings[udid]?.online = false
                        self.persistAndNotify()
                    }
                }
            }
        }
    }

    /// Perbarui semua perangkat yang sedang terhubung.
    func refreshAll() {
        queue.async {
            let udids = Set(self.links.values.map { $0.udid })
            for u in udids { self.refresh(udid: u) }
        }
    }

    // Harus dipanggil di `queue`.
    private func refresh(udid: String) {
        // Utamakan USB (lebih cepat & stabil), lalu Wi-Fi.
        let candidates = links.values.filter { $0.udid == udid }.sorted { !$0.wifi && $1.wifi }
        guard !candidates.isEmpty else { return }
        var sawUntrusted = false
        defer {
            if sawUntrusted {
                DispatchQueue.main.async {
                    // Tampilkan peringatan hanya jika tetap gagal dan belum ada data segar.
                    if self.readings[udid]?.online != true {
                        self.untrusted.insert(udid); self.onChange?()
                    }
                }
            }
        }
        for link in candidates {
            switch query(link) {
            case .ok(let r):
                DispatchQueue.main.async {
                    self.untrusted.remove(udid)
                    self.readings[udid] = r
                    self.persistAndNotify()
                }
                sawUntrusted = false
                return
            case .notTrusted:
                sawUntrusted = true
                continue
            case .failed:
                continue
            }
        }
    }

    private func query(_ link: DeviceLink) -> QueryResult {
        let d = link.ref
        guard MD.connect(d) == 0 else { return .failed }
        defer { _ = MD.disconnect(d) }
        guard MD.isPaired(d) == 1, MD.validatePairing(d) == 0 else { return .notTrusted(link.udid) }
        guard MD.startSession(d) == 0 else { return .failed }
        defer { _ = MD.stopSession(d) }

        func value(_ domain: String?, _ key: String) -> Any? {
            MD.copyValue(d, domain as CFString?, key as CFString)?.takeRetainedValue()
        }
        let battery = "com.apple.mobile.battery"
        guard let level = (value(battery, "BatteryCurrentCapacity") as? NSNumber)?.intValue else { return .failed }

        let name = value(nil, "DeviceName") as? String ?? "Perangkat"
        let cls = value(nil, "DeviceClass") as? String ?? "iPhone"
        let charging = (value(battery, "BatteryIsCharging") as? NSNumber)?.boolValue ?? false
        let full = (value(battery, "FullyCharged") as? NSNumber)?.boolValue ?? false

        return .ok(Reading(udid: link.udid, name: name, deviceClass: cls, level: level,
                           charging: charging, fullyCharged: full, viaWiFi: link.wifi, updated: Date()))
    }

    private func persistAndNotify() {
        if let data = try? JSONEncoder().encode(readings) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
        onChange?()
    }

    func forget(udid: String) {
        readings.removeValue(forKey: udid)
        persistAndNotify()
    }
}

// MARK: - Login item (LaunchAgent)

enum LoginItem {
    static let label = "io.github.utama-wira.batstats"
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
    static var isEnabled: Bool { FileManager.default.fileExists(atPath: plistURL.path) }

    static func set(_ on: Bool) {
        if on {
            let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [exe],
                "RunAtLoad": true,
                "ProcessType": "Interactive",
            ]
            try? FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                     withIntermediateDirectories: true)
            if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
                try? data.write(to: plistURL)
            }
        } else {
            try? FileManager.default.removeItem(at: plistURL)
        }
    }
}


// MARK: - Pindahan dari versi lama (BateraiKu)

enum Migration {
    static let oldDomain = "id.bateraiku.app"

    static func run() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: "migratedFromBateraiKu") else { return }
        d.set(true, forKey: "migratedFromBateraiKu")

        if let old = UserDefaults(suiteName: oldDomain) {
            for key in ["readings.v1", "history.v1", "barStyle", "showPercent", "lowThreshold", "notifyLow", "notifyFull"] {
                if d.object(forKey: key) == nil, let v = old.object(forKey: key) { d.set(v, forKey: key) }
            }
        }
        let oldAgent = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(oldDomain).plist")
        if FileManager.default.fileExists(atPath: oldAgent.path) {
            try? FileManager.default.removeItem(at: oldAgent)
            LoginItem.set(true)
        }
    }
}

enum AppInfo {
    static let name = "BatStats"
    static let tagline = "Battery Status"
    static let copyright = "© 2026 @utama_wira"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
