// BatStats — Battery Status
// Baterai Mac, iPhone & iPad dalam satu ikon di menu bar.
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Ikon menu bar yang digambar sendiri: gaya Cincin, Baterai, atau Angka.

import AppKit

enum StatusIcon {
    static let height: CGFloat = 22
    static let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)

    private struct Segment {
        var width: CGFloat
        var draw: (CGFloat) -> Void   // menerima posisi x
    }

    static func make(devices: [DeviceItem], style: BarStyle, showPercent: Bool, low: Int) -> NSImage {
        var segments: [Segment] = []
        if devices.isEmpty {
            segments.append(symbolSegment("iphone.slash", size: 13, color: .secondaryLabelColor))
        }
        for d in devices {
            switch style {
            case .ring: segments += ringSegments(d, showPercent: showPercent, low: low)
            case .battery: segments += batterySegments(d, showPercent: showPercent, low: low)
            case .text: segments += textSegments(d, low: low)
            }
            segments.append(Segment(width: 9, draw: { _ in }))
        }
        if !devices.isEmpty { segments.removeLast() }

        let width = ceil(segments.reduce(0) { $0 + $1.width })
        let image = NSImage(size: NSSize(width: max(width, 1), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for s in segments { s.draw(x); x += s.width }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: Gaya cincin — ikon perangkat di dalam lingkaran progres

    private static func ringSegments(_ d: DeviceItem, showPercent: Bool, low: Int) -> [Segment] {
        let size: CGFloat = 18
        let color = { Palette.ns(level: d.level, charging: d.charging, online: d.online, low: low) }
        var segs = [Segment(width: size) { x in
            let rect = NSRect(x: x + 1, y: (height - size) / 2 + 1, width: size - 2, height: size - 2)
            let track = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            track.lineWidth = 2
            NSColor.labelColor.withAlphaComponent(0.18).setStroke()
            track.stroke()

            let center = NSPoint(x: rect.midX, y: rect.midY)
            let arc = NSBezierPath()
            let end = 90 - 360 * CGFloat(max(d.level, 2)) / 100
            arc.appendArc(withCenter: center, radius: rect.width / 2 - 1, startAngle: 90, endAngle: end, clockwise: true)
            arc.lineWidth = 2.2
            arc.lineCapStyle = .round
            color().setStroke()
            arc.stroke()

            let inner = d.charging ? "bolt.fill" : d.symbol
            let innerColor: NSColor = d.charging ? .systemGreen : (d.online ? .labelColor : .secondaryLabelColor)
            drawSymbol(inner, pointSize: d.symbol == "laptopcomputer" && !d.charging ? 6.5 : 7.5,
                       color: innerColor, centeredIn: rect)
        }]
        if showPercent { segs.append(textSegment(" \(d.level)%", color: color)) }
        return segs
    }

    // MARK: Gaya baterai — ikon perangkat + baterai mini terisi

    private static func batterySegments(_ d: DeviceItem, showPercent: Bool, low: Int) -> [Segment] {
        let color = { Palette.ns(level: d.level, charging: d.charging, online: d.online, low: low) }
        let deviceColor: NSColor = d.online ? .labelColor : .secondaryLabelColor
        var segs = [symbolSegment(d.symbol, size: d.symbol == "laptopcomputer" ? 11 : 12, color: deviceColor),
                    Segment(width: 3, draw: { _ in })]
        let bw: CGFloat = 24, bh: CGFloat = 11
        segs.append(Segment(width: bw + 3) { x in
            let body = NSRect(x: x + 0.5, y: (height - bh) / 2, width: bw, height: bh)
            let outline = NSBezierPath(roundedRect: body, xRadius: 3, yRadius: 3)
            outline.lineWidth = 1
            NSColor.labelColor.withAlphaComponent(d.online ? 0.45 : 0.25).setStroke()
            outline.stroke()

            let nub = NSRect(x: body.maxX + 1, y: body.midY - 2, width: 1.6, height: 4)
            NSColor.labelColor.withAlphaComponent(d.online ? 0.45 : 0.25).setFill()
            NSBezierPath(roundedRect: nub, xRadius: 0.8, yRadius: 0.8).fill()

            let inner = body.insetBy(dx: 2, dy: 2)
            let fill = NSRect(x: inner.minX, y: inner.minY,
                              width: max(inner.width * CGFloat(d.level) / 100, 1.5), height: inner.height)
            color().setFill()
            NSBezierPath(roundedRect: fill, xRadius: 1.5, yRadius: 1.5).fill()

            if d.charging {
                drawSymbol("bolt.fill", pointSize: 8, color: .labelColor, centeredIn: body)
            }
        })
        if showPercent { segs.append(textSegment(" \(d.level)%", color: color)) }
        return segs
    }

    // MARK: Gaya angka — ringkas

    private static func textSegments(_ d: DeviceItem, low: Int) -> [Segment] {
        let color = { Palette.ns(level: d.level, charging: d.charging, online: d.online, low: low) }
        let deviceColor: NSColor = d.online ? .labelColor : .secondaryLabelColor
        var segs = [symbolSegment(d.symbol, size: d.symbol == "laptopcomputer" ? 11 : 12, color: deviceColor),
                    textSegment(" \(d.level)%", color: color)]
        if d.charging { segs.append(symbolSegment("bolt.fill", size: 8, color: .systemGreen)) }
        return segs
    }

    // MARK: Bantuan gambar

    private static func textSegment(_ s: String, color: @escaping () -> NSColor) -> Segment {
        let w = (s as NSString).size(withAttributes: [.font: font]).width
        return Segment(width: ceil(w)) { x in
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color()]
            let size = (s as NSString).size(withAttributes: attrs)
            (s as NSString).draw(at: NSPoint(x: x, y: (height - size.height) / 2), withAttributes: attrs)
        }
    }

    private static func symbolSegment(_ name: String, size: CGFloat, color: NSColor) -> Segment {
        let img = symbol(name, pointSize: size, color: color)
        let w = img?.size.width ?? size
        return Segment(width: ceil(w)) { x in
            guard let img = symbol(name, pointSize: size, color: color) else { return }
            img.draw(in: NSRect(x: x, y: (height - img.size.height) / 2, width: img.size.width, height: img.size.height))
        }
    }

    private static func symbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            .applying(.init(paletteColors: [color]))
            .applying(.preferringMonochrome())
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
    }

    private static func drawSymbol(_ name: String, pointSize: CGFloat, color: NSColor, centeredIn rect: NSRect) {
        guard let img = symbol(name, pointSize: pointSize, color: color) else { return }
        let s = img.size
        img.draw(in: NSRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
    }
}
