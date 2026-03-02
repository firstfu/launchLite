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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.7))
                .font(.system(size: 14))

            TextField("Search", text: $appState.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .focused($isFocused)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            isFocused = true
        }
    }
}
