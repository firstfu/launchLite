//
//  PageIndicatorView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI

/// A horizontal row of dots indicating the current page, similar to iOS/Launchpad page indicators.
struct PageIndicatorView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.totalPages > 1 {
            HStack(spacing: 8) {
                ForEach(0..<appState.totalPages, id: \.self) { index in
                    let isActive = index == appState.currentPage
                    Capsule()
                        .fill(.white.opacity(isActive ? 0.95 : 0.3))
                        .frame(width: isActive ? 18 : 7, height: 7)
                        .shadow(color: .white.opacity(isActive ? 0.3 : 0.0), radius: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: appState.currentPage)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                appState.currentPage = index
                            }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.white.opacity(0.06))
            )
        }
    }
}
