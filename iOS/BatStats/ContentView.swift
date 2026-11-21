// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Layar utama.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var expanded: String? = Store.thisDeviceID
    @State private var showSettings = false
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if let own = store.devices.first(where: { $0.isThisDevice }) {
                        BigRing(device: own, low: store.lowThreshold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }

                    let others = store.devices.filter { !$0.isThisDevice }
                    if !others.isEmpty {
                        // Rata tengah bila muat; bisa digeser bila perangkatnya banyak.
                        ViewThatFits(in: .horizontal) {
                            ringRow(others).frame(maxWidth: .infinity)
                            ScrollView(.horizontal, showsIndicators: false) { ringRow(others) }
                        }
                    }

                    if !store.folderConnected {
                        ConnectCard { showGuide = true }
                    } else if store.folderProblem {
                        Banner(symbol: "exclamationmark.icloud", color: .orange,
                               text: "Folder iCloud tidak bisa dibuka. Pilih ulang foldernya di Pengaturan.")
                    } else if others.isEmpty {
                        Banner(symbol: "hourglass", color: .blue,
                               text: "Folder tersambung. Mac dan iPad akan muncul setelah BatStats di Mac atau pintasan di iPad mengirim datanya.")
                    }

                    VStack(spacing: 8) {
                        ForEach(store.devices) { d in
                            DeviceCard(device: d, history: store.history[d.id] ?? [], low: store.lowThreshold,
                                       expanded: expanded == d.id,
                                       onTap: { toggle(d.id) },
                                       onHide: d.isThisDevice ? nil : { store.hide(d.id) })
                        }
                    }

                    footer
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: expanded)
            }
            .refreshable {
                await Store.shared.refreshAndWait()
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Pengaturan")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store)
            }
            .sheet(isPresented: $showGuide) {
                GuideView().environmentObject(store)
            }
            .onAppear {
                if !store.onboarded {
                    store.onboarded = true
                    showGuide = true
                }
            }
        }
    }

    private func ringRow(_ list: [DeviceItem]) -> some View {
        HStack(spacing: 18) {
            ForEach(list) { d in
                HeroRing(device: d, low: store.lowThreshold, selected: expanded == d.id)
                    .frame(minWidth: 76)
                    .onTapGesture { toggle(d.id) }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private func toggle(_ id: String) {
        expanded = expanded == id ? nil : id
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient(colors: Palette.brand, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(AppInfo.name).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(AppInfo.tagline).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text("\(store.devices.count) perangkat · diperbarui \(Fmt.relative(store.lastRefresh))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.isRefreshing { ProgressView() }
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        HStack {
            Text("\(AppInfo.name) v\(AppInfo.version)")
            Spacer()
            Link(AppInfo.copyright, destination: AppInfo.repo)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.top, 6)
    }
}

struct ConnectCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 26))
                    .foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .topLeading, endPoint: .bottomTrailing))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lihat juga baterai Mac & iPad").font(.subheadline.weight(.semibold))
                    Text("Sambungkan folder iCloud BatStats, cukup sekali.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView().environmentObject(Store.shared)
}
