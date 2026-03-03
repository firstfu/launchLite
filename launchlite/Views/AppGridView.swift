//
//  AppGridView.swift
//  launchlite
//
//  Created on 2026/3/2.
//
//  應用程式網格視圖，顯示當前頁面的應用圖示，支援分頁動畫、拖放重排和資料夾建立。

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 擴展 UTType，定義 LaunchLite 內部拖放使用的自訂類型。
extension UTType {
    /// LaunchLite 網格項目的自訂 UTType，用於內部拖放識別。
    static let launchLiteGridItem = UTType(exportedAs: "com.firstfu.tw.launchlite.griditem")
}

/// Displays all pages of app icons in a horizontal strip, with support for
/// continuous gesture-driven page scrolling, drag-and-drop rearranging, and folder creation.
struct AppGridView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var gridLayoutManager: GridLayoutManager
    @Query private var preferences: [UserPreferences]

    @State private var hoveredItemID: String?
    @State private var folderCreationTimer: Timer?

    /// 取得目前的使用者偏好設定，若無則回傳預設值。
    private var prefs: UserPreferences {
        preferences.first ?? UserPreferences()
    }

    /// 從偏好設定取得圖示大小。
    private var iconSize: CGFloat {
        prefs.iconSize
    }

    /// 根據偏好設定的欄數產生 LazyVGrid 所需的欄位配置。
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 28),
            count: prefs.gridColumns
        )
    }

    /// 計算滿頁 grid 的預期高度，確保每頁 grid 區域大小一致。
    private var expectedGridHeight: CGFloat {
        let cellHeight = iconSize + 58 // icon area (iconSize+20) + spacing (8) + text (~30)
        let rows = CGFloat(prefs.gridRows)
        return rows * cellHeight + (rows - 1) * 32
    }

    /// 將所有頁面水平排列在 HStack 中，透過偏移量實現即時跟隨手勢的翻頁效果。
    var body: some View {
        GeometryReader { geometry in
            let pageWidth = geometry.size.width
            let totalPages = max(1, appState.totalPages)

            HStack(spacing: 0) {
                ForEach(0..<totalPages, id: \.self) { pageIndex in
                    pageContent(for: pageIndex)
                        .frame(width: pageWidth, alignment: .top)
                }
            }
            .offset(x: pageOffset(pageWidth: pageWidth))
            .onChange(of: geometry.size.width) { _, newWidth in
                appState.viewportWidth = newWidth
            }
            .onAppear {
                appState.viewportWidth = geometry.size.width
            }
        }
        .frame(height: expectedGridHeight)
        .onChange(of: gridLayoutManager.draggedItemID) { _, newValue in
            if newValue == nil {
                hoveredItemID = nil
                folderCreationTimer?.invalidate()
                folderCreationTimer = nil
            }
        }
    }

    // MARK: - Page Offset

    /// 計算 HStack 的水平偏移量，包含基礎頁面偏移和拖動偏移（含邊緣橡皮筋效果）。
    private func pageOffset(pageWidth: CGFloat) -> CGFloat {
        let baseOffset = -CGFloat(appState.currentPage) * pageWidth
        let drag = appState.pageDragOffset

        // Rubber-band dampening at edges
        let effectiveDrag: CGFloat
        if appState.currentPage == 0 && drag > 0 {
            effectiveDrag = rubberBand(drag)
        } else if appState.currentPage >= appState.totalPages - 1 && drag < 0 {
            effectiveDrag = -rubberBand(-drag)
        } else {
            effectiveDrag = drag
        }

        return baseOffset + effectiveDrag
    }

    /// 橡皮筋阻尼公式，模擬原生 Launchpad 邊緣過捲效果。
    private func rubberBand(_ offset: CGFloat) -> CGFloat {
        let dimension: CGFloat = 800
        return (1 - (1 / (offset / dimension + 1))) * dimension
    }

    // MARK: - Page Content

    /// 根據搜尋狀態建立對應頁面的網格內容。
    @ViewBuilder
    private func pageContent(for page: Int) -> some View {
        if appState.isSearching {
            searchPageGrid(for: page)
        } else {
            customOrderPageGrid(for: page)
        }
    }

    // MARK: - Search Mode Grid (flat, alphabetical, no folders)

    /// 搜尋模式的扁平網格視圖，按字母順序顯示過濾後的應用程式（無資料夾）。
    private func searchPageGrid(for page: Int) -> some View {
        let apps = appState.apps(forPage: page)
        return LazyVGrid(columns: columns, spacing: 32) {
            ForEach(apps) { app in
                AppIconView(app: app, iconSize: iconSize)
            }
        }
        .padding(.horizontal, 64)
    }

    // MARK: - Custom Order Grid (with folders and drag-and-drop)

    /// 自訂排序的網格視圖，支援資料夾顯示和拖放重排。
    /// 使用整個網格區域的 DropDelegate，根據游標座標計算目標位置，不需要精確經過圖示。
    private func customOrderPageGrid(for page: Int) -> some View {
        let items = appState.gridItems(forPage: page)
        let cols = prefs.gridColumns
        let colSpacing: CGFloat = 28
        let rowSpacing: CGFloat = 32
        let hPadding: CGFloat = 64
        let gridWidth = appState.viewportWidth
        let availableWidth = gridWidth - 2 * hPadding
        let cellWidth = cols > 0 ? max(1, (availableWidth - CGFloat(cols - 1) * colSpacing) / CGFloat(cols)) : 1
        let cellHeight = iconSize + 58
        let pageStartIndex = page * appState.appsPerPage

        return LazyVGrid(columns: columns, spacing: rowSpacing) {
            ForEach(items) { item in
                gridCell(for: item)
                    .opacity(gridLayoutManager.draggedItemID == item.id ? 0.3 : 1.0)
                    .scaleEffect(hoveredItemID == item.id && gridLayoutManager.draggedItemID != item.id ? 1.12 : 1.0)
                    .onDrag {
                        gridLayoutManager.startDrag(itemID: item.id)
                        let provider = NSItemProvider()
                        provider.registerDataRepresentation(
                            forTypeIdentifier: UTType.launchLiteGridItem.identifier,
                            visibility: .ownProcess
                        ) { completion in
                            completion(Data(), nil)
                            return nil
                        }
                        return provider
                    }
            }
        }
        .padding(.horizontal, hPadding)
        .onDrop(
            of: [.launchLiteGridItem],
            delegate: GridAreaDropDelegate(
                gridLayoutManager: gridLayoutManager,
                pageStartIndex: pageStartIndex,
                columns: cols,
                cellWidth: cellWidth,
                cellHeight: cellHeight,
                columnSpacing: colSpacing,
                rowSpacing: rowSpacing,
                horizontalPadding: hPadding,
                hoveredItemID: $hoveredItemID,
                folderCreationTimer: $folderCreationTimer
            )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gridLayoutManager.allItems.map(\.id))
    }

    // MARK: - Grid Cell

    /// 根據 GridSlotItem 類型建立對應的網格儲存格視圖（應用程式或資料夾）。
    @ViewBuilder
    private func gridCell(for item: GridSlotItem) -> some View {
        switch item {
        case .app(let scannedApp):
            AppIconView(app: scannedApp, iconSize: iconSize)
        case .folder(let folder):
            FolderView(folder: folder, iconSize: iconSize)
        }
    }
}

// MARK: - Grid Area Drop Delegate

/// 整個網格區域的拖放委託，根據游標座標計算目標格位，實現原生 Launchpad 風格的即時重排。
/// 不需要精確經過圖示，游標在網格任意位置都能觸發重排。
struct GridAreaDropDelegate: DropDelegate {
    let gridLayoutManager: GridLayoutManager
    let pageStartIndex: Int
    let columns: Int
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let horizontalPadding: CGFloat
    @Binding var hoveredItemID: String?
    @Binding var folderCreationTimer: Timer?

    /// 根據游標座標計算對應的 allItems 全域索引。
    private func globalIndex(at location: CGPoint) -> Int? {
        let x = location.x - horizontalPadding
        let y = location.y

        let colStep = cellWidth + columnSpacing
        let rowStep = cellHeight + rowSpacing

        let col = max(0, min(Int(x / colStep), columns - 1))
        let row = max(0, Int(y / rowStep))

        let localIndex = row * columns + col
        let globalIdx = pageStartIndex + localIndex

        guard globalIdx >= 0, globalIdx < gridLayoutManager.allItems.count else { return nil }
        return globalIdx
    }

    func dropEntered(info: DropInfo) {
        // 初次進入，由 dropUpdated 持續追蹤
    }

    /// 拖動過程中持續追蹤游標位置，即時重排或高亮目標資料夾。
    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let dragID = gridLayoutManager.draggedItemID else {
            return DropProposal(operation: .cancel)
        }

        guard let targetIdx = globalIndex(at: info.location) else {
            hoveredItemID = nil
            folderCreationTimer?.invalidate()
            folderCreationTimer = nil
            return DropProposal(operation: .move)
        }

        let targetItem = gridLayoutManager.allItems[targetIdx]

        // 游標在被拖曳項目自身的位置上 — 不做任何動作（保持資料夾計時器繼續）
        if targetItem.id == dragID {
            return DropProposal(operation: .move)
        }

        // 目標改變時才觸發重排或資料夾操作
        guard hoveredItemID != targetItem.id else {
            return DropProposal(operation: .move)
        }

        hoveredItemID = targetItem.id
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil

        if case .folder = targetItem {
            // 目標是資料夾 — 僅高亮，不重排
        } else {
            // 目標是 app — 立即重排
            gridLayoutManager.liveReorder(draggedID: dragID, targetID: targetItem.id)

            // 啟動資料夾建立計時器：若游標在同位置停留 0.8 秒則建立資料夾
            let targetID = targetItem.id
            let timer = Timer(timeInterval: 0.8, repeats: false) { _ in
                gridLayoutManager.createFolder(fromItemID: dragID, andItemID: targetID)
                hoveredItemID = nil
            }
            RunLoop.main.add(timer, forMode: .common)
            folderCreationTimer = timer
        }

        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        hoveredItemID = nil
        folderCreationTimer?.invalidate()
        folderCreationTimer = nil
    }

    /// 放下時處理資料夾放入或完成重排持久化。
    func performDrop(info: DropInfo) -> Bool {
        defer {
            gridLayoutManager.endDrag()
            hoveredItemID = nil
            folderCreationTimer?.invalidate()
            folderCreationTimer = nil
        }

        guard let dragID = gridLayoutManager.draggedItemID,
              let targetIdx = globalIndex(at: info.location),
              targetIdx < gridLayoutManager.allItems.count else {
            return true
        }

        let targetItem = gridLayoutManager.allItems[targetIdx]

        // 放在資料夾上 → 加入資料夾
        if case .folder(let folder) = targetItem, dragID != targetItem.id {
            gridLayoutManager.addToFolder(itemID: dragID, folder: folder)
        }

        // 否則重排已在 dropUpdated 完成，endDrag() 會持久化
        return true
    }
}
