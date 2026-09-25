import Foundation
import Combine

class AlarmViewModel {
        let categoryOptions = ["Hög/Låg", "Trend", "Trio", "Teknik", "Övrigt"]

        let alertBGOptions = ["Akut låg", "Låg", "Hög", "Akut hög"]
        let alertExtraBGOptions = ["Sjunker snabbt", "Stiger snabbt", "Tillfälligt"]
        let alertSystemOptions = ["Saknar värden", "Loopar inte", "Lågt batteri"]
        let alertHardwareOptions = ["Sensorbyte", "Pumpbyte", "Reservoar"]
        let alertOtherOptions = ["COB", "IOB", "Missad bolus"]

    // State för UI
    @Published var selectedCategoryIndex: Int = 0
    @Published var selectedSubCategoryIndex: Int = 0 // Hanterar logiken mellan bgAlerts, otherAlerts etc.

    // Data Source Snapshot Data
    var sections: [AlarmSection] = []

    // Mockup för datan (Här anropar du din UserDefaultsRepository)
    // I din kod: UserDefaultsRepository.shared...

    // MARK: - Logik för att bygga vyn
    func updateSnapshotData() {
        sections = []

        // 1. Globala inställningar visas ofta alltid
        sections.append(.alarmKitSettings)
        sections.append(.globalSettings)

        // 2. Hämta namnet på det valda larmet baserat på huvudkategori och underkategori
        let activeAlarmName: String
        switch selectedCategoryIndex {
        case 0: // BG Alerts
            activeAlarmName = alertBGOptions[selectedSubCategoryIndex]
        case 1: // Extra BG Alerts
            activeAlarmName = alertExtraBGOptions[selectedSubCategoryIndex]
        case 2: // Trio Alerts
            activeAlarmName = alertSystemOptions[selectedSubCategoryIndex]
        case 3: // Hardware Alerts
            activeAlarmName = alertHardwareOptions[selectedSubCategoryIndex]
        case 4: // Other Alerts
            activeAlarmName = alertOtherOptions[selectedSubCategoryIndex]
        default:
            activeAlarmName = ""
        }

        if !activeAlarmName.isEmpty {
            sections.append(.specificAlarm("\(activeAlarmName)"))
        }

        // 3. Nattinställningar
        sections.append(.nightSettings)
    }

    // MARK: - Helpers to get rows for a section
    func rows(for section: AlarmSection) -> [AlarmRow] {
        switch section {
        case .categorySelection:
            return [.segmentControl]

        case .alarmKitSettings:
            return [
                .toggle(title: "Tillåt AlarmKit", isOn: AlarmKitSettings.enabled.value, id: "alarmKitEnabled"),
                .action(title: "Behörighet i iOS inställningar", id: "alarmKitPermission"),
                .dateValue(title: "AlarmKit dagtid", date: AlarmKitSettings.date(for: AlarmKitSettings.dayStart.value), id: "alarmKitDayStart"),
                .dateValue(title: "AlarmKit nattid", date: AlarmKitSettings.date(for: AlarmKitSettings.nightStart.value), id: "alarmKitNightStart")
            ]

        case .globalSettings:
            // Hämtar värden från UserDefaultsRepository för de globala sektionerna
            let storedSnoozeTime = UserDefaultsRepository.alertSnoozeAllTime.value
            let isSnoozed = UserDefaultsRepository.alertSnoozeAllIsSnoozed.value
            // Om toggeln är av vill vi *inte* visa sista datumet, precis som i gamla Eureka-vyn
            let snoozeTime = isSnoozed ? storedSnoozeTime : nil

            let storedMuteTime = UserDefaultsRepository.alertMuteAllTime.value
            let isMuted = UserDefaultsRepository.alertMuteAllIsMuted.value
            let muteTime = isMuted ? storedMuteTime : nil

            var rows: [AlarmRow] = []

            // Snooze All rader
            rows.append(.dateValue(title: "Snooza alla larm till", date: snoozeTime, id: "alertSnoozeAllTime"))
            if snoozeTime != nil {
                rows.append(.toggle(title: "Alla larm snoozade", isOn: isSnoozed, id: "alertSnoozeAllIsSnoozed"))
            }

            // Mute All rader
            rows.append(.dateValue(title: "Tysta alla larm till", date: muteTime, id: "alertMuteAllTime"))
            if muteTime != nil {
                rows.append(.toggle(title: "Alla larm tystade", isOn: isMuted, id: "alertMuteAllIsMuted"))
            }

            return rows

        case .specificAlarm(let name):
            switch name {
            case "Akut låg":
                return withAlarmKitRows(getUrgentLowAlertRows(), name: name)
            case "Låg":
                return withAlarmKitRows(getLowAlertRows(), name: name)
            case "Hög":
                return withAlarmKitRows(getHighAlertRows(), name: name)
            case "Akut hög":
                return withAlarmKitRows(getUrgentHighAlertRows(), name: name)
            case "Sjunker snabbt":
                return withAlarmKitRows(getFastDropAlertRows(), name: name)
            case "Stiger snabbt":
                return withAlarmKitRows(getFastRiseAlertRows(), name: name)
            case "Tillfälligt":
                return withAlarmKitRows(getTemporaryAlertRows(), name: name)
            // Trio-segment alarms
            case "Saknar värden":
                return withAlarmKitRows(getMissingReadingsAlertRows(), name: name)
            case "Loopar inte":
                return withAlarmKitRows(getNotLoopingAlertRows(), name: name)
            case "Lågt batteri":
                return withAlarmKitRows(getLowBatteryAlertRows(), name: name)
            case "Sensorbyte":
                return withAlarmKitRows(getSAgeAlertRows(), name: name)
            case "Pumpbyte":
                return withAlarmKitRows(getCAgeAlertRows(), name: name)
            case "Reservoar":
                return withAlarmKitRows(getReservoirAlertRows(), name: name)
            case "COB":
                return withAlarmKitRows(getCOBAlertRows(), name: name)
            case "IOB":
                return withAlarmKitRows(getIOBAlertRows(), name: name)
            case "Missad bolus":
                return withAlarmKitRows(getMissedBolusAlertRows(), name: name)
            default:
                return []
            }

        case .nightSettings:
            return getNightSettingsRows()
        }


    }

    private func withAlarmKitRows(_ original: [AlarmRow], name: String) -> [AlarmRow] {
        guard let alarm = AlarmKitAlarm.allCases.first(where: { $0.settingsName == name }) else { return original }
        var rows = original
        rows.insert(contentsOf: [
            .toggle(title: "Använd även AlarmKit", isOn: alarm.enabled.value, id: "alarmKitEnabled." + alarm.rawValue),
            .segmentedPicker(title: "AlarmKit", selected: AlarmKitPeriod.allCases.firstIndex(of: alarm.period) ?? 1,
                             options: AlarmKitPeriod.allCases.map(\.title), id: "alarmKitPeriod." + alarm.rawValue)
        ], at: min(1, rows.count))
        return rows
    }

    func updateAlarmKitPeriod(id: String, index: Int) {
        guard let alarm = AlarmKitAlarm(rawValue: String(id.dropFirst("alarmKitPeriod.".count))),
              AlarmKitPeriod.allCases.indices.contains(index) else { return }
        alarm.periodValue.value = AlarmKitPeriod.allCases[index].rawValue
    }

    // MARK: - Formatters
    func formatGlucoseValue(_ value: Double) -> String {
        let isMmol = UserDefaultsRepository.units.value == "mmol/L"
        if isMmol {
            // Omräkning från mg/dL till mmol/L (delat med 18.0182)
            let mmolValue = value / 18.0182
            return String(format: "%.1f", mmolValue)
        } else {
            return String(format: "%.0f", value)
        }
    }

}
