// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Store: baterai perangkat ini (UIDevice) + perangkat lain dari folder iCloud,
// riwayat 24 jam, dan notifikasi.

import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class Store: ObservableObject {
    static let shared = Store()
    static let thisDeviceID = "this-device"

    /// Data dari pintasan Shortcuts / iPhone lain dianggap aktif selama 3 jam.
    static let freshForShortcut: TimeInterval = 3 * 3600
    /// BatStats di Mac menulis paling lambat tiap 10 menit selama Mac menyala.
    static let freshForMac: TimeInterval = 25 * 60

    private let defaults = UserDefaults.standard

    @Published private(set) var devices: [DeviceItem] = []
    @Published private(set) var history: [String: [Sample]] = [:]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh = Date()
    @Published private(set) var folderConnected = SharedFolder.isConnected
    @Published private(set) var folderProblem = false
    @Published private(set) var lastShared: Date?

    @Published var deviceName: String { didSet { defaults.set(deviceName, forKey: "deviceName"); lastShareSignature = ""; reload() } }
    @Published var lowThreshold: Int { didSet { defaults.set(lowThreshold, forKey: "lowThreshold") } }
    @Published var notifyLow: Bool { didSet { defaults.set(notifyLow, forKey: "notifyLow"); if notifyLow { askNotificationPermission() } } }
    @Published var notifyFull: Bool { didSet { defaults.set(notifyFull, forKey: "notifyFull"); if notifyFull { askNotificationPermission() } } }
    @Published var shareOwnBattery: Bool { didSet { defaults.set(shareOwnBattery, forKey: "shareOwnBattery"); lastShareSignature = ""; reload() } }
    @Published private(set) var hidden: Set<String> { didSet { defaults.set(Array(hidden), forKey: "hidden") } }
    @Published var onboarded: Bool { didSet { defaults.set(onboarded, forKey: "onboarded") } }

    private var remote: [RemoteReading] = []
    private var notifiedLow: Set<String> { didSet { defaults.set(Array(notifiedLow), forKey: "notifiedLow") } }
    private var notifiedFull: Set<String> { didSet { defaults.set(Array(notifiedFull), forKey: "notifiedFull") } }
    private var lastShareSignature = ""
    private var lastShareDate = Date.distantPast
    private var timer: Timer?

    var thisKind: String { UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone" }

    init() {
        let d = UserDefaults.standard
        deviceName = d.string(forKey: "deviceName") ?? UIDevice.current.name
        lowThreshold = d.object(forKey: "lowThreshold") as? Int ?? 20
        notifyLow = d.object(forKey: "notifyLow") as? Bool ?? true
        notifyFull = d.object(forKey: "notifyFull") as? Bool ?? false
        shareOwnBattery = d.object(forKey: "shareOwnBattery") as? Bool ?? true
        hidden = Set(d.stringArray(forKey: "hidden") ?? [])
        onboarded = d.bool(forKey: "onboarded")
        notifiedLow = Set(d.stringArray(forKey: "notifiedLow") ?? [])
        notifiedFull = Set(d.stringArray(forKey: "notifiedFull") ?? [])
        if let data = d.data(forKey: "history.v1"),
           let h = try? JSONDecoder().decode([String: [Sample]].self, from: data) { history = h }

        UIDevice.current.isBatteryMonitoringEnabled = true
        let nc = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange] {
            nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in Store.shared.reload() }
            }
        }
        reload()
    }

    // MARK: Siklus app

    func becameActive() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in Store.shared.refresh() }
        }
    }

    func wentToBackground() {
        timer?.invalidate()
        timer = nil
    }

    /// Dipanggil oleh tugas latar (Background App Refresh).
    func backgroundRefresh() async {
        await readRemote()
        reload()
    }

    // MARK: Data

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            await readRemote()
            try? await Task.sleep(nanoseconds: 400_000_000)
            reload()
            lastRefresh = Date()
            isRefreshing = false
        }
    }

    /// Untuk tarik-untuk-memperbarui: menunggu sampai pembacaan selesai.
    func refreshAndWait() async {
        isRefreshing = true
        await readRemote()
        reload()
        lastRefresh = Date()
        isRefreshing = false
    }

    private func readRemote() async {
        let result = await Task.detached(priority: .utility) { SharedFolder.readAll() }.value
        switch result {
        case .notConnected:
            remote = []; folderConnected = false; folderProblem = false
        case .failed:
            folderConnected = true; folderProblem = true
        case .ok(let list):
            remote = list; folderConnected = true; folderProblem = false
        }
    }

    func reload() {
        var items: [DeviceItem] = [ownDevice()]
        let ownKey = SharedFolder.key(deviceName)

        // Satu entri per nama perangkat: ambil yang paling baru.
        var best: [String: RemoteReading] = [:]
        for r in remote where r.key != ownKey {
            if let old = best[r.key], old.updated >= r.updated { continue }
            best[r.key] = r
        }
        let order = ["Mac": 0, "iPhone": 1, "iPad": 2]
        let sorted = best.values.sorted {
            let a = order[$0.kind] ?? 3, b = order[$1.kind] ?? 3
            return a != b ? a < b : $0.name.localizedCompare($1.name) == .orderedAscending
        }
        for r in sorted {
            items.append(Store.item(from: r))
        }
        devices = items.filter { !hidden.contains($0.id) }

        for d in items where d.online {
            record(d)
            checkNotifications(d)
        }
        shareOwnIfNeeded(items[0])
    }

    private func ownDevice() -> DeviceItem {
        let dev = UIDevice.current
        let raw = dev.batteryLevel        // -1 bila tidak diketahui (mis. Simulator)
        let level = raw < 0 ? 0 : Int((raw * 100).rounded())
        let state = dev.batteryState
        let charging = state == .charging || state == .full
        var detail: String
        switch state {
        case .full: detail = "Penuh · terhubung ke charger"
        case .charging: detail = "Mengisi daya"
        case .unplugged: detail = "Memakai baterai"
        default: detail = "Baterai tidak terbaca"
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { detail += " · Mode Daya Rendah" }
        return DeviceItem(id: Store.thisDeviceID, name: deviceName, kind: thisKind, level: level, charging: charging,
                          full: state == .full, online: raw >= 0, connection: "Perangkat ini", updated: Date(), detail: detail)
    }

    private static func item(from r: RemoteReading) -> DeviceItem {
        let age = Date().timeIntervalSince(r.updated)
        let fresh: Bool
        switch r.source {
        case .mac, .relayed: fresh = age < freshForMac
        case .app, .shortcut: fresh = age < freshForShortcut
        }
        let online = fresh && r.reportedOnline
        let connection = r.source == .relayed ? "Lewat Mac" : "iCloud"
        let state = r.full ? "Penuh" : (r.charging ? "Mengisi daya" : "Memakai baterai")
        let detail: String
        if online {
            if let d = r.detail, r.source == .mac { detail = d }
            else if let d = r.detail { detail = "\(state) · \(d)" }
            else { detail = "\(state) · dikirim \(Fmt.time(r.updated))" }
        } else if r.source == .mac {
            detail = "Mac tidur/mati · terakhir \(Fmt.time(r.updated))"
        } else {
            detail = "Terakhir terlihat \(Fmt.time(r.updated))"
        }
        return DeviceItem(id: "remote:" + r.key, name: r.name, kind: r.kind, level: r.level,
                          charging: r.charging && online, full: r.full && online, online: online,
                          connection: connection, updated: r.updated, detail: detail)
    }

    // MARK: Kirim baterai perangkat ini ke folder (dibaca BatStats di Mac)

    private func shareOwnIfNeeded(_ own: DeviceItem) {
        guard shareOwnBattery, folderConnected, own.online else { return }
        let signature = "\(own.name)|\(own.level)|\(own.charging)|\(own.full)"
        if signature == lastShareSignature, Date().timeIntervalSince(lastShareDate) < 600 { return }
        lastShareSignature = signature
        lastShareDate = Date()
        let model = thisKind
        Task.detached(priority: .utility) {
            let ok = SharedFolder.writeOwn(name: own.name, model: model, level: own.level, charging: own.charging, full: own.full)
            if ok { await MainActor.run { Store.shared.lastShared = Date() } }
        }
    }

    // MARK: Folder

    func connectFolder(_ url: URL) {
        do {
            try SharedFolder.connect(url)
            folderConnected = true
            lastShareSignature = ""
            refresh()
        } catch {
            folderProblem = true
        }
    }

    func disconnectFolder() {
        SharedFolder.disconnect()
        remote = []
        folderConnected = false
        folderProblem = false
        reload()
    }

    // MARK: Sembunyikan

    func hide(_ id: String) {
        hidden.insert(id)
        reload()
    }

    func unhideAll() {
        hidden = []
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
