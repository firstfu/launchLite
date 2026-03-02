//
//  AppFolder.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Foundation
import SwiftData

@Model
final class AppFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var pageIndex: Int
    var gridRow: Int
    var gridColumn: Int

    @Relationship(deleteRule: .nullify, inverse: \AppItem.folder)
    var items: [AppItem]

    init(
        id: UUID = UUID(),
        name: String,
        pageIndex: Int = 0,
        gridRow: Int = 0,
        gridColumn: Int = 0,
        items: [AppItem] = []
    ) {
        self.id = id
        self.name = name
        self.pageIndex = pageIndex
        self.gridRow = gridRow
        self.gridColumn = gridColumn
        self.items = items
    }
}
