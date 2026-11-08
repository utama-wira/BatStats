// BatStats — Battery Status
// Baterai Mac, iPhone & iPad dalam satu ikon di menu bar.
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Panel interaktif yang muncul saat ikon menu bar diklik.

import AppKit
import Charts
import SwiftUI

struct PanelView: View {
    @ObservedObject var store = Store.shared
    @S private var expanded: String?

    init(expandedInitially: String? = nil) {
        _expanded = S(wrappedValue: expandedInitially)
    }
    @S private var showSettings = false
    @S private var showHelp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if store.hasUntrusted {
                Banner(symbol: "lock.iphone", color: .orange,
                       text: "Buka kunci perangkat lalu ketuk \"Percayai\" di layarnya.")
            }

            if store.devices.isEmpty {
                EmptyState()
            } else {
                HStack(spacing: 0) {
                    ForEach(store.devices) { d in
                        HeroRing(device: d, low: store.lowThreshold, selected: expanded == d.id)
                            .frame(maxWidth: .infinity)
                            .onTapGesture { toggle(d.id) }
                    }
                }
                .padding(.vertical, 4)

                VStack(spacing: 6) {
                    ForEach(store.devices) { d in
                        DeviceCard(device: d, history: store.history[d.id] ?? [], low: store.lowThreshold,
                                   expanded: expanded == d.id,
                                   onTap: { toggle(d.id) },
                                   onForget: d.isMac ? nil : { store.forget(d.id) })
                    }
                }
            }

            if showSettings {
                SettingsPanel(showHelp: $showHelp)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack {
                Text("\(AppInfo.name) v\(AppInfo.version)")
                Spacer()
                Text(AppInfo.copyright)
                    .onTapGesture { NSWorkspace.shared.open(URL(string: "https://github.com/utama-wira/BatStats")!) }
                    .onHover { inside in if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
                    .help("Buka halaman GitHub BatStats")
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 360)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expanded)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSettings)
        .alert("Membaca baterai tanpa kabel", isPresented: $showHelp) {
            Button("Oke", role: .cancel) {}
        } message: {
            Text("""
            1. Colok perangkat ke Mac dengan kabel, buka kuncinya, ketuk "Percayai".
            2. Di Finder, klik nama perangkat di sidebar.
            3. Centang "Tampilkan … ini saat di Wi-Fi", lalu klik Terapkan.
            4. Cabut kabel. Selama satu Wi-Fi, BatStats tetap bisa membacanya.
            """)
        }
    }

    private func toggle(_ id: String) {
        expanded = expanded == id ? nil : id
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.85, blue: 0.5), Color(red: 0.1, green: 0.65, blue: 0.9)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(AppInfo.name).font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(AppInfo.tagline).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text("\(store.devices.count) perangkat · diperbarui \(Fmt.relative(store.lastRefresh))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            IconButton(symbol: "arrow.clockwise", help: "Perbarui sekarang", spinning: store.isRefreshing) {
                store.refresh()
            }
            IconButton(symbol: showSettings ? "xmark" : "slider.horizontal.3", help: "Pengaturan") {
                showSettings.toggle()
            }
        }
    }
}

// MARK: - Cincin besar

struct HeroRing: View {
    let device: DeviceItem
    let low: Int
    let selected: Bool
    @S private var shown: Double

    init(device: DeviceItem, low: Int, selected: Bool) {
        self.device = device; self.low = low; self.selected = selected
        _shown = S(wrappedValue: Double(device.level))
    }
    @S private var hover = false
    @S private var glow = false

    private var isLow: Bool { device.online && !device.charging && device.level <= low }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: shown / 100)
                    .stroke(AngularGradient(colors: Palette.gradient(level: device.level, charging: device.charging,
                                                                     online: device.online, low: low) + [Palette.gradient(level: device.level, charging: device.charging, online: device.online, low: low)[0]],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: isLow ? .red.opacity(glow ? 0.7 : 0.1) : .clear, radius: glow ? 8 : 2)

                Image(systemName: device.symbol)
                    .font(.system(size: device.isMac ? 18 : 20, weight: .regular))
                    .foregroundStyle(device.online ? .primary : .secondary)

                if device.charging {
                    Image(systemName: "bolt.circle.fill")
                        .font(.system(size: 17))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .symbolEffect(.pulse, options: .repeating)
                        .offset(x: 23, y: -23)
                } else if !device.online {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                        .background(Circle().fill(.gray.opacity(0.85)))
                        .foregroundStyle(.white)
                        .offset(x: 23, y: -23)
                } else if isLow {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 17))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .symbolEffect(.pulse, options: .repeating)
                        .offset(x: 23, y: -23)
                }
            }
            .frame(width: 68, height: 68)
            .scaleEffect(hover || selected ? 1.07 : 1)

            Text("\(device.level)%")
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(value: Double(device.level)))
                .animation(.spring, value: device.level)
                .foregroundStyle(device.online ? .primary : .secondary)
            Text(device.kind)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.spring(response: 0.3)) { hover = h } }
        .onAppear {
            shown = 0
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.05)) { shown = Double(device.level) }
            if isLow { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { glow = true } }
        }
        .onChange(of: device.level) { _, new in
            withAnimation(.spring(response: 0.8)) { shown = Double(new) }
        }
        .help("\(device.name): \(device.level)%")
    }
}

// MARK: - Kartu perangkat

struct DeviceCard: View {
    let device: DeviceItem
    let history: [Sample]
    let low: Int
    let expanded: Bool
    let onTap: () -> Void
    let onForget: (() -> Void)?
    @S private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(LinearGradient(colors: Palette.gradient(level: device.level, charging: device.charging,
                                                                      online: device.online, low: low).map { $0.opacity(0.22) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: device.symbol)
                        .font(.system(size: 14))
                        .foregroundStyle(device.online ? .primary : .secondary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(device.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Chip(text: device.connection)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    LevelBar(level: device.level, colors: Palette.gradient(level: device.level, charging: device.charging,
                                                                          online: device.online, low: low))
                    HistoryChart(samples: history, colors: Palette.gradient(level: device.level, charging: device.charging,
                                                                            online: true, low: low))
                    HStack {
                        if let lo = history.map(\.l).min(), let hi = history.map(\.l).max(), history.count > 1 {
                            Label("Terendah \(lo)%", systemImage: "arrow.down")
                            Label("Tertinggi \(hi)%", systemImage: "arrow.up")
                        }
                        Spacer()
                        Text(device.isMac ? "langsung" : Fmt.relative(device.updated))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if let onForget {
                        Button(role: .destructive, action: onForget) {
                            Label("Lupakan perangkat ini", systemImage: "trash")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(hover || expanded ? 0.08 : 0.04))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .contextMenu {
            if let onForget { Button("Lupakan perangkat", role: .destructive, action: onForget) }
        }
    }
}

struct LevelBar: View {
    let level: Int
    let colors: [Color]
    @S private var shown: CGFloat

    init(level: Int, colors: [Color]) {
        self.level = level; self.colors = colors
        _shown = S(wrappedValue: CGFloat(level))
    }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(g.size.width * shown / 100, 6))
            }
        }
        .frame(height: 8)
        .onAppear { shown = 0; withAnimation(.spring(response: 0.8)) { shown = CGFloat(level) } }
        .onChange(of: level) { _, n in withAnimation(.spring) { shown = CGFloat(n) } }
    }
}

struct HistoryChart: View {
    let samples: [Sample]
    let colors: [Color]

    var body: some View {
        if samples.count < 2 {
            HStack(spacing: 6) {
                Image(systemName: "chart.xyaxis.line")
                Text("Grafik 24 jam akan muncul setelah beberapa pembacaan.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 50)
        } else {
            Chart(samples) { s in
                AreaMark(x: .value("Waktu", s.t), y: .value("Baterai", s.l))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [colors[0].opacity(0.35), colors[0].opacity(0.02)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Waktu", s.t), y: .value("Baterai", s.l))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(colors[0])
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { v in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%").font(.system(size: 8)) }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute(), centered: false)
                        .font(.system(size: 8))
                }
            }
            .frame(height: 80)
        }
    }
}

// MARK: - Pengaturan

struct SettingsPanel: View {
    @ObservedObject var store = Store.shared
    @Binding var showHelp: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pengaturan").font(.system(size: 13, weight: .bold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Gaya ikon di menu bar").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(BarStyle.allCases) { s in
                        StyleOption(style: s, selected: store.barStyle == s) { store.barStyle = s }
                    }
                }
            }

            Toggle("Tampilkan persen di menu bar", isOn: $store.showPercent)
            Toggle("Peringatan baterai lemah", isOn: $store.notifyLow)
            if store.notifyLow {
                HStack {
                    Text("Ingatkan saat di bawah").foregroundStyle(.secondary)
                    Spacer()
                    Stepper("\(store.lowThreshold)%", value: $store.lowThreshold, in: 5...50, step: 5)
                        .monospacedDigit()
                }
                .font(.caption)
            }
            Toggle("Kabari saat baterai penuh", isOn: $store.notifyFull)
            Toggle("Buka otomatis saat login", isOn: $store.launchAtLogin)

            HStack {
                Button("Tes notifikasi") { store.sendTestNotification() }
                Button("Cara pakai Wi-Fi") { showHelp = true }
                Spacer()
                Button("Keluar") { NSApp.terminate(nil) }
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.system(size: 12))
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.05)))
    }
}

struct StyleOption: View {
    let style: BarStyle
    let selected: Bool
    let action: () -> Void
    @S private var hover = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                preview.frame(height: 18)
                Text(style.label).font(.caption2.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(hover ? 0.08 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(selected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    @ViewBuilder private var preview: some View {
        switch style {
        case .ring:
            ZStack {
                Circle().stroke(Color.primary.opacity(0.15), lineWidth: 2)
                Circle().trim(from: 0, to: 0.7).stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "iphone").font(.system(size: 7, weight: .semibold))
            }
            .frame(width: 17, height: 17)
        case .battery:
            HStack(spacing: 3) {
                Image(systemName: "iphone").font(.system(size: 11))
                Image(systemName: "battery.75percent").font(.system(size: 14))
            }
        case .text:
            HStack(spacing: 2) {
                Image(systemName: "iphone").font(.system(size: 11))
                Text("75%").font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
        }
    }
}

// MARK: - Komponen kecil

struct IconButton: View {
    let symbol: String
    let help: String
    var spinning = false
    let action: () -> Void
    @S private var hover = false
    @S private var angle: Double = 0

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .rotationEffect(.degrees(angle))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(hover ? 0.12 : 0.06)))
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .onChange(of: spinning) { _, s in
            if s { withAnimation(.linear(duration: 0.7).repeatForever(autoreverses: false)) { angle = 360 } }
            else { withAnimation(.default) { angle = 0 } }
        }
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 8, weight: .bold))
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
    }
    private var icon: String {
        switch text {
        case "Wi-Fi": return "wifi"
        case "USB": return "cable.connector"
        case "Offline": return "moon.zzz.fill"
        default: return "desktopcomputer"
        }
    }
    private var color: Color {
        switch text {
        case "Wi-Fi": return .blue
        case "USB": return .purple
        case "Offline": return .gray
        default: return .teal
        }
    }
}

struct Banner: View {
    let symbol: String
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(.caption)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)))
    }
}

struct EmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
                .symbolEffect(.variableColor.iterative, options: .repeating)
            Text("Belum ada perangkat").font(.headline)
            Text("Colok iPhone atau iPad sekali dengan kabel, lalu ketuk \"Percayai\".")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// Pengganti @State: Command Line Tools di Mac ini tidak menyertakan plugin macro SwiftUI.
@propertyWrapper
struct S<T>: DynamicProperty {
    private let state: State<T>
    init(wrappedValue: T) { state = State(initialValue: wrappedValue) }
    var wrappedValue: T {
        get { state.wrappedValue }
        nonmutating set { state.wrappedValue = newValue }
    }
    var projectedValue: Binding<T> { state.projectedValue }
}
