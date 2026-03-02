//
//  IconStyleManager.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Cocoa

@MainActor
final class IconStyleManager {
    enum IconStyle: Sendable {
        case automatic
        case light
        case dark
        case tinted
    }

    private(set) var currentStyle: IconStyle = .automatic
    private var appearanceObservation: NSKeyValueObservation?

    init() {
        observeAppearanceChanges()
    }

    deinit {
        appearanceObservation?.invalidate()
    }

    // MARK: - Appearance Detection

    /// Returns the current effective appearance (dark or light).
    var isDarkMode: Bool {
        let appearance = NSApp.effectiveAppearance
        return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func observeAppearanceChanges() {
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleAppearanceChange()
            }
        }
    }

    private func handleAppearanceChange() {
        // Notify observers or update cached values if needed
    }

    // MARK: - Icon Retrieval

    /// Returns the icon image for a given app bundle ID, styled appropriately.
    func icon(forBundleID bundleID: String, size: CGFloat = 64) -> NSImage {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return fallbackIcon(size: size)
        }

        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    /// Returns the icon image for an app at a given URL.
    func icon(forAppAt url: URL, size: CGFloat = 64) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }

    /// Returns icon data (PNG) for the given bundle ID.
    func iconData(forBundleID bundleID: String, size: CGFloat = 64) -> Data? {
        let image = icon(forBundleID: bundleID, size: size)
        return pngData(from: image)
    }

    // MARK: - Fallback

    private func fallbackIcon(size: CGFloat) -> NSImage {
        let image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "Application") ?? NSImage()
        image.size = NSSize(width: size, height: size)
        return image
    }

    // MARK: - PNG Conversion

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
