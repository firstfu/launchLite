//
//  GridSlotItem.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import Foundation

/// A unified view-model representing a single cell in the app grid.
/// Can be either a standalone app or a folder containing multiple apps.
enum GridSlotItem: Identifiable {
    case app(ScannedApp)
    case folder(AppFolder)

    var id: String {
        switch self {
        case .app(let scannedApp):
            return "app-\(scannedApp.bundleID)"
        case .folder(let folder):
            return "folder-\(folder.id.uuidString)"
        }
    }

    var name: String {
        switch self {
        case .app(let scannedApp):
            return scannedApp.name
        case .folder(let folder):
            return folder.name
        }
    }

    var sortOrder: Int {
        switch self {
        case .app:
            // Resolved via GridLayoutManager lookup
            return 0
        case .folder(let folder):
            return folder.sortOrder
        }
    }

    /// The drag identifier string used for NSItemProvider.
    var dragID: String { id }
}
