//
//  AppScanner.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import AppKit
import Combine
import Foundation

struct ScannedApp: Sendable, Identifiable, Hashable {
    let bundleID: String
    let name: String
    let url: URL
    let icon: NSImage

    var id: String { bundleID }
}

@MainActor
final class AppScanner: ObservableObject {

    @Published private(set) var apps: [ScannedApp] = []

    private let searchPaths: [String] = [
        "/Applications",
        "/System/Applications",
        NSString("~/Applications").expandingTildeInPath,
    ]

    private var fileSources: [DispatchSourceFileSystemObject] = []

    init() {
        startMonitoring()
    }

    deinit {
        for source in fileSources {
            source.cancel()
        }
        fileSources.removeAll()
    }

    // MARK: - Public

    func scan() async -> [ScannedApp] {
        let paths = searchPaths
        let scanned = await Task.detached {
            AppScanner.performScan(searchPaths: paths)
        }.value

        apps = scanned
        return scanned
    }

    // MARK: - File System Monitoring

    private func startMonitoring() {
        for path in searchPaths {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: .global(qos: .utility)
            )

            source.setEventHandler { [weak self] in
                Task { @MainActor [weak self] in
                    _ = await self?.scan()
                }
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()
            fileSources.append(source)
        }
    }

    // MARK: - Scanning (nonisolated)

    nonisolated private static func performScan(searchPaths: [String]) -> [ScannedApp] {
        var results: [String: ScannedApp] = [:]

        for path in searchPaths {
            let directoryURL = URL(fileURLWithPath: path)
            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "app" else { continue }
                guard !isFilteredApp(fileURL) else { continue }

                if let app = scannedApp(from: fileURL) {
                    results[app.bundleID] = app
                }
            }
        }

        return results.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func scannedApp(from url: URL) -> ScannedApp? {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier
        else { return nil }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 512, height: 512)

        return ScannedApp(bundleID: bundleID, name: name, url: url, icon: icon)
    }

    nonisolated private static func isFilteredApp(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasPrefix(".") { return true }

        let filteredPaths = [
            "/System/Applications/Utilities/",
            "/System/Library/",
            "/usr/",
        ]
        let path = url.path
        for filtered in filteredPaths {
            if path.hasPrefix(filtered) { return true }
        }

        let filteredBundleIDs = [
            "com.apple.finder",
        ]
        if let bundle = Bundle(url: url),
           let bundleID = bundle.bundleIdentifier,
           filteredBundleIDs.contains(bundleID)
        {
            return true
        }

        return false
    }
}
