//
//  HotCornerMonitor.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Cocoa

@MainActor
final class HotCornerMonitor {
    enum Corner: Int, CaseIterable, Sendable {
        case topLeft = 0
        case topRight = 1
        case bottomLeft = 2
        case bottomRight = 3
    }

    private var monitor: Any?
    private let onTrigger: () -> Void

    /// Which corner is active.
    var activeCorner: Corner = .topLeft

    /// Size of the corner detection zone in points.
    private let cornerSize: CGFloat = 5

    /// How long the mouse must stay in the corner before triggering (seconds).
    private let dwellTime: TimeInterval = 0.5

    /// Minimum interval between triggers to prevent rapid re-firing.
    private let cooldownInterval: TimeInterval = 2.0

    private var cornerEntryTime: Date?
    private var dwellTimer: Timer?
    private var lastTriggerTime: Date = .distantPast

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
        dwellTimer?.invalidate()
    }

    // MARK: - Configuration

    func configure(corner: Corner) {
        self.activeCorner = corner
    }

    func configure(cornerPosition: Int) {
        if let corner = Corner(rawValue: cornerPosition) {
            self.activeCorner = corner
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            Task { @MainActor in
                self?.handleMouseMoved(event)
            }
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        cancelDwellTimer()
        cornerEntryTime = nil
    }

    // MARK: - Event Handling

    private func handleMouseMoved(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation

        if isInActiveCorner(mouseLocation) {
            if cornerEntryTime == nil {
                cornerEntryTime = Date()
                startDwellTimer()
            }
        } else {
            cancelDwellTimer()
            cornerEntryTime = nil
        }
    }

    private func isInActiveCorner(_ point: NSPoint) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let frame = screen.frame

        switch activeCorner {
        case .topLeft:
            return point.x <= frame.minX + cornerSize
                && point.y >= frame.maxY - cornerSize
        case .topRight:
            return point.x >= frame.maxX - cornerSize
                && point.y >= frame.maxY - cornerSize
        case .bottomLeft:
            return point.x <= frame.minX + cornerSize
                && point.y <= frame.minY + cornerSize
        case .bottomRight:
            return point.x >= frame.maxX - cornerSize
                && point.y <= frame.minY + cornerSize
        }
    }

    // MARK: - Dwell Timer

    private func startDwellTimer() {
        cancelDwellTimer()
        dwellTimer = Timer.scheduledTimer(withTimeInterval: dwellTime, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dwellTimerFired()
            }
        }
    }

    private func cancelDwellTimer() {
        dwellTimer?.invalidate()
        dwellTimer = nil
    }

    private func dwellTimerFired() {
        // Verify mouse is still in the corner
        let mouseLocation = NSEvent.mouseLocation
        guard isInActiveCorner(mouseLocation) else {
            cornerEntryTime = nil
            return
        }

        // Check cooldown
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= cooldownInterval else {
            cornerEntryTime = nil
            return
        }

        lastTriggerTime = now
        cornerEntryTime = nil
        onTrigger()
    }
}
