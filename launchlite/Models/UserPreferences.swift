//
//  UserPreferences.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Foundation
import SwiftData

@Model
final class UserPreferences {
    var gridRows: Int
    var gridColumns: Int
    var iconSize: Double
    var hotkey: String
    var hotCornerEnabled: Bool
    var hotCornerPosition: Int
    var showInMenuBar: Bool

    init(
        gridRows: Int = 5,
        gridColumns: Int = 7,
        iconSize: Double = 120,
        hotkey: String = "⌥⌘L",
        hotCornerEnabled: Bool = false,
        hotCornerPosition: Int = 0,
        showInMenuBar: Bool = true
    ) {
        self.gridRows = gridRows
        self.gridColumns = gridColumns
        self.iconSize = iconSize
        self.hotkey = hotkey
        self.hotCornerEnabled = hotCornerEnabled
        self.hotCornerPosition = hotCornerPosition
        self.showInMenuBar = showInMenuBar
    }
}
