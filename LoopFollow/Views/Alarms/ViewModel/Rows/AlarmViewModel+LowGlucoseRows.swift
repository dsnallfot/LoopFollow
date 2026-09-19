import Foundation

extension AlarmViewModel {
    // MARK: - Urgent Low Alert Logic
    func getUrgentLowAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let units = UserDefaultsRepository.units.value ?? "mg/dL"
        let isActive = UserDefaultsRepository.alertUrgentLowActive.value

        // 1. Active Switch
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "urgent_low_active"))
        guard isActive else { return rows }

        // 2. BG Level (Stepper)
        let bgValue = Double(UserDefaultsRepository.alertUrgentLowBG.value)
        rows.append(.valueStepper(
            title: "Glukos",
            value: bgValue,
            min: 40,
            max: 80,
            step: (units == "mmol/L" ? 0.1 : 1.0),
            unit: "",
            id: "urgent_low_bg"
        ))

        // 3. Predictive Minutes
        rows.append(.valueStepper(
            title: "Prediktivt",
            value: Double(UserDefaultsRepository.alertUrgentLowPredictiveMinutes.value),
            min: 0,
            max: 60,
            step: 5,
            unit: " min",
            id: "urgent_low_predictive"
        ))

        // 4. Default Snooze
        rows.append(.valueStepper(
            title: "Snooze",
            value: Double(UserDefaultsRepository.alertUrgentLowSnooze.value),
            min: 5,
            max: 15,
            step: 5,
            unit: " min",
            id: "urgent_low_snooze"
        ))

        // 5. Sound Selection
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertUrgentLowSound.value ?? "Default",
            id: "urgent_low_sound"
        ))

        // 6. Play Sound (Always, At Night, etc.)
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertUrgentLowAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "urgent_low_audible"
        ))

        // 7. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertUrgentLowRepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "urgent_low_repeat"
        ))

        // 8. Pre-Snooze (AutoSnooze)
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertUrgentLowAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "urgent_low_autosnooze"
        ))

        // 9. Snoozed Until (Date)
        // Visar "Ej snoozad" om toggeln är av (även om det finns ett gammalt datum lagrat)
        let storedSnoozedTime = UserDefaultsRepository.alertUrgentLowSnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertUrgentLowIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "urgent_low_snoozed_time"))

        if snoozedTime != nil {
            rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "urgent_low_is_snoozed"))
        }

        return rows
    }

        // MARK: - Low Alert Logic
        func getLowAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let units = UserDefaultsRepository.units.value ?? "mg/dL"
            let isActive = UserDefaultsRepository.alertLowActive.value

            // 1. Active Switch
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "low_active"))
            guard isActive else { return rows }

            // 2. BG Level (Stepper)
            let bgValue = Double(UserDefaultsRepository.alertLowBG.value)
            rows.append(.valueStepper(
                title: "Glukos",
                value: bgValue,
                min: 40, max: 150, step: (units == "mmol/L" ? 0.1 : 1.0), // Stega 0.1 om mmol
                unit: "",
                id: "low_bg"
            ))

            // 3. Persistent For (Minutes)
            rows.append(.valueStepper(
                title: "Varit låg i",
                value: Double(UserDefaultsRepository.alertLowPersistent.value),
                min: 0, max: 240, step: 5, unit: " min", id: "low_persistent"
            ))

            // 4. Ignore Persistence (-Delta)
            let deltaValue = Double(UserDefaultsRepository.alertLowPersistenceMax.value)
            rows.append(.valueStepper(
                title: "Direktlarm vid -Δ",
                value: deltaValue,
                min: 0, max: 20, step: 1,
                unit: "",
                id: "low_persistence_max"
            ))

            // 5. Default Snooze Time
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertLowSnooze.value),
                min: 5, max: 30, step: 5,
                unit: " min",
                id: "low_snooze"
            ))

            // 6. Sound Selection
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertLowSound.value ?? "Default",
                id: "low_sound"
            ))

            // 7. Play Sound (Always, At Night, etc.)
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertLowAudible.value,
                options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
                id: "low_audible"
            ))

            // 8. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertLowRepeat.value,
                options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
                id: "low_repeat"
            ))

            // 9. Pre-Snooze (AutoSnooze)
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertLowAutosnooze.value,
                options: ["Aldrig", "Nattetid", "Dagtid"],
                id: "low_autosnooze"
            ))

            // 10. Snoozed Until (Date)
            // Visar "Ej snoozad" om toggeln är av (även om det finns ett gammalt datum lagrat)
            let storedSnoozedTime = UserDefaultsRepository.alertLowSnoozedTime.value
            let isLowSnoozed = UserDefaultsRepository.alertLowIsSnoozed.value
            let snoozedTime = isLowSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "low_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isLowSnoozed, id: "low_is_snoozed"))
            }

            return rows
        }
}
