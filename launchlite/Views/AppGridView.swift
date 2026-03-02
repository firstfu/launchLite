//
//  AppGridView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI
import SwiftData

/// Displays the grid of app icons for the current page, with support for
/// page transitions and drag-and-drop rearranging.
struct AppGridView: View {
    @EnvironmentObject private var appState: AppState
    @Query private var preferences: [UserPreferences]
    @Query private var folders: [AppFolder]

    private var prefs: UserPreferences {
        preferences.first ?? UserPreferences()
    }

    private var iconSize: CGFloat {
        prefs.iconSize
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 20),
            count: prefs.gridColumns
        )
    }

    var body: some View {
        let currentApps = appState.apps(forPage: appState.currentPage)

        LazyVGrid(columns: columns, spacing: 24) {
            // Show folders on first page when not searching
            if appState.currentPage == 0 && appState.searchText.isEmpty {
                ForEach(folders, id: \.id) { folder in
                    FolderView(folder: folder, iconSize: iconSize)
                }
            }

            ForEach(currentApps) { app in
                AppIconView(app: app, iconSize: iconSize)
            }
        }
        .padding(.horizontal, 40)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id(appState.currentPage)
        .animation(.easeInOut(duration: 0.3), value: appState.currentPage)
    }
}
