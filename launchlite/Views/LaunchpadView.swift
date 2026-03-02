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
        ZStack {
            // Transparent background - tap on empty area to close
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    appState.hide()
                }

            VStack(spacing: 0) {
                // Search bar at top
                SearchBarView()
                    .padding(.top, 40)

                Spacer()

                // App grid in center
                ScrollView {
                    AppGridView()
                }
                .scrollIndicators(.hidden)

                Spacer()

                // Page indicator at bottom
                PageIndicatorView()
                    .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
