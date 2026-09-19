import Foundation

extension AlarmViewModel {
    // MARK: - Night and General Settings Logic
    func getNightSettingsRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []

        // --- Alarminställningar (General) ---
        let overrideVolume = UserDefaultsRepository.overrideSystemOutputVolume.value
        rows.append(.toggle(title: "Override systemvolym", isOn: overrideVolume, id: "overrideSystemOutputVolume"))

        // I getNightSettingsRows i din ViewModel
        if overrideVolume {
            // Vi skickar in talet som ett heltal mellan 0 och 100
            let volumePercent = (Double(UserDefaultsRepository.forcedOutputVolume.value) * 100).rounded()

            rows.append(.valueStepper(
                title: "Volym",
                value: volumePercent, // Här skickar vi 35.0 istället för 0.35
                min: 0,
                max: 100,
                step: 5,            // 5% steg istället för 0.05
                unit: "%",          // Enkel enhet
                id: "forcedOutputVolume"
            ))
        }

        rows.append(.toggle(title: "Larmljud under telefonsamtal", isOn: UserDefaultsRepository.alertAudioDuringPhone.value, id: "alertAudioDuringPhone"))
        rows.append(.toggle(title: "Ignorera noll-glukos", isOn: UserDefaultsRepository.alertIgnoreZero.value, id: "alertIgnoreZero"))
        rows.append(.toggle(title: "Auto-Snooza CGM-start", isOn: UserDefaultsRepository.alertAutoSnoozeCGMStart.value, id: "alertAutoSnoozeCGMStart"))
        rows.append(.toggle(title: "Aktivera volymknapp-snooze", isOn: UserDefaultsRepository.enableVolumeButtonSnooze.value, id: "enableVolumeButtonSnooze"))
        rows.append(.toggle(title: "Autoväxla till snoozevyn", isOn: UserDefaultsRepository.autoSwitchToSnoozeView.value, id: "autoSwitchToSnoozeView"))

        // --- Nattinställningar (Time Windows) ---
        // Eureka använde TimeInlineRow, vi mappar dem till .dateValue eller en dedikerad .timePicker om du har det
        rows.append(.dateValue(
            title: "Nattetid startar",
            date: UserDefaultsRepository.quietHourStart.value,
            id: "quietHourStart"
        ))

        rows.append(.dateValue(
            title: "Nattetid slutar",
            date: UserDefaultsRepository.quietHourEnd.value,
            id: "quietHourEnd"
        ))

        return rows
    }

}
