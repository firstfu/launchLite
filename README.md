# LaunchLite

一款 macOS 原生應用程式啟動器，以 iOS 風格的全螢幕格狀介面取代內建的 Launchpad，支援資料夾管理、拖放排序、搜尋過濾及多種啟動方式。

## 功能特色

- **全螢幕應用程式格狀顯示** — 分頁式格狀佈局，支援滑動手勢與鍵盤切換頁面
- **應用程式自動掃描** — 即時偵測 `/Applications`、`/System/Applications`、`~/Applications` 下的所有應用程式
- **拖放排序** — 直覺式拖放重新排列應用程式位置
- **資料夾管理** — 將一個 App 拖曳至另一個上方即可建立資料夾，支援展開檢視、重新命名及刪除
- **即時搜尋** — 依應用程式名稱或 Bundle ID 進行過濾
- **編輯模式** — 長按進入抖動模式，可刪除或管理項目
- **多種啟動方式**
  - 快捷鍵（預設 `⌥⌘L`，可自訂）
  - 觸控板雙指捏合手勢
  - 螢幕熱角
  - 選單列圖示
- **外觀自訂** — 可調整格狀行列數（3–8 行、5–10 列）及圖示大小（48–128pt）
- **多螢幕支援** — 自動在滑鼠所在螢幕顯示
- **流暢動畫** — 淡入縮放、彈性切頁、懸停特效、編輯模式抖動動畫

## 系統需求

- macOS 26.2+
- 需要「輔助使用」權限（全域快捷鍵功能）

## 建置

```bash
# Debug 建置
xcodebuild -scheme launchlite -configuration Debug build

# Release 建置
xcodebuild -scheme launchlite -configuration Release build
```

或直接在 Xcode 中開啟 `launchlite.xcodeproj` 並按下 `⌘R` 執行。

## 測試

```bash
# 執行所有測試
xcodebuild test -scheme launchlite -destination 'platform=macOS'

# 僅單元測試
xcodebuild test -scheme launchlite -destination 'platform=macOS' -only-testing:launchliteTests

# 僅 UI 測試
xcodebuild test -scheme launchlite -destination 'platform=macOS' -only-testing:launchliteUITests
```

## 專案結構

```
launchlite/
├── App/
│   ├── LaunchLiteApp.swift          # @main 入口，選單列與 AppDelegate
│   └── AppState.swift               # 集中式狀態管理（ObservableObject）
├── Panel/
│   ├── LaunchpadPanel.swift         # 自訂 NSPanel（全螢幕、模糊背景）
│   └── LaunchpadWindowController.swift  # 視窗生命週期與動畫控制
├── Views/
│   ├── LaunchpadView.swift          # 主容器（搜尋列 + 格狀 + 頁面指示器）
│   ├── AppGridView.swift            # 格狀渲染與拖放處理
│   ├── AppIconView.swift            # 單一應用程式圖示
│   ├── FolderView.swift             # 資料夾預覽與展開檢視
│   ├── SearchBarView.swift          # 搜尋輸入欄
│   ├── PageIndicatorView.swift      # 頁面圓點指示器
│   └── SettingsView.swift           # 設定視窗（外觀、快捷鍵、一般）
├── Models/
│   ├── AppItem.swift                # SwiftData 模型：應用程式
│   ├── AppFolder.swift              # SwiftData 模型：資料夾
│   ├── UserPreferences.swift        # SwiftData 模型：使用者偏好設定
│   └── GridSlotItem.swift           # 統一格狀項目列舉
├── Services/
│   ├── AppScanner.swift             # 應用程式探索與檔案系統監控
│   ├── GridLayoutManager.swift      # 格狀佈局與拖放邏輯
│   ├── HotKeyManager.swift          # 全域快捷鍵（CGEvent tap）
│   ├── GestureMonitor.swift         # 觸控板捏合手勢偵測
│   ├── HotCornerMonitor.swift       # 螢幕熱角偵測
│   └── IconStyleManager.swift       # 圖示擷取與外觀偵測
└── Utilities/
    └── BlurEffect.swift             # 毛玻璃效果工具
```

## 技術堆疊

| 層級 | 技術 |
|------|------|
| UI 框架 | SwiftUI |
| 資料持久化 | SwiftData |
| 響應式 | Combine |
| 視窗管理 | AppKit（NSPanel + NSHostingView）|
| 輸入偵測 | CGEvent tap、NSEvent monitors |
| 拖放 | UTType + NSItemProvider |

## 授權

MIT License
