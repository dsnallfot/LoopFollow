import Foundation

extension AlarmViewModel {
    // MARK: - SAGE (Sensorbyte) Alert Logic
    func getSAgeAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let isActive = UserDefaultsRepository.alertSAGEActive.value

        // 1. Active
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "sage_active"))
        guard isActive else { return rows }

        // 2. Time (hours before sensor change)
        rows.append(.valueStepper(
            title: "Tid före byte",
            value: Double(UserDefaultsRepository.alertSAGE.value),
            min: 1,
            max: 24,
            step: 1,
            unit: " h",
            id: "sage_time"
        ))

        // 3. Snooze (hours)
        rows.append(.valueStepper(
            title: "Snooze (timmar)",
            value: Double(UserDefaultsRepository.alertSAGESnooze.value),
            min: 1,
            max: 24,
            step: 1,
            unit: " h",
            id: "sage_snooze"
        ))

        // 4. Sound
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertSAGESound.value ?? "Default",
            id: "sage_sound"
        ))

        // 5. Play Sound (dag/natt/alltid)
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertSAGEAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "sage_audible"
        ))

        // 6. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertSAGERepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "sage_repeat"
        ))

        // 7. Pre-Snooze
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertSAGEAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "sage_autosnooze"
        ))

        // 8. Snoozad till
        let storedSnoozedTime = UserDefaultsRepository.alertSAGESnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertSAGEIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(
            title: "Snoozad till",
            date: snoozedTime,
            id: "sage_snoozed_time"
        ))

        if snoozedTime != nil {
            rows.append(.toggle(
                title: "Är snoozad",
                isOn: isSnoozed,
                id: "sage_is_snoozed"
            ))
        }

        return rows
    }

    // MARK: - CAGE (Pumpbyte) Alert Logic
    func getCAgeAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let isActive = UserDefaultsRepository.alertCAGEActive.value

        // 1. Active
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "cage_active"))
        guard isActive else { return rows }

        // 2. Time (hours before canula/pump change)
        rows.append(.valueStepper(
            title: "Tid före byte",
            value: Double(UserDefaultsRepository.alertCAGE.value),
            min: 1,
            max: 24,
            step: 1,
            unit: " h",
            id: "cage_time"
        ))

        // 3. Snooze (hours)
        rows.append(.valueStepper(
            title: "Snooze (timmar)",
            value: Double(UserDefaultsRepository.alertCAGESnooze.value),
            min: 1,
            max: 24,
            step: 1,
            unit: " h",
            id: "cage_snooze"
        ))

        // 4. Sound
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertCAGESound.value ?? "Default",
            id: "cage_sound"
        ))

        // 5. Play Sound
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertCAGEAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "cage_audible"
        ))

        // 6. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertCAGERepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "cage_repeat"
        ))

        // 7. Pre-Snooze
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertCAGEAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "cage_autosnooze"
        ))

        // 8. Snoozed Until
        let storedSnoozedTime = UserDefaultsRepository.alertCAGESnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertCAGEIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(
            title: "Snoozad till",
            date: snoozedTime,
            id: "cage_snoozed_time"
        ))

        if snoozedTime != nil {
            rows.append(.toggle(
                title: "Är snoozad",
                isOn: isSnoozed,
                id: "cage_is_snoozed"
            ))
        }

        return rows
    }

    // MARK: - Pump / Reservoar Alert Logic
    func getReservoirAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let isActive = UserDefaultsRepository.alertPump.value

        // 1. Active
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "reservoir_active"))
        guard isActive else { return rows }

        // 2. Units Remaining
        rows.append(.valueStepper(
            title: "Enheter kvar",
            value: Double(UserDefaultsRepository.alertPumpAt.value),
            min: 1,
            max: 49,
            step: 1,
            unit: " E",
            id: "reservoir_units"
        ))

        // 3. Snooze Hours
        rows.append(.valueStepper(
            title: "Snooze (timmar)",
            value: Double(UserDefaultsRepository.alertPumpSnoozeHours.value),
            min: 1,
            max: 24,
            step: 1,
            unit: " h",
            id: "reservoir_snooze_hours"
        ))

        // 4. Sound
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertPumpSound.value ?? "Default",
            id: "reservoir_sound"
        ))

        // 5. Play Sound
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertPumpAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "reservoir_audible"
        ))

        // 6. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertPumpRepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "reservoir_repeat"
        ))

        // 7. Pre-Snooze
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertPumpAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "reservoir_autosnooze"
        ))

        // 8. Snoozed Until
        let storedSnoozedTime = UserDefaultsRepository.alertPumpSnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertPumpIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(
            title: "Snoozad till",
            date: snoozedTime,
            id: "reservoir_snoozed_time"
        ))

        if snoozedTime != nil {
            rows.append(.toggle(
                title: "Är snoozad",
                isOn: isSnoozed,
                id: "reservoir_is_snoozed"
            ))
        }

        return rows
    }

}
