// BatStats — Battery Status
// Baterai Mac, iPhone & iPad dalam satu ikon di menu bar.
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Titik masuk aplikasi.

import AppKit
import IOKit.ps
import SwiftUI
import UserNotifications

Migration.run()

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let store = Store.shared
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePanel)
            button.target = self
            button.imagePosition = .imageOnly
        }

        let host = NSHostingController(rootView: PanelView())
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient
        popover.animates = true

        UNUserNotificationCenter.current().delegate = self
        if store.notifyLow || store.notifyFull { store.askNotificationPermission() }

        store.onBarChange = { [weak self] in self?.updateIcon() }
        store.monitor.onChange = { Store.shared.reload() }
        store.monitor.start()

        // Status daya Mac berubah → perbarui seketika.
        let psCallback: IOPowerSourceCallbackType = { _ in
            DispatchQueue.main.async { Store.shared.reload() }
        }
        if let src = IOPSNotificationCreateRunLoopSource(psCallback, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), src, .defaultMode)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Store.shared.refresh()
        }
        store.reload()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        button.image = StatusIcon.make(devices: store.devices, style: store.barStyle,
                                       showPercent: store.showPercent, low: store.lowThreshold)
        button.toolTip = store.devices.map { "\($0.name): \($0.level)%" }.joined(separator: "\n")
    }

    @objc private func togglePanel() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.refresh()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // Tampilkan notifikasi walau app sedang aktif.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// Mode pratinjau: `BatStats --snapshot <folder>` menyimpan gambar panel & ikon (untuk dicek).
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1])
    _ = NSApplication.shared
    let store = Store.shared
    store.demoNames = CommandLine.arguments.contains("--demo")
    store.monitor.start()
    RunLoop.main.run(until: Date().addingTimeInterval(6))
    store.reload()
    func save(_ img: NSImage?, _ name: String) {
        guard let img, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent(name))
    }
    for dark in [false, true] {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
        appearance.performAsCurrentDrawingAppearance {
            for style in BarStyle.allCases {
                let icon = StatusIcon.make(devices: store.devices, style: style, showPercent: true, low: store.lowThreshold)
                let big = NSImage(size: NSSize(width: icon.size.width * 3 + 24, height: icon.size.height * 3 + 12), flipped: false) { r in
                    (dark ? NSColor(white: 0.15, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill(); r.fill()
                    icon.draw(in: NSRect(x: 12, y: 6, width: icon.size.width * 3, height: icon.size.height * 3))
                    return true
                }
                save(NSImage(data: big.tiffRepresentation!), "icon-\(style.rawValue)-\(dark ? "dark" : "light").png")
            }
        }
        let view = PanelView(expandedInitially: store.devices.first?.id)
            .background(dark ? Color(white: 0.16) : Color(white: 0.97))
            .environment(\.colorScheme, dark ? .dark : .light)
        MainActor.assumeIsolated {
            let r = ImageRenderer(content: view)
            r.scale = 2
            save(r.nsImage, "panel-\(dark ? "dark" : "light").png")
        }
    }
    print("Tersimpan di \(dir.path)")
    exit(0)
}

// Mode uji dari terminal: `BatStats --dump`
if CommandLine.arguments.contains("--dump") {
    let m = DeviceMonitor.shared
    if let mac = MacBattery.read() { print("Mac: \(mac.level)% — \(mac.statusLine)") }
    for c in ICloudSource.readAll() {
        print("iCloud \"\(c.name)\": \(c.level)% charging=\(c.charging) iPad=\(c.isPad) dikirim \(Fmt.time(c.updated))")
    }
    m.onChange = {
        for r in m.readings.values where r.online {
            print("\(r.deviceClass) \"\(r.name)\": \(r.level)% charging=\(r.charging) wifi=\(r.viaWiFi)")
        }
    }
    m.start()
    print("Mencari perangkat selama 8 detik…")
    RunLoop.main.run(until: Date().addingTimeInterval(8))
    if m.readings.values.filter({ $0.online }).isEmpty { print("Tidak ada perangkat terbaca.") }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
