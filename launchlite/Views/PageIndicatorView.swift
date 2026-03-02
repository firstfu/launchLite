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
                    Circle()
                        .fill(index == appState.currentPage ? .white : .white.opacity(0.4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == appState.currentPage ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: appState.currentPage)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState.currentPage = index
                            }
                        }
                }
            }
            .padding(.vertical, 8)
        }
    }
}
