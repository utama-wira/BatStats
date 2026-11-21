// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Komponen tampilan: cincin baterai, kartu perangkat, grafik 24 jam.

import Charts
import SwiftUI

// MARK: - Cincin besar untuk perangkat ini

struct BigRing: View {
    let device: DeviceItem
    let low: Int
    @State private var shown: Double = 0
    @State private var glow = false

    private var colors: [Color] {
        Palette.gradient(level: device.level, charging: device.charging, online: device.online, low: low)
    }
    private var isLow: Bool { device.online && !device.charging && device.level <= low }

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.07), lineWidth: 16)
            Circle()
                .trim(from: 0, to: shown / 100)
                .stroke(AngularGradient(colors: colors + [colors[0]], center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: isLow ? .red.opacity(glow ? 0.6 : 0.1) : colors[0].opacity(0.25), radius: glow ? 14 : 8)

            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: device.symbol).font(.system(size: 15, weight: .medium))
                    if device.charging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
                            .symbolEffect(.pulse, options: .repeating)
                    }
                }
                .foregroundStyle(.secondary)
                Text(device.online ? "\(device.level)%" : "–")
                    .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: Double(device.level)))
                    .animation(.spring, value: device.level)
                Text(device.full ? "Penuh" : device.charging ? "Mengisi daya" : isLow ? "Baterai lemah" : device.kind + " ini")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(isLow ? Color.red : Color.secondary)
            }
        }
        .frame(width: 200, height: 200)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(device.name), baterai \(device.level) persen\(device.charging ? ", mengisi daya" : "")")
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.8).delay(0.05)) { shown = Double(device.level) }
            if isLow { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { glow = true } }
        }
        .onChange(of: device.level) { _, new in
            withAnimation(.spring(response: 0.8)) { shown = Double(new) }
        }
    }
}

// MARK: - Cincin kecil untuk perangkat lain

struct HeroRing: View {
    let device: DeviceItem
    let low: Int
    let selected: Bool
    @State private var shown: Double = 0
    @State private var glow = false

    private var isLow: Bool { device.online && !device.charging && device.level <= low }

    var body: some View {
        let colors = Palette.gradient(level: device.level, charging: device.charging, online: device.online, low: low)
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Color.primary.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: shown / 100)
                    .stroke(AngularGradient(colors: colors + [colors[0]], center: .center),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: isLow ? .red.opacity(glow ? 0.7 : 0.1) : .clear, radius: glow ? 8 : 2)

                Image(systemName: device.symbol)
                    .font(.system(size: device.kind == "Mac" ? 18 : 20))
                    .foregroundStyle(device.online ? .primary : .secondary)

                Group {
                    if device.charging {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 18))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .green)
                            .symbolEffect(.pulse, options: .repeating)
                    } else if !device.online {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 9, weight: .bold))
                            .padding(4)
                            .background(Circle().fill(.gray.opacity(0.85)))
                            .foregroundStyle(.white)
                    } else if isLow {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .red)
                            .symbolEffect(.pulse, options: .repeating)
                    }
                }
                .offset(x: 24, y: -24)
            }
            .frame(width: 68, height: 68)
            .scaleEffect(selected ? 1.07 : 1)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(device.name), \(device.level) persen")
        .accessibilityAddTraits(.isButton)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.05)) { shown = Double(device.level) }
            if isLow { withAnimation(.easeInOut(duration: 0.9).repeatForever()) { glow = true } }
        }
        .onChange(of: device.level) { _, new in
            withAnimation(.spring(response: 0.8)) { shown = Double(new) }
        }
    }
}

// MARK: - Kartu perangkat

struct DeviceCard: View {
    let device: DeviceItem
    let history: [Sample]
    let low: Int
    let expanded: Bool
    let onTap: () -> Void
    let onHide: (() -> Void)?

    var body: some View {
        let colors = Palette.gradient(level: device.level, charging: device.charging, online: device.online, low: low)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: colors.map { $0.opacity(0.22) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: device.symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(device.online ? .primary : .secondary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(device.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Chip(text: device.connection)
                    }
                    Text(device.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Text("\(device.level)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(device.online ? .primary : .secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    LevelBar(level: device.level, colors: colors)
                    HistoryChart(samples: history,
                                 colors: Palette.gradient(level: device.level, charging: device.charging, online: true, low: low))
                    HStack {
                        if let lo = history.map(\.l).min(), let hi = history.map(\.l).max(), history.count > 1 {
                            Label("Terendah \(lo)%", systemImage: "arrow.down")
                            Label("Tertinggi \(hi)%", systemImage: "arrow.up")
                        }
                        Spacer()
                        Text(device.isThisDevice ? "langsung" : Fmt.relative(device.updated))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: onTap)
        .contextMenu {
            if let onHide {
                Button("Sembunyikan perangkat", systemImage: "eye.slash", role: .destructive, action: onHide)
            }
        }
    }
}

struct LevelBar: View {
    let level: Int
    let colors: [Color]
    @State private var shown: CGFloat = 0

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(g.size.width * shown / 100, 8))
            }
        }
        .frame(height: 8)
        .onAppear { withAnimation(.spring(response: 0.8)) { shown = CGFloat(level) } }
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
            .frame(maxWidth: .infinity, minHeight: 60)
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
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%").font(.system(size: 9)) }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.hour().minute(), centered: false)
                        .font(.system(size: 9))
                }
            }
            .frame(height: 110)
        }
    }
}

// MARK: - Komponen kecil

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
        .fixedSize()
    }
    private var icon: String {
        switch text {
        case "iCloud": return "icloud.fill"
        case "Lewat Mac": return "laptopcomputer"
        default: return "iphone.gen3"
        }
    }
    private var color: Color {
        switch text {
        case "iCloud": return .orange
        case "Lewat Mac": return .blue
        default: return .teal
        }
    }
}

struct Banner: View {
    let symbol: String
    let color: Color
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(text).font(.footnote)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.12)))
    }
}
