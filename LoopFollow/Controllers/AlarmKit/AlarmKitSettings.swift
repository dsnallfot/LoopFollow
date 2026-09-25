import Foundation

/// The period is evaluated at delivery time in the user's current time zone.
enum AlarmKitPeriod: String, CaseIterable {
    case always, never, day, night

    var title: String {
        switch self {
        case .always: return "Alltid"
        case .never: return "Aldrig"
        case .day: return "Dag"
        case .night: return "Natt"
        }
    }

    func includes(minute: Int, dayStart: Int, nightStart: Int) -> Bool {
        if self == .always { return true }
        if self == .never { return false }
        // Equal boundaries have no day interval; night covers the whole day.
        let isDay = dayStart < nightStart
            ? minute >= dayStart && minute < nightStart
            : dayStart > nightStart && (minute >= dayStart || minute < nightStart)
        return self == .day ? isDay : !isDay
    }
}

enum AlarmKitSettings {
    static let enabled = UserDefaultsValue<Bool>(key: "alarmKitEnabled", default: false)
    static let dayStart = UserDefaultsValue<Int>(key: "alarmKitDayStart", default: 7 * 60)
    static let nightStart = UserDefaultsValue<Int>(key: "alarmKitNightStart", default: 22 * 60)

    static func minute(of date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }

    static func date(for minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }
}

/// Stable identifiers; display labels are never used as persistence keys.
enum AlarmKitAlarm: String, CaseIterable, Codable {
    case urgentLow, low, high, urgentHigh, fastDrop, fastRise, temporary, missedReading, notLooping, battery, sage, cage, pump, cob, iob, missedBolus

    var settingsName: String {
        switch self {
        case .urgentLow: return "Akut låg"
        case .low: return "Låg"
        case .high: return "Hög"
        case .urgentHigh: return "Akut hög"
        case .fastDrop: return "Sjunker snabbt"
        case .fastRise: return "Stiger snabbt"
        case .temporary: return "Tillfälligt"
        case .missedReading: return "Saknar värden"
        case .notLooping: return "Loopar inte"
        case .battery: return "Lågt batteri"
        case .sage: return "Sensorbyte"
        case .cage: return "Pumpbyte"
        case .pump: return "Reservoar"
        case .cob: return "COB"
        case .iob: return "IOB"
        case .missedBolus: return "Missad bolus"
        }
    }

    var label: String {
        switch self {
        case .urgentLow: return "🆘 Akut lågt!"
        case .low: return "🔴 Lågt socker"
        case .high: return "🟣 Högt socker"
        case .urgentHigh: return "⚠️ Akut högt!"
        case .fastDrop: return "⏬ Sjunker snabbt"
        case .fastRise: return "⏫ Stiger snabbt"
        case .temporary: return "⚠️ Tillfällig varning"
        case .missedReading: return "⚠️ Inga värden"
        case .notLooping: return "❌ Loop ej aktiv!"
        case .battery: return "🪫 Låg batterinivå"
        case .sage: return "⏰ Påminnelse sensorbyte"
        case .cage: return "⏰ Påminnelse pumpbyte"
        case .pump: return "⚠️ Låg insulinnivå"
        case .cob: return "🥨 COB Varning"
        case .iob: return "💉 IOB Varning"
        case .missedBolus: return "⚠️ Missad måltidsbolus"
        }
    }

    static func from(label: String) -> Self? {
        let plain = label.replacingOccurrences(of: " AlarmKit", with: "")
            .replacingOccurrences(of: " (Comp. low?)", with: "")
        if plain == "⚠️ Snart akut låg!" { return .urgentLow }
        return allCases.first { $0.label == plain }
    }

    private static let switches = Dictionary(uniqueKeysWithValues: allCases.map {
        ($0, UserDefaultsValue<Bool>(key: "alarmKit.\($0.rawValue).enabled", default: false))
    })
    private static let periods = Dictionary(uniqueKeysWithValues: allCases.map {
        ($0, UserDefaultsValue<String>(key: "alarmKit.\($0.rawValue).period", default: AlarmKitPeriod.always.rawValue))
    })
    var enabled: UserDefaultsValue<Bool> { Self.switches[self]! }
    var periodValue: UserDefaultsValue<String> { Self.periods[self]! }
    var period: AlarmKitPeriod { AlarmKitPeriod(rawValue: periodValue.value) ?? .never }

    func usesAlarmKit(at date: Date = Date()) -> Bool {
        AlarmKitSettings.enabled.value && enabled.value && period.includes(
            minute: AlarmKitSettings.minute(of: date),
            dayStart: AlarmKitSettings.dayStart.value, nightStart: AlarmKitSettings.nightStart.value
        )
    }

    var active: UserDefaultsValue<Bool> {
        switch self {
        case .urgentLow: return UserDefaultsRepository.alertUrgentLowActive
        case .low: return UserDefaultsRepository.alertLowActive
        case .high: return UserDefaultsRepository.alertHighActive
        case .urgentHigh: return UserDefaultsRepository.alertUrgentHighActive
        case .fastDrop: return UserDefaultsRepository.alertFastDropActive
        case .fastRise: return UserDefaultsRepository.alertFastRiseActive
        case .temporary: return UserDefaultsRepository.alertTemporaryActive
        case .missedReading: return UserDefaultsRepository.alertMissedReadingActive
        case .notLooping: return UserDefaultsRepository.alertNotLoopingActive
        case .battery: return UserDefaultsRepository.alertBatteryActive
        case .sage: return UserDefaultsRepository.alertSAGEActive
        case .cage: return UserDefaultsRepository.alertCAGEActive
        case .pump: return UserDefaultsRepository.alertPump
        case .cob: return UserDefaultsRepository.alertCOB
        case .iob: return UserDefaultsRepository.alertIOB
        case .missedBolus: return UserDefaultsRepository.alertMissedBolusActive
        }
    }

    var snoozed: UserDefaultsValue<Bool>? {
        switch self {
        case .urgentLow: return UserDefaultsRepository.alertUrgentLowIsSnoozed
        case .low: return UserDefaultsRepository.alertLowIsSnoozed
        case .high: return UserDefaultsRepository.alertHighIsSnoozed
        case .urgentHigh: return UserDefaultsRepository.alertUrgentHighIsSnoozed
        case .fastDrop: return UserDefaultsRepository.alertFastDropIsSnoozed
        case .fastRise: return UserDefaultsRepository.alertFastRiseIsSnoozed
        case .temporary: return nil
        case .missedReading: return UserDefaultsRepository.alertMissedReadingIsSnoozed
        case .notLooping: return UserDefaultsRepository.alertNotLoopingIsSnoozed
        case .battery: return UserDefaultsRepository.alertBatteryIsSnoozed
        case .sage: return UserDefaultsRepository.alertSAGEIsSnoozed
        case .cage: return UserDefaultsRepository.alertCAGEIsSnoozed
        case .pump: return UserDefaultsRepository.alertPumpIsSnoozed
        case .cob: return UserDefaultsRepository.alertCOBIsSnoozed
        case .iob: return UserDefaultsRepository.alertIOBIsSnoozed
        case .missedBolus: return UserDefaultsRepository.alertMissedBolusIsSnoozed
        }
    }

    var snoozedUntil: UserDefaultsValue<Date?>? {
        switch self {
        case .urgentLow: return UserDefaultsRepository.alertUrgentLowSnoozedTime
        case .low: return UserDefaultsRepository.alertLowSnoozedTime
        case .high: return UserDefaultsRepository.alertHighSnoozedTime
        case .urgentHigh: return UserDefaultsRepository.alertUrgentHighSnoozedTime
        case .fastDrop: return UserDefaultsRepository.alertFastDropSnoozedTime
        case .fastRise: return UserDefaultsRepository.alertFastRiseSnoozedTime
        case .temporary: return nil
        case .missedReading: return UserDefaultsRepository.alertMissedReadingSnoozedTime
        case .notLooping: return UserDefaultsRepository.alertNotLoopingSnoozedTime
        case .battery: return UserDefaultsRepository.alertBatterySnoozedTime
        case .sage: return UserDefaultsRepository.alertSAGESnoozedTime
        case .cage: return UserDefaultsRepository.alertCAGESnoozedTime
        case .pump: return UserDefaultsRepository.alertPumpSnoozedTime
        case .cob: return UserDefaultsRepository.alertCOBSnoozedTime
        case .iob: return UserDefaultsRepository.alertIOBSnoozedTime
        case .missedBolus: return UserDefaultsRepository.alertMissedBolusSnoozedTime
        }
    }

    var defaultSnoozeSeconds: TimeInterval {
        switch self {
        case .urgentLow: return TimeInterval(UserDefaultsRepository.alertUrgentLowSnooze.value) * 60
        case .low: return TimeInterval(UserDefaultsRepository.alertLowSnooze.value) * 60
        case .high: return TimeInterval(UserDefaultsRepository.alertHighSnooze.value) * 60
        case .urgentHigh: return TimeInterval(UserDefaultsRepository.alertUrgentHighSnooze.value) * 60
        case .fastDrop: return TimeInterval(UserDefaultsRepository.alertFastDropSnooze.value) * 60
        case .fastRise: return TimeInterval(UserDefaultsRepository.alertFastRiseSnooze.value) * 60
        case .temporary: return 0
        case .missedReading: return TimeInterval(UserDefaultsRepository.alertMissedReadingSnooze.value) * 60
        case .notLooping: return TimeInterval(UserDefaultsRepository.alertNotLoopingSnooze.value) * 60
        case .battery: return TimeInterval(UserDefaultsRepository.alertBatterySnoozeHours.value) * 3600
        case .sage: return TimeInterval(UserDefaultsRepository.alertSAGESnooze.value) * 3600
        case .cage: return TimeInterval(UserDefaultsRepository.alertCAGESnooze.value) * 3600
        case .pump: return TimeInterval(UserDefaultsRepository.alertPumpSnoozeHours.value) * 3600
        case .cob: return TimeInterval(UserDefaultsRepository.alertCOBSnoozeHours.value) * 3600
        case .iob: return TimeInterval(UserDefaultsRepository.alertIOBSnoozeHours.value) * 3600
        case .missedBolus: return TimeInterval(UserDefaultsRepository.alertMissedBolusSnooze.value) * 60
        }
    }

    func isSnoozed(at date: Date = Date()) -> Bool {
        guard snoozed?.value == true else { return false }
        return (snoozedUntil?.value ?? .distantFuture) > date
    }

    func acknowledge(at date: Date = Date()) {
        if self == .temporary {
            active.value = false // This is a one-shot alarm, with no standard snooze interval.
        } else {
            let until = date.addingTimeInterval(defaultSnoozeSeconds)
            // A delayed system intent must not shorten a snooze already extended in the app.
            snoozedUntil?.value = max(isSnoozed(at: date) ? (snoozedUntil?.value ?? until) : until, until)
            snoozed?.value = true
        }
    }
}
