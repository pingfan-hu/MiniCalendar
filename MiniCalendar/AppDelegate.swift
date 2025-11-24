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
    private var cancellables = Set<AnyCancellable>()
    private var keyboardEventMonitor: Any?
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
                        guard let button = self?.statusItem.button else { return }

                        if output == CalendarIcon.iconModeIdentifier {
                            let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
                            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Calendar")?.withSymbolConfiguration(config)
                            button.title = ""
                        } else {
                            button.title = output
                            button.image = nil
                        }
                    }
                    .store(in: &cancellables)

        popover = NSPopover()
        updatePopoverBehavior()

        NotificationCenter.default.addObserver(self, selector: #selector(closePopoverIfNotPinned), name: NSApplication.didResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePinStateChanged), name: NSNotification.Name("PopoverPinStateChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAppearanceModeChanged), name: NSNotification.Name("AppearanceModeChanged"), object: nil)
    }

    deinit {
        // Clean up event monitor
        if let monitor = keyboardEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        // Clean up notification observers
        NotificationCenter.default.removeObserver(self)
        // Clean up Combine subscriptions
        cancellables.removeAll()
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
    }

    @objc func closePopover() {
        popover.performClose(nil)
    }

    @objc func closePopoverIfNotPinned() {
        if !SettingsManager.isPopoverPinned {
            popover.performClose(nil)
        }
    }

    @objc func handlePinStateChanged() {
        updatePopoverBehavior()
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
