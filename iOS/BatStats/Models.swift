// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Model data, format waktu, dan warna. Sama dengan versi Mac supaya tampilannya seragam.

import SwiftUI

struct Sample: Codable, Identifiable {
    var t: Date
    var l: Int
    var c: Bool
    var id: Date { t }
}

struct DeviceItem: Identifiable, Equatable {
    var id: String
    var name: String
    var kind: String        // Mac, iPhone, iPad
    var level: Int
    var charging: Bool
    var full: Bool
    var online: Bool        // false = angka lama, tampil abu-abu
    var connection: String  // "Perangkat ini", "iCloud", "Lewat Mac"
    var updated: Date
    var detail: String
    var isThisDevice: Bool { id == Store.thisDeviceID }

    var symbol: String {
        switch kind {
        case "Mac": return "laptopcomputer"
        case "iPad": return "ipad"
        default: return "iphone"
        }
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

enum Palette {
    static func gradient(level: Int, charging: Bool, online: Bool, low: Int) -> [Color] {
        if !online { return [.gray.opacity(0.5), .gray.opacity(0.35)] }
        if charging { return [Color(red: 0.20, green: 0.85, blue: 0.45), Color(red: 0.10, green: 0.75, blue: 0.85)] }
        if level <= low { return [Color(red: 1.0, green: 0.25, blue: 0.30), Color(red: 1.0, green: 0.55, blue: 0.20)] }
        if level <= 50 { return [Color(red: 1.0, green: 0.70, blue: 0.10), Color(red: 1.0, green: 0.85, blue: 0.30)] }
        return [Color(red: 0.25, green: 0.80, blue: 0.50), Color(red: 0.40, green: 0.90, blue: 0.40)]
    }

    static let brand = [Color(red: 0.2, green: 0.85, blue: 0.5), Color(red: 0.1, green: 0.65, blue: 0.9)]
}

enum AppInfo {
    static let name = "BatStats"
    static let tagline = "Battery Status"
    static let copyright = "© 2026 @utama_wira"
    static let repo = URL(string: "https://github.com/utama-wira/BatStats")!
    static let guide = URL(string: "https://github.com/utama-wira/BatStats/blob/main/docs/IPHONE.md")!
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
