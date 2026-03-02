//
//  AppState.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import AppKit
import Combine
import SwiftData

@MainActor
final class AppState: ObservableObject {

    // MARK: - Published State

    @Published var isVisible = false
    @Published var searchText = ""
    @Published var isEditMode = false
    @Published var currentPage = 0
    @Published private(set) var installedApps: [ScannedApp] = []
    @Published private(set) var filteredApps: [ScannedApp] = []

    // MARK: - Dependencies

    let appScanner: AppScanner
    let modelContext: ModelContext
    let gridLayoutManager: GridLayoutManager

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(appScanner: AppScanner, modelContext: ModelContext) {
        self.appScanner = appScanner
        self.modelContext = modelContext
        self.gridLayoutManager = GridLayoutManager(modelContext: modelContext)

        setupBindings()
    }

    // MARK: - Reactive Bindings

    private func setupBindings() {
        // Sync scanner results into installedApps
        appScanner.$apps
            .receive(on: RunLoop.main)
            .assign(to: &$installedApps)

        // Filter apps whenever searchText or installedApps changes
        $searchText
            .combineLatest($installedApps)
            .map { query, apps in
                guard !query.isEmpty else { return apps }
                let lowered = query.lowercased()
                return apps.filter {
                    $0.name.lowercased().contains(lowered)
                        || $0.bundleID.lowercased().contains(lowered)
                }
            }
            .assign(to: &$filteredApps)

        // Sync grid layout whenever installed apps change
        $installedApps
            .sink { [weak self] apps in
                self?.gridLayoutManager.syncWithScannedApps(apps)
            }
            .store(in: &cancellables)

        // Reset page to 0 when search text changes
        $searchText
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.currentPage = 0
            }
            .store(in: &cancellables)
    }

    // MARK: - Pagination

    /// Whether we are currently in search mode (non-empty search text).
    var isSearching: Bool { !searchText.isEmpty }

    /// Number of items that fit on a single page, based on UserPreferences grid size.
    var appsPerPage: Int {
        let prefs = fetchPreferences()
        return prefs.gridRows * prefs.gridColumns
    }

    /// Total number of pages needed.
    var totalPages: Int {
        let perPage = appsPerPage
        guard perPage > 0 else { return 1 }
        let totalCount = isSearching ? filteredApps.count : gridLayoutManager.totalItems
        return max(1, Int(ceil(Double(totalCount) / Double(perPage))))
    }

    /// Returns the flat list of filtered apps for a search page (no folders, alphabetical).
    func apps(forPage page: Int) -> [ScannedApp] {
        let perPage = appsPerPage
        guard perPage > 0 else { return [] }
        let start = page * perPage
        guard start < filteredApps.count else { return [] }
        let end = min(start + perPage, filteredApps.count)
        return Array(filteredApps[start..<end])
    }

    /// Returns the unified grid slot items for a page (custom order with folders).
    func gridItems(forPage page: Int) -> [GridSlotItem] {
        gridLayoutManager.items(forPage: page, perPage: appsPerPage)
    }

    // MARK: - Visibility

    func show() {
        searchText = ""
        isEditMode = false
        currentPage = 0
        isVisible = true
    }

    func hide() {
        isVisible = false
        searchText = ""
        isEditMode = false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - App Launching

    func launchApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)

        // Update lastUsed timestamp in SwiftData
        let descriptor = FetchDescriptor<AppItem>(
            predicate: #Predicate { $0.bundleID == bundleID }
        )
        if let item = try? modelContext.fetch(descriptor).first {
            item.lastUsed = Date()
            try? modelContext.save()
        }

        hide()
    }

    // MARK: - Refresh

    func refreshApps() async {
        _ = await appScanner.scan()
    }

    // MARK: - Preferences Helper

    private func fetchPreferences() -> UserPreferences {
        let descriptor = FetchDescriptor<UserPreferences>()
        if let prefs = try? modelContext.fetch(descriptor).first {
            return prefs
        }
        return UserPreferences()
    }
}
