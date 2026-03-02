# LaunchLite — macOS Launchpad 替代應用設計文件

**日期**: 2026-03-02
**狀態**: 已核准

## 目標

復刻經典 macOS Launchpad 體驗，提供全螢幕應用啟動器，解決 macOS Tahoe 移除 Launchpad 後的使用者需求。

## 架構：混合架構（NSPanel + SwiftUI）

NSPanel 作為浮動全螢幕容器，SwiftUI 處理 UI 佈局與互動。

```
LaunchLiteApp (@main, MenuBarExtra)
├── AppState (ObservableObject)
├── LaunchpadPanel (NSPanel)
│   └── NSHostingView → LaunchpadView (SwiftUI)
│       ├── SearchBar
│       ├── AppGridView
│       │   ├── AppIconView
│       │   └── FolderView → FolderGridView
│       └── PageIndicator
├── HotKeyManager (全域快捷鍵)
├── GestureMonitor (觸控板手勢)
├── HotCornerMonitor (螢幕角落偵測)
└── SwiftData ModelContainer
    ├── AppItem
    ├── AppFolder
    ├── PageLayout
    └── UserPreferences
```

## 資料模型（SwiftData）

- **AppItem**: bundleID, name, iconPath, pageIndex, gridPosition, folderID?, lastUsed
- **AppFolder**: id, name, pageIndex, gridPosition, items: [AppItem]
- **PageLayout**: pageIndex, rows, columns
- **UserPreferences**: gridRows, gridColumns, iconSize, hotkey, hotCorner, showInMenuBar

## 核心 UI 行為

- **開啟**: 截取桌面 → 模糊背景（NSVisualEffectView）→ 中心縮放淡入
- **關閉**: Esc / 點擊空白 / 再次觸發快捷鍵 → 縮放淡出
- **網格**: 預設 7x5，可自訂，超出分頁，左右滑動切換
- **搜尋**: 頂部搜尋列，即時過濾，匹配名稱和 bundle ID
- **資料夾**: 拖拽建立，點擊展開浮動氣泡，可重新命名
- **拖拽排列**: 長按進入抖動模式，自由拖拽，跨頁支援
- **圖示風格**: 跟隨系統（Default/Dark/Light/Tinted）

## 啟動觸發方式

| 方式 | 實作 |
|------|------|
| 全域快捷鍵 | CGEvent tap，預設 ⌥⌘L |
| 觸控板捏合 | NSEvent global monitor，magnification 手勢 |
| Hot Corner | 滑鼠位置監聽，角落停留觸發 |
| Menu Bar | MenuBarExtra 圖示點擊 |

## 應用掃描

掃描 /Applications、~/Applications、/System/Applications。使用 NSWorkspace 讀取資訊和圖示。FSEvents 監聽變化自動更新。

## 檔案結構

```
launchlite/
├── App/
│   ├── LaunchLiteApp.swift
│   └── AppState.swift
├── Models/
│   ├── AppItem.swift
│   ├── AppFolder.swift
│   └── UserPreferences.swift
├── Views/
│   ├── LaunchpadView.swift
│   ├── AppGridView.swift
│   ├── AppIconView.swift
│   ├── FolderView.swift
│   ├── SearchBarView.swift
│   ├── PageIndicatorView.swift
│   └── SettingsView.swift
├── Panel/
│   ├── LaunchpadPanel.swift
│   └── LaunchpadWindowController.swift
├── Services/
│   ├── AppScanner.swift
│   ├── HotKeyManager.swift
│   ├── GestureMonitor.swift
│   ├── HotCornerMonitor.swift
│   └── IconStyleManager.swift
└── Utilities/
    ├── BlurEffect.swift
    └── AnimationHelper.swift
```

## 技術限制與注意事項

- App Sandbox 可能限制檔案系統掃描範圍，可能需要申請額外 entitlements
- 觸控板手勢攔截需要輔助使用權限
- 全域快捷鍵需要 Accessibility API 權限
- 圖示風格 API 在 macOS 26+ 可用
