//
//  AppDelegate.swift
//  MiniCalendar
//
//  Created by ruihelin on 2025/9/28.
//

import SwiftUI
import AppKit
import Combine
import CoreText
import Sparkle

class AppDelegate: NSObject,NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?

    private var calendarIcon = CalendarIcon()
    private var currentIconOutput: String?
    private var cancellables = Set<AnyCancellable>()
    private var keyboardEventMonitor: Any?
    private var mouseEventMonitor: Any?
    private var calendarManager: CalendarManager?
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register bundled custom font
        registerCustomFont()

        // Apply appearance mode
        applyAppearanceMode()

        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // Initialize shared CalendarManager once
        Task { @MainActor in
            calendarManager = CalendarManager()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        keyboardEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.characters == "," {
                self?.showSettingsWindow()
                return nil
            }
            return event
        }

        calendarIcon.$displayOutput
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] output in
                        self?.currentIconOutput = output
                        self?.refreshStatusButton()
                    }
                    .store(in: &cancellables)

        popover = NSPopover()
        updatePopoverBehavior()

        // Swap the icon between its idle (outlined) and active (filled) state
        // whenever the popover opens or closes. The popover is transient, so
        // the system can close it on its own — these notifications cover
        // every close path. The will- variants fire before the open/close
        // animation, so the icon inverts the moment the user clicks instead
        // of when the animation finishes.
        NotificationCenter.default.addObserver(self, selector: #selector(popoverWillShow), name: NSPopover.willShowNotification, object: popover)
        NotificationCenter.default.addObserver(self, selector: #selector(popoverWillClose), name: NSPopover.willCloseNotification, object: popover)

        NotificationCenter.default.addObserver(self, selector: #selector(closePopoverIfNotPinned), name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePinStateChanged), name: NSNotification.Name("PopoverPinStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppearanceModeChanged), name: NSNotification.Name("AppearanceModeChanged"), object: nil)
    }

    deinit {
        // Clean up event monitors
        if let monitor = keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        // Clean up Combine subscriptions
        cancellables.removeAll()
    }

    // MARK: - Status bar icon

    /// Idle icon: outlined badge with a solid calendar glyph.
    static let normalIcon = makeStatusIcon(active: false)
    /// Active icon (panel open): solid badge with a knocked-out glyph — the
    /// same inversion the system input-menu badge uses while engaged.
    static let activeIcon = makeStatusIcon(active: true)

    /// Rounded-rect badge with a mini calendar (header bar + 3x2 date dots),
    /// drawn as a template image — the same construction and 22x16 frame as
    /// the system text-input-menu badge (the "A" icon) and MiniNotes' pen
    /// badge, so the icons read as one family. `active: false` strokes the
    /// border and fills the glyph; `active: true` fills the badge and knocks
    /// the glyph out. Vector paths are rendered per backing scale, so the
    /// glyph stays crisp at every scaled resolution.
    private static func makeStatusIcon(active: Bool) -> NSImage {
        let canvas = NSSize(width: 22, height: 16)
        // Border thickness and outer corner radius measured from the system
        // input-menu badge (2 px border, 11 px radius at 2x).
        let border: CGFloat = 1.0
        let outerRadius: CGFloat = 5.5
        let image = NSImage(size: canvas, flipped: false) { _ in
            if active {
                NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 22, height: 16),
                             xRadius: outerRadius, yRadius: outerRadius).fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
            } else {
                let inset = border / 2
                let frame = NSRect(x: inset, y: inset, width: 22 - border, height: 16 - border)
                let ring = NSBezierPath(roundedRect: frame, xRadius: outerRadius - inset, yRadius: outerRadius - inset)
                ring.lineWidth = border
                ring.stroke()
            }

            // mini calendar: 3x2 grid of date dots below a header bar,
            // centered in the badge
            let dot: CGFloat = 2.3, gapX: CGFloat = 1.25, gapY: CGFloat = 1.2
            let gridW = 3 * dot + 2 * gapX
            let headerH: CGFloat = 2.0
            let glyphH = headerH + gapY + 2 * dot + gapY
            let x0 = (22 - gridW) / 2
            let y0 = (16 - glyphH) / 2
            for row in 0..<2 {
                for col in 0..<3 {
                    let r = NSRect(x: x0 + CGFloat(col) * (dot + gapX),
                                   y: y0 + CGFloat(row) * (dot + gapY),
                                   width: dot, height: dot)
                    NSBezierPath(roundedRect: r, xRadius: 0.55, yRadius: 0.55).fill()
                }
            }
            let header = NSRect(x: x0, y: y0 + 2 * (dot + gapY), width: gridW, height: headerH)
            NSBezierPath(roundedRect: header, xRadius: 0.8, yRadius: 0.8).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Calendar"
        return image
    }

    /// Whether the popover is engaged from the user's point of view. Tracked
    /// explicitly (rather than reading `popover.isShown`) because the icon
    /// flips on the will-show/will-close notifications, when `isShown` still
    /// has its old value.
    private var popoverEngaged = false

    /// Applies the current display mode to the status button: the badge icon
    /// (idle or active depending on the popover) in icon mode, or the date
    /// text otherwise.
    private func refreshStatusButton() {
        guard let button = statusItem.button, let output = currentIconOutput else { return }
        if output == CalendarIcon.iconModeIdentifier {
            button.image = popoverEngaged ? Self.activeIcon : Self.normalIcon
            button.title = ""
        } else {
            button.title = output
            button.image = nil
        }
    }

    @objc private func popoverWillShow() {
        popoverEngaged = true
        refreshStatusButton()
    }

    @objc private func popoverWillClose() {
        popoverEngaged = false
        refreshStatusButton()
    }

    @objc func statusItemClicked(sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: LocalizationHelper.settings, action: #selector(showSettingsWindow), keyEquivalent: ","))

            // Add "Check for Updates" menu item
            if let updaterController = updaterController {
                let updateMenuItem = NSMenuItem(title: LocalizationHelper.checkForUpdates, action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
                updateMenuItem.target = updaterController
                menu.addItem(updateMenuItem)
            }

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: LocalizationHelper.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover()
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                updatePopoverBehavior()

                // Ensure CalendarManager is initialized before showing popover
                if calendarManager == nil {
                    Task { @MainActor in
                        calendarManager = CalendarManager()
                        showPopoverContent(button: button)
                    }
                } else {
                    // Reset calendar to today when opening popover
                    Task { @MainActor in
                        calendarManager?.goToCurrentMonth()
                    }
                    showPopoverContent(button: button)
                }
            }
        }
    }

    private func showPopoverContent(button: NSStatusBarButton) {
        guard let manager = calendarManager else { return }

        let hostingController = NSHostingController(rootView: ContentView(calendarManager: manager))
        hostingController.sizingOptions = .intrinsicContentSize
        popover.contentViewController = hostingController

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        
        // Start monitoring for clicks outside the popover
        startMouseEventMonitor()
    }
    
    private func startMouseEventMonitor() {
        // Remove existing monitor if any
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
        
        // Only monitor if popover is not pinned
        guard !SettingsManager.isPopoverPinned else { return }
        
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.popover.isShown else { return }
            
            // Check if click is outside both the popover and the status bar button
            if let popoverWindow = self.popover.contentViewController?.view.window,
               let statusButton = self.statusItem.button {
                
                let clickLocation = event.locationInWindow
                
                // Convert click location to screen coordinates
                guard let eventWindow = event.window else {
                    // Click was outside any window, close the popover
                    self.closePopover()
                    return
                }
                
                let screenLocation = eventWindow.convertPoint(toScreen: clickLocation)
                
                // Check if click is inside popover
                let popoverFrame = popoverWindow.frame
                if popoverFrame.contains(screenLocation) {
                    return
                }
                
                // Check if click is inside status bar button
                if let buttonWindow = statusButton.window {
                    let buttonFrameInWindow = statusButton.convert(statusButton.bounds, to: nil)
                    let buttonFrameInScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
                    if buttonFrameInScreen.contains(screenLocation) {
                        return
                    }
                }
                
                // Click was outside both popover and button, close it
                self.closePopover()
            }
        }
    }
    
    private func stopMouseEventMonitor() {
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
            mouseEventMonitor = nil
        }
    }

    @objc func closePopover() {
        popover.performClose(nil)
        stopMouseEventMonitor()
    }

    @objc func closePopoverIfNotPinned() {
        if !SettingsManager.isPopoverPinned {
            popover.performClose(nil)
            stopMouseEventMonitor()
        }
    }

    @objc func handlePinStateChanged() {
        updatePopoverBehavior()
        
        // Update mouse event monitoring based on pin state
        if SettingsManager.isPopoverPinned {
            stopMouseEventMonitor()
        } else if popover.isShown {
            startMouseEventMonitor()
        }
    }

    @objc func handleAppearanceModeChanged() {
        applyAppearanceMode()
        // Force popover to update appearance if it's currently shown
        if popover.isShown, let window = popover.contentViewController?.view.window {
            window.appearance = NSApp.appearance
        }
    }

    private func updatePopoverBehavior() {
        if SettingsManager.isPopoverPinned {
            popover.behavior = .semitransient
        } else {
            popover.behavior = .transient
        }
    }
    
    @objc func showSettingsWindow() {
        guard let calendarManager = calendarManager else { return }

        if settingsWindow == nil {
            let settingsView = SettingsView(calendarManager: calendarManager)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 525, height: 375),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: settingsView)
            settingsWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func registerCustomFont() {
        guard let fontURL = Bundle.main.url(forResource: "LXGWWenKai-Medium", withExtension: "ttf") else {
            print("❌ Custom font file not found in bundle")
            return
        }

        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)

        if success {
            print("✅ Custom font registered successfully: \(fontURL.lastPathComponent)")
        } else {
            if let error = error?.takeRetainedValue() {
                print("❌ Failed to register custom font: \(error)")
            }
        }
    }

    private func applyAppearanceMode() {
        let appearanceMode = SettingsManager.appearanceMode

        switch appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
