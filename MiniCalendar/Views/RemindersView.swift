//
//  RemindersView.swift
//  MiniCalendar
//
//  Created by Claude Code on 2025/10/23.
//

import SwiftUI

struct ReminderWithDate: Identifiable {
    let id: String
    let reminder: CalendarReminder
    let date: Date?
}

struct RemindersView: View {
    @ObservedObject var calendarManager: CalendarManager
    @State private var contentHeight: CGFloat = 0
    @Namespace private var animation

    // Get all incomplete reminders (from CalendarManager, not limited by date range)
    var remindersWithDates: [ReminderWithDate] {
        return calendarManager.allIncompleteReminders.map { reminder in
            ReminderWithDate(
                id: reminder.id,
                reminder: reminder,
                date: reminder.dueDate
            )
        }
    }

    // Split into one-time and recurring
    var oneTimeReminders: [ReminderWithDate] {
        let today = Calendar.current.startOfDay(for: Date())
        return remindersWithDates
            .filter { !$0.reminder.isRecurring }
            .filter { item in
                // Exclude overdue one-time reminders
                guard let dueDate = item.reminder.dueDate else {
                    return true
                }
                let dueDateStart = Calendar.current.startOfDay(for: dueDate)
                return dueDateStart >= today
            }
            .sorted { r1, r2 in
                // Show undated reminders first
                if r1.reminder.dueDate == nil && r2.reminder.dueDate != nil {
                    return true
                }
                if r1.reminder.dueDate != nil && r2.reminder.dueDate == nil {
                    return false
                }
                // Both have dates - sort by date
                if let d1 = r1.reminder.dueDate, let d2 = r2.reminder.dueDate {
                    return d1 < d2
                }
                return false
            }
    }

    // Helper to check if reminder is not in the future
    func isNotFuture(_ item: ReminderWithDate) -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        guard let dueDate = item.reminder.dueDate else {
            return true // Show reminders without due date
        }
        let dueDateStart = Calendar.current.startOfDay(for: dueDate)
        return dueDateStart <= today
    }

    // Helper to sort reminders by date
    func sortedByDate(_ reminders: [ReminderWithDate]) -> [ReminderWithDate] {
        return reminders.sorted { r1, r2 in
            if let d1 = r1.reminder.dueDate, let d2 = r2.reminder.dueDate {
                return d1 < d2
            }
            if r1.reminder.dueDate != nil { return true }
            if r2.reminder.dueDate != nil { return false }
            return false
        }
    }

    // Helper to check if recurring reminder is overdue (entire date range is before today)
    func isRecurringOverdue(_ item: ReminderWithDate) -> Bool {
        guard let startDate = item.reminder.dueDate,
              let frequency = item.reminder.recurrenceFrequency,
              let interval = item.reminder.recurrenceInterval else {
            return false
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var endDate: Date?
        switch frequency {
        case "daily":
            endDate = calendar.date(byAdding: .day, value: interval, to: startDate)
        case "weekly":
            endDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate)
        case "monthly":
            endDate = calendar.date(byAdding: .month, value: interval, to: startDate)
        case "yearly":
            endDate = calendar.date(byAdding: .year, value: interval, to: startDate)
        default:
            return false
        }

        if let calculatedEndDate = endDate,
           let actualEndDate = calendar.date(byAdding: .day, value: -1, to: calculatedEndDate) {
            let actualEndDateStart = calendar.startOfDay(for: actualEndDate)
            return actualEndDateStart < today
        }

        return false
    }

    var overdueReminders: [ReminderWithDate] {
        let today = Calendar.current.startOfDay(for: Date())

        // Overdue one-time reminders
        let overdueOneTime = remindersWithDates
            .filter { !$0.reminder.isRecurring }
            .filter { item in
                guard let dueDate = item.reminder.dueDate else {
                    return false
                }
                let dueDateStart = Calendar.current.startOfDay(for: dueDate)
                return dueDateStart < today
            }

        // Overdue recurring reminders
        let overdueRecurring = remindersWithDates
            .filter { $0.reminder.isRecurring }
            .filter { isRecurringOverdue($0) }

        return sortedByDate(overdueOneTime + overdueRecurring)
    }

    var weeklyReminders: [ReminderWithDate] {
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { isNotFuture($0) }
                .filter { !isRecurringOverdue($0) }
                .filter { $0.reminder.recurrenceFrequency == "weekly" && $0.reminder.recurrenceInterval == 1 }
        )
    }

    var biweeklyReminders: [ReminderWithDate] {
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { isNotFuture($0) }
                .filter { !isRecurringOverdue($0) }
                .filter { $0.reminder.recurrenceFrequency == "weekly" && $0.reminder.recurrenceInterval == 2 }
        )
    }

    var monthlyReminders: [ReminderWithDate] {
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { isNotFuture($0) }
                .filter { !isRecurringOverdue($0) }
                .filter { $0.reminder.recurrenceFrequency == "monthly" && $0.reminder.recurrenceInterval == 1 }
        )
    }

    var quarterlyReminders: [ReminderWithDate] {
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { isNotFuture($0) }
                .filter { !isRecurringOverdue($0) }
                .filter { $0.reminder.recurrenceFrequency == "monthly" && $0.reminder.recurrenceInterval == 3 }
        )
    }

    var semiannuallyReminders: [ReminderWithDate] {
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { isNotFuture($0) }
                .filter { !isRecurringOverdue($0) }
                .filter { $0.reminder.recurrenceFrequency == "monthly" && $0.reminder.recurrenceInterval == 6 }
        )
    }

    var yearlyReminders: [ReminderWithDate] {
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { isNotFuture($0) }
                .filter { !isRecurringOverdue($0) }
                .filter { $0.reminder.recurrenceFrequency == "yearly" && $0.reminder.recurrenceInterval == 1 }
        )
    }

    var multiYearRemindersGrouped: [(interval: Int, reminders: [ReminderWithDate])] {
        let multiYearReminders = remindersWithDates
            .filter { $0.reminder.isRecurring }
            .filter { isNotFuture($0) }
            .filter { !isRecurringOverdue($0) }
            .filter { $0.reminder.recurrenceFrequency == "yearly" && ($0.reminder.recurrenceInterval ?? 1) > 1 }

        // Group by interval
        let grouped = Dictionary(grouping: multiYearReminders) { $0.reminder.recurrenceInterval ?? 2 }

        // Sort by interval and return as array of tuples
        return grouped.sorted { $0.key < $1.key }.map { (interval: $0.key, reminders: sortedByDate($0.value)) }
    }

    var futureReminders: [ReminderWithDate] {
        let today = Calendar.current.startOfDay(for: Date())
        return sortedByDate(
            remindersWithDates
                .filter { $0.reminder.isRecurring }
                .filter { item in
                    // Only show recurring reminders with due date in the future
                    guard let dueDate = item.reminder.dueDate else {
                        return false // Don't show reminders without due date here
                    }
                    let dueDateStart = Calendar.current.startOfDay(for: dueDate)
                    return dueDateStart > today
                }
        )
    }

    func getMultiYearLabel(interval: Int) -> String {
        let isChinese = SettingsManager.appLanguage == .chinese ||
                       (SettingsManager.appLanguage == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)

        if isChinese {
            return "每\(interval)年"
        } else {
            return "Every \(interval) Years"
        }
    }

    func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let dateYear = calendar.component(.year, from: date)
        let includesYear = currentYear != dateYear

        let formatter = DateFormatter()
        let isChinese = SettingsManager.appLanguage == .chinese ||
                       (SettingsManager.appLanguage == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)

        if isChinese {
            if includesYear {
                // Format: "26年6月1日" (remove leading zeros)
                let year = dateYear % 100 // Get last 2 digits
                let month = calendar.component(.month, from: date)
                let day = calendar.component(.day, from: date)
                return "\(year)年\(month)月\(day)日"
            } else {
                // Format: "6月1日" (remove leading zeros)
                let month = calendar.component(.month, from: date)
                let day = calendar.component(.day, from: date)
                return "\(month)月\(day)日"
            }
        } else {
            formatter.locale = Locale(identifier: "en_US")
            if includesYear {
                // Format: "Jun 1, 26"
                formatter.dateFormat = "MMM d, yy"
            } else {
                // Format: "Jun 1"
                formatter.dateFormat = "MMM d"
            }
            return formatter.string(from: date)
        }
    }

    // Helper function to determine if date string includes year
    func dateStringIncludesYear(_ dateString: String) -> Bool {
        let isChinese = SettingsManager.appLanguage == .chinese ||
                       (SettingsManager.appLanguage == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)

        if isChinese {
            // Chinese year format contains "年" character
            return dateString.contains("年")
        } else {
            // English year format contains comma
            return dateString.contains(",")
        }
    }

    func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "" }

        let formatter = DateFormatter()
        let isChinese = SettingsManager.appLanguage == .chinese ||
                       (SettingsManager.appLanguage == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)

        if isChinese {
            formatter.dateFormat = "a h:mm"
            formatter.locale = Locale(identifier: "zh_CN")
        } else {
            formatter.dateFormat = "h:mm a"
            formatter.locale = Locale(identifier: "en_US")
        }
        return formatter.string(from: date)
    }

    // Calculate date range for a recurring reminder occurrence (returns array with 2 lines)
    func getDateRangeLines(for item: ReminderWithDate) -> [String] {
        guard let startDate = item.reminder.dueDate,
              let frequency = item.reminder.recurrenceFrequency,
              let interval = item.reminder.recurrenceInterval else {
            if let date = item.date {
                return [formatDate(date)]
            }
            return []
        }

        // Calculate end date based on recurrence interval
        var endDate: Date?
        let calendar = Calendar.current

        switch frequency {
        case "daily":
            endDate = calendar.date(byAdding: .day, value: interval, to: startDate)
        case "weekly":
            endDate = calendar.date(byAdding: .weekOfYear, value: interval, to: startDate)
        case "monthly":
            endDate = calendar.date(byAdding: .month, value: interval, to: startDate)
        case "yearly":
            endDate = calendar.date(byAdding: .year, value: interval, to: startDate)
        default:
            if let date = item.date {
                return [formatDate(date)]
            }
            return []
        }

        // End date is one day before the next occurrence
        if let calculatedEndDate = endDate,
           let actualEndDate = calendar.date(byAdding: .day, value: -1, to: calculatedEndDate) {
            return ["\(formatDate(startDate)) -", formatDate(actualEndDate)]
        }

        if let date = item.date {
            return [formatDate(date)]
        }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if overdueReminders.isEmpty && oneTimeReminders.isEmpty && weeklyReminders.isEmpty && biweeklyReminders.isEmpty &&
               monthlyReminders.isEmpty && quarterlyReminders.isEmpty && semiannuallyReminders.isEmpty &&
               yearlyReminders.isEmpty && multiYearRemindersGrouped.isEmpty && futureReminders.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.green)
                    Text(LocalizationHelper.noRemindersToShow)
                        .font(.customSize(17))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // One-time reminders
                        if !oneTimeReminders.isEmpty {
                            Text(LocalizationHelper.oneTimeReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(oneTimeReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let date = item.date {
                                            let dateText = formatDate(date)
                                            Text(dateText)
                                                .font(.customSize(dateStringIncludesYear(dateText) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        } else {
                                            // Show "无日期/Undated" for reminders without dates
                                            let isChinese = SettingsManager.appLanguage == .chinese ||
                                                           (SettingsManager.appLanguage == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)
                                            Text(isChinese ? "无日期" : "Undated")
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Overdue reminders
                        if !overdueReminders.isEmpty {
                            if !oneTimeReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.overdueReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(overdueReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        if item.reminder.isRecurring {
                                            // Date range split into two lines for recurring
                                            let dateLines = getDateRangeLines(for: item)
                                            ForEach(0..<dateLines.count, id: \.self) { index in
                                                Text(dateLines[index])
                                                    .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                    .foregroundColor(.secondary)
                                            }
                                        } else if let date = item.date {
                                            // Single date for one-time
                                            let dateText = formatDate(date)
                                            Text(dateText)
                                                .font(.customSize(dateStringIncludesYear(dateText) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        } else {
                                            // Show "无日期/Undated" for reminders without dates
                                            let isChinese = SettingsManager.appLanguage == .chinese ||
                                                           (SettingsManager.appLanguage == .system && Locale.preferredLanguages.first?.hasPrefix("zh") == true)
                                            Text(isChinese ? "无日期" : "Undated")
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Weekly reminders
                        if !weeklyReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.weeklyReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(weeklyReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Bi-weekly reminders
                        if !biweeklyReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.biweeklyReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(biweeklyReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Monthly reminders
                        if !monthlyReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty || !biweeklyReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.monthlyReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(monthlyReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Quarterly reminders
                        if !quarterlyReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty || !biweeklyReminders.isEmpty || !monthlyReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.quarterlyReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(quarterlyReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Semi-annually reminders
                        if !semiannuallyReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty || !biweeklyReminders.isEmpty || !monthlyReminders.isEmpty || !quarterlyReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.semiannuallyReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(semiannuallyReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Yearly reminders
                        if !yearlyReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty || !biweeklyReminders.isEmpty || !monthlyReminders.isEmpty || !quarterlyReminders.isEmpty || !semiannuallyReminders.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.yearlyReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(yearlyReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Multi-year reminders (every 2+ years)
                        ForEach(multiYearRemindersGrouped, id: \.interval) { group in
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty || !biweeklyReminders.isEmpty || !monthlyReminders.isEmpty || !quarterlyReminders.isEmpty || !semiannuallyReminders.isEmpty || !yearlyReminders.isEmpty || multiYearRemindersGrouped.first?.interval != group.interval {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(getMultiYearLabel(interval: group.interval))
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(group.reminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }

                        // Future reminders
                        if !futureReminders.isEmpty {
                            if !overdueReminders.isEmpty || !oneTimeReminders.isEmpty || !weeklyReminders.isEmpty || !biweeklyReminders.isEmpty || !monthlyReminders.isEmpty || !quarterlyReminders.isEmpty || !semiannuallyReminders.isEmpty || !yearlyReminders.isEmpty || !multiYearRemindersGrouped.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            Text(LocalizationHelper.futureReminders)
                                .font(.customSize(14))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)

                            ForEach(futureReminders) { item in
                                HStack(alignment: .center, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        // Date range split into two lines
                                        let dateLines = getDateRangeLines(for: item)
                                        ForEach(0..<dateLines.count, id: \.self) { index in
                                            Text(dateLines[index])
                                                .font(.customSize(dateStringIncludesYear(dateLines[index]) ? 10 : 12))
                                                .foregroundColor(.secondary)
                                        }

                                        if item.reminder.hasTime, let dueDate = item.reminder.dueDate {
                                            Text(formatTime(dueDate))
                                                .font(.customSize(12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(width: 62, alignment: .leading)

                                    ReminderListItemView(reminder: item.reminder, hideTime: true, calendarManager: calendarManager)
                                }
                                .padding(.horizontal, 16)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                                .matchedGeometryEffect(id: item.id, in: animation)
                            }
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}
