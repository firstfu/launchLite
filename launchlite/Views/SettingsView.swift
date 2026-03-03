//
//  SettingsView.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import ServiceManagement
import SwiftData
import SwiftUI

/// The app settings view, displayed in a native macOS Settings window.
/// Provides controls for appearance, shortcuts, and general preferences.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [UserPreferences]

    private var prefs: UserPreferences {
        if let existing = allPreferences.first {
            return existing
        }
        let newPrefs = UserPreferences()
        modelContext.insert(newPrefs)
        return newPrefs
    }

    var body: some View {
        TabView {
            AppearanceTab(prefs: prefs)
                .tabItem {
                    Label("外觀", systemImage: "paintbrush")
                }

            ShortcutsTab(prefs: prefs)
                .tabItem {
                    Label("快捷鍵", systemImage: "keyboard")
                }

            GeneralTab(prefs: prefs, modelContext: modelContext)
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
        }
        .frame(width: 480, height: 340)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.level = .floating
                NSApp.keyWindow?.orderFrontRegardless()
            }
        }
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @Bindable var prefs: UserPreferences

    var body: some View {
        Form {
            Section("格狀排列") {
                HStack {
                    Text("列數")
                    Slider(
                        value: Binding(
                            get: { Double(prefs.gridRows) },
                            set: { prefs.gridRows = Int($0) }
                        ),
                        in: 3...8,
                        step: 1
                    )
                    Text("\(prefs.gridRows)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }

                HStack {
                    Text("欄數")
                    Slider(
                        value: Binding(
                            get: { Double(prefs.gridColumns) },
                            set: { prefs.gridColumns = Int($0) }
                        ),
                        in: 5...10,
                        step: 1
                    )
                    Text("\(prefs.gridColumns)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }

            Section("圖示大小") {
                HStack {
                    Text("大小")
                    Slider(value: $prefs.iconSize, in: 48...160, step: 4)
                    Text("\(Int(prefs.iconSize)) pt")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Shortcuts Tab

private struct ShortcutsTab: View {
    @Bindable var prefs: UserPreferences
    @State private var isRecordingHotkey = false
    @AppStorage("gestureEnabled") private var gestureEnabled = true

    var body: some View {
        Form {
            Section("鍵盤快捷鍵") {
                HStack {
                    Text("啟動快捷鍵")
                    Spacer()
                    HotKeyRecorderButton(
                        hotkey: $prefs.hotkey,
                        isRecording: $isRecordingHotkey
                    )
                }
            }

            Section("觸控板手勢") {
                Toggle("啟用捏合手勢觸發", isOn: $gestureEnabled)
            }

            Section("螢幕角落觸發") {
                Toggle("啟用熱角", isOn: $prefs.hotCornerEnabled)

                if prefs.hotCornerEnabled {
                    Picker("位置", selection: $prefs.hotCornerPosition) {
                        Text("左上角").tag(0)
                        Text("右上角").tag(1)
                        Text("左下角").tag(2)
                        Text("右下角").tag(3)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @Bindable var prefs: UserPreferences
    let modelContext: ModelContext
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("選單列") {
                Toggle("在選單列中顯示", isOn: $prefs.showInMenuBar)
            }

            Section("啟動") {
                Toggle("登入時自動啟動", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("重設") {
                Button("重設佈局", role: .destructive) {
                    showResetConfirmation = true
                }
                .confirmationDialog(
                    "確定要重設所有配置嗎？此操作無法復原。",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("重設", role: .destructive) {
                        resetLayout()
                    }
                    Button("取消", role: .cancel) {}
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func resetLayout() {
        let descriptor = FetchDescriptor<AppItem>()
        guard let items = try? modelContext.fetch(descriptor) else { return }
        for item in items {
            item.pageIndex = 0
            item.gridRow = 0
            item.gridColumn = 0
            item.folderID = nil
            item.folder = nil
        }

        let folderDescriptor = FetchDescriptor<AppFolder>()
        if let folders = try? modelContext.fetch(folderDescriptor) {
            for folder in folders {
                modelContext.delete(folder)
            }
        }

        prefs.gridRows = 5
        prefs.gridColumns = 7
        prefs.iconSize = 120
        prefs.hotkey = "⌥⌘L"
        prefs.hotCornerEnabled = false
        prefs.hotCornerPosition = 0
        prefs.showInMenuBar = true

        try? modelContext.save()
    }
}

// MARK: - Hotkey Recorder

private struct HotKeyRecorderButton: View {
    @Binding var hotkey: String
    @Binding var isRecording: Bool

    var body: some View {
        Button {
            isRecording.toggle()
        } label: {
            Text(isRecording ? "請按下快捷鍵..." : hotkey)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .frame(minWidth: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.bordered)
        .overlay(
            Group {
                if isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 4)
                }
            }
        )
        .animation(.easeOut(duration: 0.2), value: isRecording)
        .background {
            if isRecording {
                HotKeyRecorderRepresentable(hotkey: $hotkey, isRecording: $isRecording)
            }
        }
    }
}

/// NSViewRepresentable that captures keyboard events for hotkey recording.
private struct HotKeyRecorderRepresentable: NSViewRepresentable {
    @Binding var hotkey: String
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> HotKeyCapturingView {
        let view = HotKeyCapturingView()
        view.onKeyRecorded = { recorded in
            hotkey = recorded
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: HotKeyCapturingView, context: Context) {}
}

/// NSView subclass that intercepts key events to record a hotkey combination.
final class HotKeyCapturingView: NSView {
    var onKeyRecorded: ((String) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == 53 {
            onCancel?()
            return
        }

        var parts: [String] = []
        let flags = event.modifierFlags

        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }

        // At least one modifier is required
        guard !parts.isEmpty else { return }

        if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let char = chars.first!
            if char.isLetter || char.isNumber {
                parts.append(String(char))
                onKeyRecorded?(parts.joined())
            }
        }
    }
}
