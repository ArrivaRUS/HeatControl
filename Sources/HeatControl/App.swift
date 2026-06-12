import SwiftUI
import AppKit

struct HeatControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MainPanelView(isFloating: false)
                .environmentObject(state)
        } label: {
            MenuBarLabel()
                .environmentObject(state)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Утилита живёт только в menu bar — без иконки в доке
        NSApp.setActivationPolicy(.accessory)

        // Внешний хук (Shortcuts/CLI): переключить плавающую панель
        //   swift -e 'import Foundation; DistributedNotificationCenter.default()
        //     .postNotificationName(.init("com.arrivarus.heatcontrol.togglePanel"),
        //                           object: nil, userInfo: nil, deliverImmediately: true)'
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.arrivarus.heatcontrol.togglePanel"),
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in PanelController.shared.toggle() }
        }
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
            if state.menuBarShowsTemp, let t = state.cpuTemp {
                Text("\(Int(t.rounded()))°")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}
