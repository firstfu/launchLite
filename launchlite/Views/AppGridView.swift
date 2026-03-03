//
//  AppGridView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Custom UTType for internal drag-and-drop, declared in Info.plist as exported type
extension UTType {
    static let launchLiteGridItem = UTType(exportedAs: "com.firstfu.tw.launchlite.griditem")
}

/// Displays the grid of app icons for the current page, with support for
/// page transitions, drag-and-drop rearranging, and folder creation.
struct AppGridView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @Query private var preferences: [UserPreferences]

    @State private var hoveredItemID: String?
    @State private var folderCreationTimer: Timer?

    private var prefs: UserPreferences {
        preferences.first ?? UserPreferences()
    }

    private var iconSize: CGFloat {
        prefs.iconSize
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 28),
            count: prefs.gridColumns
        )
    }

    var body: some View {
        if appState.isSearching {
            searchGrid
        } else {
            customOrderGrid
        }
    }

    // MARK: - Search Mode Grid (flat, alphabetical, no folders)

    private var searchGrid: some View {
        let currentApps = appState.apps(forPage: appState.currentPage)

        return LazyVGrid(columns: columns, spacing: 32) {
            ForEach(currentApps) { app in
                AppIconView(app: app, iconSize: iconSize)
            }
        }
        .padding(.horizontal, 64)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("search-\(appState.currentPage)")
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.currentPage)
    }

    // MARK: - Custom Order Grid (with folders and drag-and-drop)

    private var customOrderGrid: some View {
        let items = appState.gridItems(forPage: appState.currentPage)

        return LazyVGrid(columns: columns, spacing: 32) {
            ForEach(items) { item in
                gridCell(for: item)
                    .opacity(gridLayoutManager.draggedItemID == item.id ? 0.3 : 1.0)
                    .scaleEffect(hoveredItemID == item.id && gridLayoutManager.draggedItemID != item.id ? 1.12 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: hoveredItemID)
                    .onDrag {
                        print("[DRAG] onDrag started for item: \(item.id)")
                        gridLayoutManager.startDrag(itemID: item.id)
                        let provider = NSItemProvider()
                        provider.registerDataRepresentation(
                            forTypeIdentifier: UTType.launchLiteGridItem.identifier,
                            visibility: .ownProcess
                        ) { completion in
                            completion(Data(), nil)
                            return nil
                        }
                        return provider
                    }
                    .onDrop(
                        of: [.launchLiteGridItem],
                        delegate: GridCellDropDelegate(
                            targetItem: item,
                            gridLayoutManager: gridLayoutManager,
                            hoveredItemID: $hoveredItemID,
                            folderCreationTimer: $folderCreationTimer
                        )
                    )
            }
        }
        .padding(.horizontal, 64)
        .onChange(of: gridLayoutManager.draggedItemID) { _, newValue in
            if newValue == nil {
                hoveredItemID = nil
                folderCreationTimer?.invalidate()
                folderCreationTimer = nil
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("grid-\(appState.currentPage)")
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.currentPage)
    }

    // MARK: - Grid Cell

    @ViewBuilder
    private func gridCell(for item: GridSlotItem) -> some View {
        switch item {
        case .app(let scannedApp):
            AppIconView(app: scannedApp, iconSize: iconSize)
        case .folder(let folder):
            FolderView(folder: folder, iconSize: iconSize)
        }
    }
}

// MARK: - Drop Delegate

struct GridCellDropDelegate: DropDelegate {
    let targetItem: GridSlotItem
    let gridLayoutManager: GridLayoutManager
    @Binding var hoveredItemID: String?
    @Binding var folderCreationTimer: Timer?

    func dropEntered(info: DropInfo) {
        print("[DROP] dropEntered for target: \(targetItem.id), draggedItemID: \(gridLayoutManager.draggedItemID ?? "nil")")
        hoveredItemID = targetItem.id

        // Start folder creation timer when app is dragged onto another app
        if case .app = targetItem,
           let dragID = gridLayoutManager.draggedItemID,
           dragID != targetItem.id {
            folderCreationTimer?.invalidate()
            print("[DROP] Starting 0.5s folder creation timer (drag: \(dragID) → target: \(targetItem.id))")
            // Use .common run loop mode so the timer fires during drag sessions
            // (which run in .eventTracking mode, not .default).
            // Call createFolder directly — do NOT use Task { @MainActor in }
            // because async Tasks may not execute during event-tracking RunLoop mode.
            let timer = Timer(timeInterval: 0.5, repeats: false) { _ in
                print("[DROP] Timer fired! Calling createFolder...")
                gridLayoutManager.createFolder(fromItemID: dragID, andItemID: targetItem.id)
                hoveredItemID = nil
            }
            RunLoop.main.add(timer, forMode: .common)
            folderCreationTimer = timer
        } else {
            print("[DROP] Skipped timer — targetItem is folder or dragID mismatch")
        }
    }

    func dropExited(info: DropInfo) {
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil
        if hoveredItemID == targetItem.id {
            hoveredItemID = nil
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        print("[DROP] performDrop called for target: \(targetItem.id)")
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil

        // Always clean up drag state and return true to prevent macOS drop artifacts
        defer {
            gridLayoutManager.endDrag()
            hoveredItemID = nil
        }

        guard let dragID = gridLayoutManager.draggedItemID, dragID != targetItem.id else {
            print("[DROP] performDrop — no dragID or same item, returning early")
            return true
        }

        // If target is a folder → add dragged app to folder
        if case .folder(let folder) = targetItem {
            gridLayoutManager.addToFolder(itemID: dragID, folder: folder)
            return true
        }

        // Otherwise → reorder (item may already have been foldered by timer)
        guard let targetIndex = gridLayoutManager.allItems.firstIndex(where: { $0.id == targetItem.id }) else {
            return true
        }
        gridLayoutManager.moveItem(id: dragID, toIndex: targetIndex)
        return true
    }
}
