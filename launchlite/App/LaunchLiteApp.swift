//
//  LaunchLiteApp.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Combine
import SwiftData
import SwiftUI

@main
struct LaunchLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar icon
        MenuBarExtra("LaunchLite", systemImage: "square.grid.3x3") {
            Button("顯示 Launchpad") {
                appDelegate.appState.toggle()
            }
            .keyboardShortcut("l", modifiers: [.option, .command])

            Divider()

            SettingsLink {
                Text("設定...")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("結束 LaunchLite") {
                appDelegate.cleanup()
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }

        // Settings window
        Settings {
            SettingsView()
                .modelContainer(appDelegate.modelContainer)
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - SwiftData

    let modelContainer: ModelContainer = {
        let schema = Schema([
            AppItem.self,
            AppFolder.self,
            UserPreferences.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - State & Services

    private(set) lazy var appState: AppState = {
        AppState(
            appScanner: appScanner,
            modelContext: ModelContext(modelContainer)
        )
    }()

    private let appScanner = AppScanner()
    private var hotKeyManager: HotKeyManager?
    private var gestureMonitor: GestureMonitor?
    private var hotCornerMonitor: HotCornerMonitor?
    private var windowController: LaunchpadWindowController?
    private var visibilityCancellable: AnyCancellable?
    private var prefsCancellable: AnyCancellable?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupWindowController()
        setupInputServices()
        observeVisibility()
        loadPreferences()
        observePreferenceChanges()

        // Initial app scan
        Task {
            await appState.refreshApps()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cleanup()
    }

    func cleanup() {
        hotKeyManager?.stop()
        gestureMonitor?.stop()
        hotCornerMonitor?.stop()
    }

    // MARK: - Window Controller

    private func setupWindowController() {
        let launchpadView = LaunchpadView()
            .environmentObject(appState)
            .environmentObject(appState.gridLayoutManager)
            .modelContainer(modelContainer)
        let wc = LaunchpadWindowController(rootView: launchpadView)
        wc.onDismiss = { [weak self] in
            self?.appState.hide()
        }
        wc.onPageSwipe = { [weak self] direction in
            guard let self else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if direction > 0, self.appState.currentPage < self.appState.totalPages - 1 {
                    self.appState.currentPage += 1
                } else if direction < 0, self.appState.currentPage > 0 {
                    self.appState.currentPage -= 1
                }
            }
        }
        windowController = wc
    }

    // MARK: - Input Services

    private func setupInputServices() {
        hotKeyManager = HotKeyManager { [weak self] in
            self?.appState.toggle()
        }
        let started = hotKeyManager?.start() ?? false
        if !started {
            print("[LaunchLite] HotKeyManager failed to start - check accessibility permissions")
        }

        gestureMonitor = GestureMonitor { [weak self] in
            self?.appState.toggle()
        }
        gestureMonitor?.start()

        hotCornerMonitor = HotCornerMonitor { [weak self] in
            self?.appState.toggle()
        }
        // Hot corner starts disabled by default; enabled via preferences
    }

    // MARK: - Visibility

    private func observeVisibility() {
        visibilityCancellable = appState.$isVisible
            .removeDuplicates()
            .sink { [weak self] visible in
                if visible {
                    self?.windowController?.showPanel()
                } else {
                    self?.windowController?.hidePanel()
                }
            }
    }

    // MARK: - Preferences

    private func observePreferenceChanges() {
        prefsCancellable = NotificationCenter.default
            .publisher(for: .preferencesDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadPreferences()
            }
    }

    private func loadPreferences() {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<UserPreferences>()
        guard let prefs = try? context.fetch(descriptor).first else { return }

        hotKeyManager?.configure(hotkey: prefs.hotkey)
        let started = hotKeyManager?.start() ?? false
        if !started {
            print("[LaunchLite] HotKeyManager failed to start - check accessibility permissions")
        }

        if prefs.hotCornerEnabled {
            hotCornerMonitor?.configure(cornerPosition: prefs.hotCornerPosition)
            hotCornerMonitor?.start()
        } else {
            hotCornerMonitor?.stop()
        }
    }
}
