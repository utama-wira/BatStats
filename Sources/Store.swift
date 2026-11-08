// BatStats — Battery Status
// Baterai Mac, iPhone & iPad dalam satu ikon di menu bar.
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Store: satu sumber data untuk ikon menu bar dan panel.

import AppKit
import SwiftUI
import UserNotifications

struct Sample: Codable, Identifiable {
    var t: Date
    var l: Int
    var c: Bool
    var id: Date { t }
}

enum BarStyle: String, CaseIterable, Identifiable {
    case ring, battery, text
    var id: String { rawValue }
    var label: String {
        switch self {
        case .ring: return "Cincin"
        case .battery: return "Baterai"
        case .text: return "Angka"
        }
    }
}

struct DeviceItem: Identifiable, Equatable {
    var id: String
    var name: String
    var kind: String        // Mac, iPhone, iPad
    var level: Int
    var charging: Bool
    var full: Bool
    var online: Bool
    var connection: String  // "Mac ini", "USB", "Wi-Fi", "Offline"
    var updated: Date
    var detail: String
    var symbol: String
    var isMac: Bool { id == Store.macID }

    /// Data iCloud dianggap "aktif" selama 3 jam; setelah itu tampil abu-abu.
    static let iCloudFreshFor: TimeInterval = 3 * 3600

    mutating func apply(_ c: ICloudReading) {
        level = c.level
        charging = c.charging
        full = c.charging && c.level >= 100
        updated = c.updated
        online = Date().timeIntervalSince(c.updated) < DeviceItem.iCloudFreshFor
        connection = "iCloud"
        let state = c.charging ? "Mengisi daya" : "Memakai baterai"
        detail = online ? "\(state) · dikirim \(Fmt.time(c.updated))" : "Terakhir lewat iCloud \(Fmt.time(c.updated))"
    }
}

enum Fmt {
    static let locale = Locale(identifier: "id_ID")

    static func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = locale
        if Calendar.current.isDateInToday(d) { f.dateFormat = "HH.mm" }
        else if Calendar.current.isDateInYesterday(d) { f.dateFormat = "'kemarin' HH.mm" }
        else { f.dateFormat = "d MMM HH.mm" }
        return f.string(from: d)
    }

    static func relative(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 60 { return "baru saja" }
        let f = RelativeDateTimeFormatter()
        f.locale = locale
        f.unitsStyle = .full
        return f.localizedString(for: d, relativeTo: Date())
    }
}

// Warna sesuai kondisi, dipakai di ikon menu bar dan panel.
enum Palette {
    static func ns(level: Int, charging: Bool, online: Bool, low: Int) -> NSColor {
        if !online { return .secondaryLabelColor }
        if charging { return .systemGreen }
        if level <= low { return .systemRed }
        return .labelColor
    }

    static func gradient(level: Int, charging: Bool, online: Bool, low: Int) -> [Color] {
        if !online { return [.gray.opacity(0.5), .gray.opacity(0.35)] }
        if charging { return [Color(red: 0.20, green: 0.85, blue: 0.45), Color(red: 0.10, green: 0.75, blue: 0.85)] }
        if level <= low { return [Color(red: 1.0, green: 0.25, blue: 0.30), Color(red: 1.0, green: 0.55, blue: 0.20)] }
        if level <= 50 { return [Color(red: 1.0, green: 0.70, blue: 0.10), Color(red: 1.0, green: 0.85, blue: 0.30)] }
        return [Color(red: 0.25, green: 0.80, blue: 0.50), Color(red: 0.40, green: 0.90, blue: 0.40)]
    }
}

final class Store: ObservableObject {
    static let shared = Store()
    static let macID = "this-mac"

    let monitor = DeviceMonitor.shared
    private let defaults = UserDefaults.standard
    private lazy var macName: String = Host.current().localizedName ?? "Mac ini"

    @Published private(set) var devices: [DeviceItem] = []
    @Published private(set) var history: [String: [Sample]] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh = Date()
    @Published private(set) var hasUntrusted = false

    @Published var barStyle: BarStyle { didSet { defaults.set(barStyle.rawValue, forKey: "barStyle"); onBarChange?() } }
    @Published var showPercent: Bool { didSet { defaults.set(showPercent, forKey: "showPercent"); onBarChange?() } }
    @Published var lowThreshold: Int { didSet { defaults.set(lowThreshold, forKey: "lowThreshold"); onBarChange?() } }
    @Published var notifyLow: Bool { didSet { defaults.set(notifyLow, forKey: "notifyLow"); if notifyLow { askNotificationPermission() } } }
    @Published var notifyFull: Bool { didSet { defaults.set(notifyFull, forKey: "notifyFull"); if notifyFull { askNotificationPermission() } } }
    @Published var launchAtLogin: Bool { didSet { LoginItem.set(launchAtLogin) } }
    @Published var useICloud: Bool {
        didSet {
            defaults.set(useICloud, forKey: "useICloud")
            if useICloud { ICloudSource.ensureFolder() }
            reload()
        }
    }

    var onBarChange: (() -> Void)?
    /// Untuk screenshot publik: sembunyikan nama asli perangkat.
    var demoNames = false

    private var notifiedLow: Set<String> = []
    private var notifiedFull: Set<String> = []

    init() {
        barStyle = BarStyle(rawValue: defaults.string(forKey: "barStyle") ?? "") ?? .ring
        showPercent = defaults.object(forKey: "showPercent") as? Bool ?? true
        lowThreshold = defaults.object(forKey: "lowThreshold") as? Int ?? 20
        notifyLow = defaults.object(forKey: "notifyLow") as? Bool ?? true
        notifyFull = defaults.object(forKey: "notifyFull") as? Bool ?? false
        launchAtLogin = LoginItem.isEnabled
        useICloud = defaults.object(forKey: "useICloud") as? Bool ?? true
        if useICloud { ICloudSource.ensureFolder() }
        if let data = defaults.data(forKey: "history.v1"),
           let h = try? JSONDecoder().decode([String: [Sample]].self, from: data) { history = h }
    }

    // MARK: Data

    func reload() {
        var items: [DeviceItem] = []
        if let m = MacBattery.read() {
            items.append(DeviceItem(id: Store.macID, name: macName, kind: "Mac", level: m.level,
                                    charging: m.charging, full: m.full, online: true, connection: "Mac ini",
                                    updated: Date(), detail: m.statusLine, symbol: "laptopcomputer"))
        }
        let readings = monitor.readings.values.sorted {
            let a = $0.deviceClass.lowercased().contains("iphone") ? 0 : 1
            let b = $1.deviceClass.lowercased().contains("iphone") ? 0 : 1
            return a != b ? a < b : $0.name < $1.name
        }
        // Sumber iCloud (dari Shortcuts), dikunci per nama perangkat.
        var cloud: [String: ICloudReading] = [:]
        if useICloud {
            for c in ICloudSource.readAll() {
                let key = Store.key(c.name)
                if let old = cloud[key], old.updated > c.updated { continue }
                cloud[key] = c
            }
        }

        for r in readings {
            let isPad = r.deviceClass.lowercased().contains("ipad")
            var item = DeviceItem(id: r.udid, name: r.name, kind: isPad ? "iPad" : "iPhone", level: r.level,
                                  charging: r.charging && r.online, full: r.fullyCharged && r.online,
                                  online: r.online, connection: r.online ? (r.viaWiFi ? "Wi-Fi" : "USB") : "Offline",
                                  updated: r.updated, detail: Store.detail(r), symbol: isPad ? "ipad" : "iphone")
            // USB/Wi-Fi selalu diutamakan. iCloud hanya mengisi saat perangkat tidak terlihat
            // dan datanya lebih baru dari pembacaan terakhir.
            if let c = cloud.removeValue(forKey: Store.key(r.name)), !r.online, c.updated > r.updated {
                item.apply(c)
            }
            items.append(item)
        }
        // Perangkat yang hanya dikenal lewat iCloud (belum pernah dicolok ke Mac ini).
        for c in cloud.values.sorted(by: { $0.name < $1.name }) {
            var item = DeviceItem(id: "icloud:" + Store.key(c.name), name: c.name, kind: c.isPad ? "iPad" : "iPhone",
                                  level: c.level, charging: false, full: false, online: false, connection: "iCloud",
                                  updated: c.updated, detail: "", symbol: c.isPad ? "ipad" : "iphone")
            item.apply(c)
            items.append(item)
        }
        if demoNames {
            items = items.map { var d = $0; d.name = d.isMac ? "MacBook Air" : "\(d.kind) Saya"; return d }
        }
        devices = items
        hasUntrusted = !monitor.untrusted.isEmpty
        for d in items where d.online {
            record(d)
            checkNotifications(d)
        }
        onBarChange?()
    }

    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func detail(_ r: Reading) -> String {
        if !r.online { return "Terakhir terlihat \(Fmt.time(r.updated))" }
        if r.fullyCharged { return "Penuh" }
        if r.charging { return "Mengisi daya" }
        return "Memakai baterai"
    }

    func refresh() {
        isRefreshing = true
        monitor.refreshAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            self.reload()
            self.lastRefresh = Date()
            self.isRefreshing = false
        }
    }

    func forget(_ id: String) {
        monitor.forget(udid: id)
        history[id] = nil
        saveHistory()
        reload()
    }

    // MARK: Riwayat 24 jam

    private func record(_ d: DeviceItem) {
        var arr = history[d.id] ?? []
        if let last = arr.last, last.l == d.level, d.updated.timeIntervalSince(last.t) < 600 { return }
        if let last = arr.last, d.updated <= last.t { return }
        arr.append(Sample(t: d.updated, l: d.level, c: d.charging))
        let cutoff = Date().addingTimeInterval(-86_400)
        arr.removeAll { $0.t < cutoff }
        history[d.id] = arr
        saveHistory()
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: "history.v1") }
    }

    // MARK: Notifikasi

    func askNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func checkNotifications(_ d: DeviceItem) {
        if notifyLow {
            if !d.charging && d.level <= lowThreshold {
                if !notifiedLow.contains(d.id) {
                    notifiedLow.insert(d.id)
                    post(title: "🪫 Baterai \(d.name) tinggal \(d.level)%", body: "Saatnya dicas, ya.")
                }
            } else if d.charging || d.level > lowThreshold + 5 {
                notifiedLow.remove(d.id)
            }
        }
        if notifyFull {
            if d.charging && (d.full || d.level >= 100) {
                if !notifiedFull.contains(d.id) {
                    notifiedFull.insert(d.id)
                    post(title: "🔋 \(d.name) sudah penuh", body: "Charger boleh dicabut.")
                }
            } else if !d.charging {
                notifiedFull.remove(d.id)
            }
        }
    }

    private func post(title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: nil))
    }

    func sendTestNotification() {
        askNotificationPermission()
        post(title: "🔔 Notifikasi BatStats aktif", body: "Kamu akan dikabari saat baterai di bawah \(lowThreshold)%.")
    }
}
