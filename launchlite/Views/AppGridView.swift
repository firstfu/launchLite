//
//  AppGridView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Custom UTType for internal drag-and-drop (avoids macOS text rendering artifacts)
extension UTType {
    static let launchLiteGridItem = UTType(importedAs: "com.firstfu.tw.launchlite.griditem")
}

/// Displays the grid of app icons for the current page, with support for
/// page transitions, drag-and-drop rearranging, and folder creation.
struct AppGridView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @Query private var preferences: [UserPreferences]

    @State private var draggedItemID: String?
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
            repeating: GridItem(.flexible(), spacing: 24),
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

        return LazyVGrid(columns: columns, spacing: 28) {
            ForEach(currentApps) { app in
                AppIconView(app: app, iconSize: iconSize)
            }
        }
        .padding(.horizontal, 60)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("search-\(appState.currentPage)")
        .animation(.easeInOut(duration: 0.3), value: appState.currentPage)
    }

    // MARK: - Custom Order Grid (with folders and drag-and-drop)

    private var customOrderGrid: some View {
        let items = appState.gridItems(forPage: appState.currentPage)

        return LazyVGrid(columns: columns, spacing: 28) {
            ForEach(items) { item in
                gridCell(for: item)
                    .opacity(draggedItemID == item.id ? 0.3 : 1.0)
                    .scaleEffect(hoveredItemID == item.id && draggedItemID != item.id ? 1.15 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: hoveredItemID)
                    .onDrag {
                        draggedItemID = item.id
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
                            draggedItemID: $draggedItemID,
                            hoveredItemID: $hoveredItemID,
                            folderCreationTimer: $folderCreationTimer
                        )
                    )
            }
        }
        .padding(.horizontal, 60)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id("grid-\(appState.currentPage)")
        .animation(.easeInOut(duration: 0.3), value: appState.currentPage)
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
    @Binding var draggedItemID: String?
    @Binding var hoveredItemID: String?
    @Binding var folderCreationTimer: Timer?

    func dropEntered(info: DropInfo) {
        hoveredItemID = targetItem.id

        // Start folder creation timer when app is dragged onto another app
        if case .app = targetItem, let dragID = draggedItemID, dragID != targetItem.id {
            folderCreationTimer?.invalidate()
            folderCreationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                Task { @MainActor in
                    gridLayoutManager.createFolder(fromItemID: dragID, andItemID: targetItem.id)
                    // Don't clear draggedItemID here — let performDrop handle cleanup
                    hoveredItemID = nil
                }
            }
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
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil

        // Always clean up drag state and return true to prevent macOS drop artifacts
        defer {
            draggedItemID = nil
            hoveredItemID = nil
        }

        guard let dragID = draggedItemID, dragID != targetItem.id else {
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
