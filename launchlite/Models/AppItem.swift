//
//  AppItem.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Foundation
import SwiftData

@Model
final class AppItem {
    #Unique<AppItem>([\.bundleID])

    var bundleID: String
    var name: String
    var iconData: Data?
    var pageIndex: Int
    var gridRow: Int
    var gridColumn: Int
    var folderID: String?
    var lastUsed: Date?

    var folder: AppFolder?

    init(
        bundleID: String,
        name: String,
        iconData: Data? = nil,
        pageIndex: Int = 0,
        gridRow: Int = 0,
        gridColumn: Int = 0,
        folderID: String? = nil,
        lastUsed: Date? = nil
    ) {
        self.bundleID = bundleID
        self.name = name
        self.iconData = iconData
        self.pageIndex = pageIndex
        self.gridRow = gridRow
        self.gridColumn = gridColumn
        self.folderID = folderID
        self.lastUsed = lastUsed
    }
}
