// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Folder bersama di iCloud Drive › Shortcuts › BatStats.
// iOS tidak mengizinkan app membaca baterai perangkat lain, jadi Mac dan iPad
// menitipkan angkanya di folder ini:
//   - "Mac - <nama>.json"  ditulis BatStats di Mac (baterai Mac + perangkat USB/Wi-Fi-nya)
//   - "<nama>.json"        ditulis pintasan Shortcuts atau BatStats di iPhone/iPad lain
// Pengguna memilih folder ini sekali lewat app File; aksesnya disimpan sebagai bookmark,
// jadi tidak butuh akun Apple Developer berbayar atau entitlement iCloud.

import Foundation

struct RemoteReading {
    enum Source { case mac, app, shortcut, relayed }

    var name: String
    var kind: String
    var level: Int
    var charging: Bool
    var full: Bool
    var updated: Date
    var detail: String?
    var source: Source
    var via: String?        // nama Mac untuk perangkat yang diteruskan Mac
    var reportedOnline = true

    var key: String { SharedFolder.key(name) }
}

enum SharedFolder {
    private static let bookmarkKey = "folderBookmark.v1"
    static let folderName = "BatStats"

    static var isConnected: Bool { UserDefaults.standard.data(forKey: bookmarkKey) != nil }

    static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: Bookmark

    /// Menyimpan folder pilihan pengguna. Boleh memilih folder "BatStats" atau folder induknya ("Shortcuts").
    static func connect(_ picked: URL) throws {
        let ok = picked.startAccessingSecurityScopedResource()
        defer { if ok { picked.stopAccessingSecurityScopedResource() } }
        let data = try picked.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func disconnect() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    static var displayPath: String? {
        guard let root = resolveRoot() else { return nil }
        let dir = dataDir(for: root)
        let parts = dir.pathComponents.suffix(2)
        return parts.joined(separator: " › ")
    }

    private static func resolveRoot() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale {
            let ok = url.startAccessingSecurityScopedResource()
            if let fresh = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: bookmarkKey)
            }
            if ok { url.stopAccessingSecurityScopedResource() }
        }
        return url
    }

    private static func dataDir(for root: URL) -> URL {
        root.lastPathComponent.caseInsensitiveCompare(folderName) == .orderedSame
            ? root : root.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Menjalankan `body` dengan akses ke folder data. Mengembalikan nil bila folder belum dipilih / tidak bisa dibuka.
    private static func withFolder<T>(_ body: (URL) throws -> T) -> T? {
        guard let root = resolveRoot() else { return nil }
        let ok = root.startAccessingSecurityScopedResource()
        defer { if ok { root.stopAccessingSecurityScopedResource() } }
        let dir = dataDir(for: root)
        if dir != root, !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return try? body(dir)
    }

    // MARK: Baca

    enum ReadResult {
        case notConnected
        case failed
        case ok([RemoteReading])
    }

    static func readAll() -> ReadResult {
        guard isConnected else { return .notConnected }
        let result: [RemoteReading]? = withFolder { dir in
            let fm = FileManager.default
            var coordError: NSError?
            var files: [URL] = []
            NSFileCoordinator().coordinate(readingItemAt: dir, options: [], error: &coordError) { u in
                files = (try? fm.contentsOfDirectory(at: u,
                    includingPropertiesForKeys: [.contentModificationDateKey, .ubiquitousItemDownloadingStatusKey],
                    options: [])) ?? []
            }
            var out: [RemoteReading] = []
            for url in files {
                let fileName = url.lastPathComponent
                // File yang belum diunduh dari iCloud: ".nama.json.icloud" → minta diunduh, baca lain kali.
                if fileName.hasPrefix("."), fileName.hasSuffix(".icloud") {
                    try? fm.startDownloadingUbiquitousItem(at: url)
                    continue
                }
                guard ["json", "txt"].contains(url.pathExtension.lowercased()) else { continue }
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .ubiquitousItemDownloadingStatusKey])
                // Minta versi terbaru dari iCloud; sementara itu pakai salinan lokal yang ada.
                if let status = values?.ubiquitousItemDownloadingStatus, status != .current {
                    try? fm.startDownloadingUbiquitousItem(at: url)
                }
                guard let data = try? Data(contentsOf: url) else { continue }
                let modified = values?.contentModificationDate ?? Date()
                out.append(contentsOf: parse(data, fallbackName: url.deletingPathExtension().lastPathComponent, modified: modified))
            }
            return out
        }
        return result.map { .ok($0) } ?? .failed
    }

    /// Membaca satu file. Mendukung tiga bentuk:
    /// 1. File Mac: {"source":"BatStats-Mac", "name", "level", ..., "devices":[...]}
    /// 2. Kamus Shortcuts / BatStats iOS: {"name","level","charging","model"}
    /// 3. Teks polos berisi angka saja, mis. "85"
    static func parse(_ data: Data, fallbackName: String, modified: Date) -> [RemoteReading] {
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
        func percent(_ v: Any?) -> Int? {
            guard var l = number(v) else { return nil }
            if l > 0, l <= 1 { l *= 100 }   // beberapa versi iOS memberi 0.85, bukan 85
            return max(0, min(100, Int(l.rounded())))
        }
        func date(_ v: Any?) -> Date? {
            guard let t = number(v), t > 1_000_000_000 else { return nil }
            return Date(timeIntervalSince1970: t)
        }
        func kind(model: String, name: String) -> String {
            let s = (model + " " + name).lowercased()
            if s.contains("ipad") { return "iPad" }
            if s.contains("mac") { return "Mac" }
            return "iPhone"
        }

        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Teks polos berisi angka.
            guard let text = String(data: data, encoding: .utf8),
                  let l = percent(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return [] }
            return [RemoteReading(name: fallbackName, kind: kind(model: "", name: fallbackName), level: l, charging: false,
                                  full: false, updated: modified, detail: nil, source: .shortcut)]
        }

        let name = (obj["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
        guard let level = percent(obj["level"]) else { return [] }
        let charging = bool(obj["charging"])
        let updated = date(obj["updated"]) ?? modified
        let model = (obj["model"] as? String) ?? ""

        if (obj["source"] as? String) == "BatStats-Mac" {
            var out = [RemoteReading(name: name, kind: "Mac", level: level, charging: charging, full: bool(obj["full"]),
                                     updated: updated, detail: obj["detail"] as? String, source: .mac)]
            for d in (obj["devices"] as? [[String: Any]]) ?? [] {
                guard let dn = d["name"] as? String, let dl = percent(d["level"]) else { continue }
                let dk = (d["kind"] as? String) ?? kind(model: "", name: dn)
                out.append(RemoteReading(name: dn, kind: dk, level: dl, charging: bool(d["charging"]), full: bool(d["full"]),
                                         updated: date(d["updated"]) ?? updated,
                                         detail: (d["connection"] as? String).map { "Terbaca Mac lewat \($0)" },
                                         source: .relayed, via: name))
            }
            return out
        }

        let source: RemoteReading.Source = (obj["source"] as? String) == "BatStats-iOS" ? .app : .shortcut
        return [RemoteReading(name: name, kind: kind(model: model, name: name), level: level, charging: charging,
                              full: bool(obj["full"]) || (charging && level >= 100), updated: updated,
                              detail: nil, source: source)]
    }

    // MARK: Tulis baterai perangkat ini

    /// Menulis "<nama>.json" dengan format yang sama seperti pintasan Shortcuts,
    /// jadi BatStats di Mac langsung bisa membacanya.
    @discardableResult
    static func writeOwn(name: String, model: String, level: Int, charging: Bool, full: Bool) -> Bool {
        let payload: [String: Any] = [
            "source": "BatStats-iOS",
            "name": name,
            "model": model,
            "level": level,
            "charging": charging,
            "full": full,
            "updated": Date().timeIntervalSince1970,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else { return false }
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
        let ok: Bool? = withFolder { dir in
            let url = dir.appendingPathComponent("\(safe).json")
            var coordError: NSError?
            var written = false
            NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { u in
                written = (try? data.write(to: u, options: .atomic)) != nil
            }
            return written
        }
        return ok ?? false
    }
}
