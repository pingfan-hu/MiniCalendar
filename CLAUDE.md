# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MiniCalendar is a free and open-source macOS menu bar calendar application built with SwiftUI. It displays in the menu bar only (no main window, `LSUIElement = YES`), supports Chinese lunar calendar, 24 solar terms, and integrates with macOS Calendar events and Reminders.

- **Minimum macOS**: 14.6
- **Swift**: 5.0 with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
- **Bundle ID**: `com.pingfan.minicalendar`
- **Single external dependency**: Sparkle (v2.8.1+) for auto-updates via SPM

## Build & Run

```bash
# Debug build
xcodebuild -project MiniCalendar.xcodeproj -scheme MiniCalendar build

# Release build with clean (for distribution)
xcodebuild -project MiniCalendar.xcodeproj -scheme MiniCalendar -configuration Release clean build
```

Build output: `/Users/pingfan/Library/Developer/Xcode/DerivedData/MiniCalendar-*/Build/Products/Release/MiniCalendar.app`

There are **no tests, no linter, and no CI/CD**. The project has a single target and single scheme.

**Release Process**: See `RELEASE.md` for signing, notarizing, and publishing to GitHub.

## Architecture

### Source Layout (`MiniCalendar/`)

```
MiniCalendarApp.swift    - App entry point (minimal Scene)
AppDelegate.swift        - Menu bar status item, popover, settings window, Sparkle updater (~306 lines)
Core/
  CalendarManager.swift  - Central @MainActor ObservableObject: EventKit integration, month grid, events/reminders (~754 lines)
  SettingsManager.swift  - @AppStorage-based settings with DisplayMode, AppearanceMode, WeekStartDay enums
  LaunchAtLoginManager.swift - SMAppService wrapper (macOS 13+)
Models/                  - CalendarDay, CalendarEvent, CalendarReminder, CalendarIcon, SettingsType
Views/                   - 15 SwiftUI views (see View Structure below)
Utils/                   - DateHelper, HolidayHelper, SolarTermHelper, UrlHelper, LocalizationHelper, Extensions
Assets.xcassets/         - App icons, accent color, GitHub logo
LXGWWenKai-Medium.ttf   - Bundled custom font
Info.plist               - App configuration including Sparkle feed URL and permission descriptions
MiniCalendar.entitlements - Sandbox=false, calendar+reminders access
```

### Data Flow

`AppDelegate` creates the `NSStatusItem` and `NSPopover`. Left-click shows the popover containing `ContentView`, right-click shows a menu (Settings, Check for Updates, Quit). `ContentView` holds a `CalendarManager` (the single source of truth for all calendar/reminder data) and a `SettingsManager`, passing them to child views via `@EnvironmentObject`.

`CalendarManager` owns an `EKEventStore`, loads month data as a 42-day grid (6 weeks), fetches events grouped by day, and fetches all incomplete reminders. It auto-refreshes on `.EKEventStoreChanged` notifications.

### View Structure

- **ContentView**: Container with tab picker switching between "Events" and "Reminders" tabs
- **CalendarView**: Month grid with lunar dates, holidays, solar terms, event dot indicators
- **EventListView** → **EventListItemView** → **EventDetailView**: Day's events with popover detail
- **RemindersView** → **ReminderListItemView** → **ReminderDetailView**: All incomplete reminders grouped by recurrence category (Overdue, One-time, Weekly, Monthly, etc.)
- **SettingsView**: Tab-based settings (SettingsIconView, SettingsCalendarView, SettingsReminderListView, SettingsLaunchAtLoginView, SettingsAboutView)

### Localization

No .strings/.lproj files. All strings are in `LocalizationHelper.swift` as static computed properties using ternary operators on an `isChinese` boolean. Languages: Chinese (zh-Hans) and English.

## Key Technical Details

### Gotchas and Important Constraints
- **Time column width**: Event/reminder list items use a 62-point wide time column — this is critical for Chinese AM/PM prefixes ("上午"/"下午"). Do not reduce.
- **EventListItemView debounce**: Includes debounce logic to prevent popover re-opening immediately after dismissal. Respect this pattern.
- **Calendar grid**: Always 42 days (6 complete weeks) with padding from adjacent months.
- **Week start**: Configurable via `SettingsManager.weekStartDay`. Custom `Calendar.mondayBased` extension in `Extensions.swift`. All calendar calculations must use this configurable calendar.
- **Lunar calendar**: Uses `Calendar(identifier: .chinese)` for lunar date calculations.
- **Hidden calendars/reminders**: Stored in UserDefaults as "HiddenCalendarIDs" and "HiddenReminderListIDs".

### Menu Bar & UI
- Status item updates via Combine publisher with 1-second timer
- Popover: `.transient` (auto-dismiss) or `.semitransient` (pinned via `SettingsManager.isPopoverPinned`)
- Appearance mode (light/dark/system) applied app-wide

### Custom Font
- "LXGWWenKai-Medium" registered programmatically in `AppDelegate.registerCustomFont()` via `CTFontManagerRegisterFontsForURL`
- Requires `ATSApplicationFontsPath = "."` in Info.plist
- Font extensions in `Extensions.swift` provide semantic sizes with automatic fallback to system font

### Sparkle Auto-Update
- `SPUStandardUpdaterController` initialized in `AppDelegate.applicationDidFinishLaunching`
- Feed URL: `https://raw.githubusercontent.com/pingfan-hu/MiniCalendar/main/appcast.xml`
- "Check for Updates" menu item in right-click menu
- Auto-checks daily (86400 second interval)

### Permissions & Entitlements
- **Critical**: App must be signed with `MiniCalendar.entitlements` for calendar/reminders access
- Entitlements: `app-sandbox = false`, `personal-information.calendars = true`, `personal-information.reminders = true`
- Info.plist requires `NSCalendarsUsageDescription`, `NSCalendarsFullAccessUsageDescription`, `NSRemindersUsageDescription`, `NSRemindersFullAccessUsageDescription`
