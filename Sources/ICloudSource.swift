// BatStats — Battery Status
// Baterai Mac, iPhone & iPad dalam satu ikon di menu bar.
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Sumber iCloud: iPhone/iPad menulis baterainya lewat Shortcuts ke
// iCloud Drive › Shortcuts › BatStats › <nama perangkat>.json
// Dipakai sebagai cadangan saat perangkat tidak terlihat lewat USB/Wi-Fi.

import Foundation

struct ICloudReading {
    var name: String
    var level: Int
    var charging: Bool
    var isPad: Bool
    var updated: Date
}

enum ICloudSource {
    /// iCloud Drive › Shortcuts › BatStats
    static var folder: URL {
        if let override = ProcessInfo.processInfo.environment["BATSTATS_ICLOUD_DIR"] {   // untuk pengujian
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/iCloud~is~workflow~my~workflows/Documents/BatStats")
    }

    static var isICloudDriveAvailable: Bool {
        FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path)
    }

    static func ensureFolder() {
        guard isICloudDriveAvailable else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    static func readAll() -> [ICloudReading] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
                                                      options: []) else { return [] }
        var out: [ICloudReading] = []
        for url in files {
            let fileName = url.lastPathComponent
            // File yang belum diunduh dari iCloud berbentuk ".nama.json.icloud" — minta diunduh.
            if fileName.hasPrefix("."), fileName.hasSuffix(".icloud") {
                try? fm.startDownloadingUbiquitousItem(at: url)
                continue
            }
            guard ["json", "txt"].contains(url.pathExtension.lowercased()),
                  let data = try? Data(contentsOf: url) else { continue }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
            let baseName = url.deletingPathExtension().lastPathComponent
            if let r = parse(data, fallbackName: baseName, modified: modified) { out.append(r) }
        }
        return out
    }

    /// Menerima JSON dari Kamus Shortcuts ({"name","level","charging","model"})
    /// atau teks polos berisi angka saja (mis. "85").
    static func parse(_ data: Data, fallbackName: String, modified: Date) -> ICloudReading? {
        func number(_ v: Any?) -> Double? {
            if let n = v as? NSNumber { return n.doubleValue }
            if let s = v as? String {
                return Double(s.replacingOccurrences(of: ",", with: ".").filter { "0123456789.".contains($0) })
            }
            return nil
        }
        func bool(_ v: Any?) -> Bool {
            if let b = v as? Bool { return b }
            if let n = v as? NSNumber { return n.boolValue }
            if let s = (v as? String)?.lowercased() { return ["1", "true", "yes", "ya", "benar"].contains(s) }
            return false
        }

        var name = fallbackName
        var level: Double?
        var charging = false
        var model = ""

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            name = (obj["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
            level = number(obj["level"])
            charging = bool(obj["charging"])
            model = (obj["model"] as? String) ?? ""
        } else if let text = String(data: data, encoding: .utf8) {
            level = number(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard var l = level else { return nil }
        if l > 0, l <= 1 { l *= 100 }   // beberapa versi iOS memberi 0.85, bukan 85
        let isPad = (model + " " + name).lowercased().contains("ipad")
        return ICloudReading(name: name, level: Int(l.rounded()), charging: charging, isPad: isPad, updated: modified)
    }
}
