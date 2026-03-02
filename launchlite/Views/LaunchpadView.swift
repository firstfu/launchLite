//
//  LaunchpadView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI

/// The main Launchpad container view. Hosts the search bar, app grid, and page indicator.
/// Designed to be embedded in the LaunchpadPanel via NSHostingView.
struct LaunchpadView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Search bar at top
            SearchBarView()
                .padding(.top, 36)

            Spacer()

            // App grid in center (pagination handles overflow, no ScrollView needed)
            AppGridView()

            Spacer()

            // Page indicator at bottom
            PageIndicatorView()
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Tap on empty area to close — child views' gestures take priority
            appState.hide()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    let horizontal = value.translation.width
                    if horizontal < -50, appState.currentPage < appState.totalPages - 1 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.currentPage += 1
                        }
                    } else if horizontal > 50, appState.currentPage > 0 {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appState.currentPage -= 1
                        }
                    }
                }
        )
        .task {
            await appState.refreshApps()
        }
    }
}
