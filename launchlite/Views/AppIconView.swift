//
//  AppIconView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI

/// Displays a single app icon with name label. Supports hover, click-to-launch,
/// and edit mode (jiggle animation with delete button).
struct AppIconView: View {
    let app: ScannedApp
    let iconSize: CGFloat

    @EnvironmentObject private var appState: AppState
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .scaleEffect(isHovering ? 1.1 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovering)

                if appState.isEditMode {
                    Button {
                        // Delete action placeholder - remove from grid
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -4, y: -4)
                }
            }
            .rotationEffect(
                appState.isEditMode
                    ? .degrees(Double.random(in: -2...2))
                    : .zero
            )
            .animation(
                appState.isEditMode
                    ? .easeInOut(duration: 0.12).repeatForever(autoreverses: true)
                    : .default,
                value: appState.isEditMode
            )

            Text(app.name)
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 16)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if !appState.isEditMode {
                appState.launchApp(bundleID: app.bundleID)
            }
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            appState.isEditMode.toggle()
        }
    }
}
