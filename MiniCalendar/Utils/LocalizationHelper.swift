//
//  LocalizationHelper.swift
//  MiniCalendar
//
//  Created by Claude Code
//

import Foundation
import SwiftUI

struct LocalizationHelper {
    private static var isChinese: Bool {
        // Check user's manual language preference first
        let appLanguage = SettingsManager.appLanguage

        switch appLanguage {
        case .chinese:
            return true
        case .english:
            return false
        case .system:
            // Detect system language
            // Try preferredLanguages first (more reliable)
            if let preferredLanguage = Locale.preferredLanguages.first {
                return preferredLanguage.hasPrefix("zh")
            }
            // Fallback to current locale
            if let languageCode = Locale.current.language.languageCode?.identifier {
                return languageCode == "zh"
            }
            return false
        }
    }

    // Event strings
    static var allDay: String {
        isChinese ? "全天" : "All Day"
    }

    static var noEventsToday: String {
        isChinese ? "今天无日程" : "No events today"
    }

    // Reminder strings
    static var noDate: String {
        isChinese ? "无日期" : "No Date"
    }

    static var noTime: String {
        isChinese ? "无时间" : "No Time"
    }

    static var completed: String {
        isChinese ? "已完成" : "Completed"
    }

    static var reminders: String {
        isChinese ? "提醒事项" : "Reminders"
    }

    static var reminderLists: String {
        isChinese ? "提醒列表" : "Reminder Lists"
    }

    static var reminderListSelectionDescription: String {
        isChinese ? "选择要在 MiniCalendar 中显示的提醒列表" : "Select which reminder lists to display in MiniCalendar"
    }

    static var noRemindersToday: String {
        isChinese ? "今天无提醒事项" : "No reminders today"
    }

    static var showReminders: String {
        isChinese ? "显示提醒事项" : "Show Reminders"
    }

    static var noRemindersToShow: String {
        isChinese ? "没有未完成的提醒事项" : "No incomplete reminders"
    }

    static var calendarTab: String {
        isChinese ? "日历" : "Calendar"
    }

    static var remindersTab: String {
        isChinese ? "提醒" : "Reminders"
    }

    static var overdueReminders: String {
        isChinese ? "逾期" : "Overdue"
    }

    static var oneTimeReminders: String {
        isChinese ? "单次" : "One-time"
    }

    static var weeklyReminders: String {
        isChinese ? "每周" : "Weekly"
    }

    static var biweeklyReminders: String {
        isChinese ? "每两周" : "Bi-weekly"
    }

    static var monthlyReminders: String {
        isChinese ? "每月" : "Monthly"
    }

    static var quarterlyReminders: String {
        isChinese ? "每季" : "Quarterly"
    }

    static var semiannuallyReminders: String {
        isChinese ? "每半年" : "Semi-annually"
    }

    static var yearlyReminders: String {
        isChinese ? "每年" : "Yearly"
    }

    static var futureReminders: String {
        isChinese ? "将来" : "Future"
    }

    // Settings strings
    static var appSettings: String {
        isChinese ? "应用设置" : "App Settings"
    }

    static var basicSettings: String {
        isChinese ? "基本设置" : "Basic Settings"
    }

    static var calendars: String {
        isChinese ? "日历选择" : "Calendars"
    }

    static var calendarSelectionDescription: String {
        isChinese ? "选择要在 MiniCalendar 中显示的日历" : "Select which calendars to display in MiniCalendar"
    }

    static var about: String {
        isChinese ? "关于" : "About"
    }

    static var menuBarDisplay: String {
        isChinese ? "菜单栏显示" : "Menu Bar Display"
    }

    static var displayType: String {
        isChinese ? "显示类型:" : "Display Type:"
    }

    static var displayFormat: String {
        isChinese ? "显示格式:" : "Display Format:"
    }

    static var customFormat: String {
        isChinese ? "自定义格式:" : "Custom Format:"
    }

    static var formatReference: String {
        isChinese ? "格式化代码参考: yyyy(年), MM(月), d(日), E(星期), HH(24时), h(12时), m(分), s(秒), a(上午/下午)"
                  : "Format reference: yyyy(year), MM(month), d(day), E(weekday), HH(24h), h(12h), m(minute), s(second), a(AM/PM)"
    }

    static var calendarDisplay: String {
        isChinese ? "日历显示" : "Calendar Display"
    }

    static var weekStartsFrom: String {
        isChinese ? "星期开始于:" : "Week Starts From:"
    }

    static var alternativeCalendar: String {
        isChinese ? "其他日历:" : "Alternative Calendar:"
    }

    static var startup: String {
        isChinese ? "启动项" : "Startup"
    }

    static var launchAtLogin: String {
        isChinese ? "开机时自动启动" : "Launch at Login"
    }

    static var version: String {
        isChinese ? "版本" : "Version"
    }

    static var appDescription: String {
        isChinese ? "免费且开源的macOS菜单栏日历。"
                  : "A free and open-source mini menu bar calendar for macOS."
    }

    static var appCredit: String {
        "Original version from bylinxx, forked by Pingfan Hu."
    }

    // Menu strings
    static var settings: String {
        isChinese ? "设置" : "Settings"
    }

    static var checkForUpdates: String {
        isChinese ? "检查更新" : "Check for Updates"
    }

    static var quit: String {
        isChinese ? "退出" : "Quit"
    }

    // DisplayMode enum strings
    static var displayModeIcon: String {
        isChinese ? "图标" : "Icon"
    }

    static var displayModeDate: String {
        isChinese ? "日期" : "Date"
    }

    static var displayModeTime: String {
        isChinese ? "时间" : "Time"
    }

    static var displayModeCustom: String {
        isChinese ? "自定义" : "Custom"
    }

    // AlternativeCalendarType enum strings
    static var alternativeCalendarNone: String {
        isChinese ? "无" : "None"
    }

    static var alternativeCalendarChinese: String {
        isChinese ? "农历（简中）" : "Lunar (Simplified Chinese)"
    }

    // Language settings
    static var language: String {
        isChinese ? "语言" : "Language"
    }

    static var languageSystem: String {
        isChinese ? "跟随系统" : "Follow System"
    }

    // WeekStartDay enum strings
    static var weekStartSystem: String {
        isChinese ? "跟随系统" : "Follow System"
    }

    static var weekStartSunday: String {
        isChinese ? "星期天" : "Sunday"
    }

    static var weekStartMonday: String {
        isChinese ? "星期一" : "Monday"
    }

    // Appearance mode strings
    static var appearance: String {
        isChinese ? "外观" : "Appearance"
    }

    static var appearanceSystem: String {
        isChinese ? "跟随系统" : "Follow System"
    }

    static var appearanceLight: String {
        isChinese ? "浅色" : "Light"
    }

    static var appearanceDark: String {
        isChinese ? "深色" : "Dark"
    }
}
