//
//  SearchBarView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI

/// A rounded, semi-transparent search bar styled like the classic Launchpad search field.
struct SearchBarView: View {
    @EnvironmentObject private var appState: AppState
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))
                .font(.system(size: 13))

            TextField("Search", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .focused($isFocused)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            isFocused = true
        }
    }
}
