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
            HStack(spacing: 7) {
                ForEach(0..<appState.totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == appState.currentPage ? .white : .white.opacity(0.3))
                        .frame(width: 6, height: 6)
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
