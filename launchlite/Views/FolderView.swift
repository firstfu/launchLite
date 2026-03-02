//
//  FolderView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Displays a folder with a 3x3 mini grid preview of contained apps.
/// Tapping expands to show the full folder content overlay.
/// Supports renaming, deleting, and dragging apps in/out.
struct FolderView: View {
    let folder: AppFolder
    let iconSize: CGFloat

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @State private var isExpanded = false
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var editedName: String = ""

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                folderPreview
                    .scaleEffect(isHovering ? 1.08 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isHovering)

                if appState.isEditMode {
                    Button {
                        gridLayoutManager.deleteFolder(folder)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, .gray)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -4, y: -4)
                }
            }

            if isRenaming {
                TextField("資料夾名稱", text: $editedName, onCommit: {
                    gridLayoutManager.renameFolder(folder, to: editedName)
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(width: iconSize + 16)
                .onAppear { editedName = folder.name }
            } else {
                Text(folder.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: iconSize + 16)
                    .onTapGesture(count: 2) {
                        editedName = folder.name
                        isRenaming = true
                    }
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if appState.isEditMode {
                editedName = folder.name
                isRenaming = true
            } else {
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

        return RoundedRectangle(cornerRadius: 14)
            .fill(.white.opacity(0.20))
            .frame(width: iconSize, height: iconSize)
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
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
            // Editable folder name
            if isRenaming {
                TextField("資料夾名稱", text: $editedName, onCommit: {
                    gridLayoutManager.renameFolder(folder, to: editedName)
                    isRenaming = false
                })
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(width: 200)
            } else {
                Text(folder.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .onTapGesture(count: 2) {
                        editedName = folder.name
                        isRenaming = true
                    }
            }

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
                    .onDrag {
                        let provider = NSItemProvider()
                        let dragID = "app-\(item.bundleID)"
                        provider.registerDataRepresentation(
                            forTypeIdentifier: UTType.launchLiteGridItem.identifier,
                            visibility: .ownProcess
                        ) { completion in
                            completion(dragID.data(using: .utf8), nil)
                            return nil
                        }
                        return provider
                    }
                    .contextMenu {
                        Button("從資料夾移出") {
                            gridLayoutManager.removeFromFolder(item)
                        }
                    }
                }
            }

            // Drop zone for adding apps to the folder
            if folder.items.isEmpty {
                Text("拖曳 app 到此處")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 200, height: 60)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .onDrop(of: [.launchLiteGridItem], isTargeted: nil) { providers in
            handleFolderDrop(providers: providers)
        }
    }

    // MARK: - Drop Handling

    private func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.launchLiteGridItem.identifier) { data, _ in
                guard let data, let dragID = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    gridLayoutManager.addToFolder(itemID: dragID, folder: folder)
                }
            }
        }
        return true
    }
}
