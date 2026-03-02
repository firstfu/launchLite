//
//  GestureMonitor.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//

import Cocoa

@MainActor
final class GestureMonitor {
    private var monitor: Any?
    private let onTrigger: () -> Void

    /// Magnification threshold: a pinch-in that exceeds this negative value triggers the action.
    private let magnificationThreshold: CGFloat = -0.3

    /// Minimum interval between triggers to prevent rapid re-firing.
    private let debounceInterval: TimeInterval = 1.0
    private var lastTriggerTime: Date = .distantPast

    /// Tracks cumulative magnification during a single gesture sequence.
    private var cumulativeMagnification: CGFloat = 0
    private var gestureInProgress: Bool = false

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Start / Stop

    func start() {
        guard monitor == nil else { return }

        monitor = NSEvent.addGlobalMonitorForEvents(matching: .magnify) { [weak self] event in
            Task { @MainActor in
                self?.handleMagnifyEvent(event)
            }
        }
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        resetGestureState()
    }

    // MARK: - Event Handling

    private func handleMagnifyEvent(_ event: NSEvent) {
        switch event.phase {
        case .began:
            gestureInProgress = true
            cumulativeMagnification = 0

        case .changed:
            guard gestureInProgress else { return }
            cumulativeMagnification += event.magnification

        case .ended, .cancelled:
            guard gestureInProgress else { return }
            cumulativeMagnification += event.magnification
            evaluateGesture()
            resetGestureState()

        default:
            // For trackpads that don't report phase, use single-event detection
            if !gestureInProgress {
                cumulativeMagnification = event.magnification
                evaluateGesture()
                cumulativeMagnification = 0
            }
        }
    }

    private func evaluateGesture() {
        guard cumulativeMagnification < magnificationThreshold else { return }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) >= debounceInterval else { return }

        lastTriggerTime = now
        onTrigger()
    }

    private func resetGestureState() {
        gestureInProgress = false
        cumulativeMagnification = 0
    }
}
