//
//  LaunchpadPanel.swift
//  launchlite
//
//  Created on 2026/3/2.
//

import AppKit

/// A borderless, full-screen NSPanel used as the Launchpad overlay.
/// Floats above all windows with a blurred background effect.
class LaunchpadPanel: NSPanel {

    /// Called when the panel is dismissed (via Esc or clicking empty area).
    var onDismiss: (() -> Void)?

    /// The visual effect view providing the blur background.
    private let blurView: NSVisualEffectView = {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.appearance = NSAppearance(named: .darkAqua)
        view.blendingMode = .behindWindow
        view.state = .active
        view.autoresizingMask = [.width, .height]
        return view
    }()

    /// Dark overlay to simulate the native Launchpad dark tone.
    private let darkOverlay: NSView = {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35).cgColor
        view.autoresizingMask = [.width, .height]
        return view
    }()

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Use a level above all standard windows (popUpMenu=101) but below
        // the system drag window level (kCGDraggingWindowLevel=500) so that
        // drag previews render above the panel during drag-and-drop.
        level = .init(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Add blur background and dark overlay
        blurView.frame = contentRect
        contentView?.addSubview(blurView, positioned: .below, relativeTo: nil)
        darkOverlay.frame = contentRect
        contentView?.addSubview(darkOverlay, positioned: .above, relativeTo: blurView)
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Esc key (keyCode 53) closes the panel
        if event.keyCode == 53 {
            dismiss()
        } else {
            super.keyDown(with: event)
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Check if the click is on the background (not on a subview of the hosted content)
        guard let contentView = contentView else { return }

        let location = event.locationInWindow
        let hitView = contentView.hitTest(location)

        // If the hit view is the content view itself or the blur view,
        // the user clicked on empty area - close the panel
        if hitView === contentView || hitView === blurView || hitView === darkOverlay {
            dismiss()
        }
    }

    /// Dismisses the panel and notifies the delegate via onDismiss callback.
    func dismiss() {
        onDismiss?()
    }
}
