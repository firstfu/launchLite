//
//  FolderView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI
import SwiftData

/// Displays a folder with a 3x3 mini grid preview of contained apps.
/// Tapping expands to show the full folder content overlay.
struct FolderView: View {
    let folder: AppFolder
    let iconSize: CGFloat

    @EnvironmentObject private var appState: AppState
    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                folderPreview
                    .scaleEffect(isHovering ? 1.08 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovering)

                if appState.isEditMode {
                    Button {
                        // Delete folder placeholder
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -4, y: -4)
                }
            }

            Text(folder.name)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 16)
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if !appState.isEditMode {
                isExpanded = true
            }
        }
        .popover(isPresented: $isExpanded, arrowEdge: .bottom) {
            folderContent
        }
    }

    // MARK: - 3x3 Mini Grid Preview

    private var folderPreview: some View {
        let previewItems = Array(folder.items.prefix(9))
        let miniSize = iconSize / 4

        return RoundedRectangle(cornerRadius: 12)
            .fill(.white.opacity(0.15))
            .frame(width: iconSize, height: iconSize)
            .overlay {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(miniSize), spacing: 2), count: 3),
                    spacing: 2
                ) {
                    ForEach(previewItems, id: \.bundleID) { item in
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: miniSize, height: miniSize)
                        }
                    }
                }
                .padding(6)
            }
    }

    // MARK: - Expanded Folder Content

    private var folderContent: some View {
        VStack(spacing: 12) {
            Text(folder.name)
                .font(.headline)
                .foregroundStyle(.white)

            let columns = Array(repeating: GridItem(.fixed(64), spacing: 16), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(folder.items, id: \.bundleID) { item in
                    VStack(spacing: 4) {
                        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.bundleID) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 48, height: 48)
                        }
                        Text(item.name)
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .onTapGesture {
                        appState.launchApp(bundleID: item.bundleID)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
