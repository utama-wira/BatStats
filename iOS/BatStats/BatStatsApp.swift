// BatStats untuk iPhone & iPad
// Copyright (c) 2026 @utama_wira. Dirilis dengan Lisensi MIT (lihat LICENSE).
//
// Titik masuk aplikasi.

import BackgroundTasks
import SwiftUI
import UserNotifications

@main
struct BatStatsApp: App {
    nonisolated static let refreshTaskID = "io.github.utama-wira.batstats.refresh"

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.becameActive()
            case .background:
                store.wentToBackground()
                BatStatsApp.scheduleRefresh()
            default:
                break
            }
        }
        // iOS sesekali membangunkan app di latar (biasanya tiap 15 menit – beberapa jam, tergantung pemakaian).
        .backgroundTask(.appRefresh(BatStatsApp.refreshTaskID)) {
            BatStatsApp.scheduleRefresh()
            await Store.shared.backgroundRefresh()
        }
    }

    nonisolated static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Tampilkan notifikasi walau app sedang dibuka.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
