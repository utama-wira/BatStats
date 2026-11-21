// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Pengaturan dan panduan menyambungkan folder iCloud.

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var showGuide = false
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nama perangkat", text: $nameDraft)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(saveName)
                } header: {
                    Text("Nama \(store.thisKind) ini")
                } footer: {
                    Text("Samakan persis dengan Pengaturan › Umum › Mengenai › Nama. Nama ini dipakai supaya Mac mengenali \(store.thisKind) ini dan tidak muncul ganda.")
                }

                Section {
                    if store.folderConnected {
                        LabeledContent("Folder", value: SharedFolder.displayPath ?? "Tersambung")
                        Toggle("Kirim baterai \(store.thisKind) ini", isOn: $store.shareOwnBattery)
                        if let t = store.lastShared {
                            LabeledContent("Terakhir dikirim", value: Fmt.time(t))
                        }
                        Button("Pilih folder lain") { picking = true }
                        Button("Putuskan folder", role: .destructive) { store.disconnectFolder() }
                    } else {
                        Button {
                            showGuide = true
                        } label: {
                            Label("Sambungkan folder iCloud", systemImage: "folder.badge.plus")
                        }
                    }
                } header: {
                    Text("Mac & iPad lewat iCloud")
                } footer: {
                    Text("Folder: iCloud Drive › Shortcuts › BatStats. BatStats di Mac (versi 2.3 ke atas) dan pintasan Shortcuts di iPad menitipkan baterainya di sini.")
                }

                Section("Notifikasi") {
                    Toggle("Peringatan baterai lemah", isOn: $store.notifyLow)
                    if store.notifyLow {
                        Stepper("Ingatkan di bawah \(store.lowThreshold)%", value: $store.lowThreshold, in: 5...50, step: 5)
                    }
                    Toggle("Kabari saat baterai penuh", isOn: $store.notifyFull)
                    Button("Tes notifikasi") { store.sendTestNotification() }
                }

                if !store.hidden.isEmpty {
                    Section {
                        Button("Tampilkan lagi perangkat tersembunyi") { store.unhideAll() }
                    }
                }

                Section("Tentang") {
                    LabeledContent("Versi", value: AppInfo.version)
                    Link("Panduan lengkap", destination: AppInfo.guide)
                    Link("BatStats di GitHub", destination: AppInfo.repo)
                }
            }
            .navigationTitle("Pengaturan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { saveName(); dismiss() }
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { store.connectFolder(url) }
            }
            .sheet(isPresented: $showGuide) {
                GuideView().environmentObject(store)
            }
            .onAppear { nameDraft = store.deviceName }
        }
    }

    private func saveName() {
        let n = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty, n != store.deviceName { store.deviceName = n }
    }
}

// MARK: - Panduan menyambungkan

struct GuideView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "laptopcomputer.and.iphone")
                            .font(.system(size: 40))
                            .foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("Semua baterai di satu layar").font(.title2.bold())
                        Text("Baterai \(store.thisKind) ini langsung terbaca. Untuk Mac dan iPad, BatStats memakai folder kecil di iCloud Drive milikmu sendiri. Tidak ada server, tidak ada data yang dikirim ke pihak lain.")
                            .foregroundStyle(.secondary)
                    }

                    Step(number: 1, title: "Nama \(store.thisKind) ini") {
                        Text("Samakan dengan Pengaturan › Umum › Mengenai › Nama.")
                        TextField("Nama perangkat", text: $nameDraft)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onSubmit(saveName)
                    }

                    Step(number: 2, title: "Perbarui BatStats di Mac") {
                        Text("Pasang BatStats versi 2.3 ke atas di Mac dan pastikan **Sumber iCloud** menyala (panel › ⚙︎). Mac akan menulis baterainya, plus iPad yang terbaca lewat kabel/Wi-Fi, ke folder BatStats.")
                    }

                    Step(number: 3, title: "Pilih folder BatStats") {
                        Text("Ketuk tombol di bawah, lalu buka **iCloud Drive › Shortcuts › BatStats** dan ketuk **Buka**. Kalau folder BatStats belum ada, pilih folder **Shortcuts** saja.")
                        Button {
                            saveName()
                            picking = true
                        } label: {
                            Label(store.folderConnected ? "Pilih ulang folder" : "Pilih folder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        if store.folderConnected {
                            Label("Tersambung: \(SharedFolder.displayPath ?? "BatStats")", systemImage: "checkmark.circle.fill")
                                .font(.footnote)
                                .foregroundStyle(.green)
                        }
                    }

                    Step(number: 4, title: "iPad (opsional)") {
                        Text("Pasang BatStats juga di iPad, atau pakai pintasan Shortcuts dari panduan BatStats. Keduanya menulis ke folder yang sama.")
                    }
                }
                .padding(20)
            }
            .navigationTitle("Sambungkan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.folderConnected ? "Selesai" : "Nanti") { saveName(); dismiss() }
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result { store.connectFolder(url) }
            }
            .onAppear { nameDraft = store.deviceName }
        }
    }

    private func saveName() {
        let n = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty, n != store.deviceName { store.deviceName = n }
    }
}

struct Step<Content: View>: View {
    let number: Int
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(LinearGradient(colors: Palette.brand, startPoint: .topLeading, endPoint: .bottomTrailing)))
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                content
                    .font(.subheadline)
            }
        }
    }
}
