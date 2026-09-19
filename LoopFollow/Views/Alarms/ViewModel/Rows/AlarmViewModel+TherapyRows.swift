import Foundation

extension AlarmViewModel {
    // MARK: - COB Alert Logic
    func getCOBAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let isActive = UserDefaultsRepository.alertCOB.value

        // 1. Active
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "cob_active"))
        guard isActive else { return rows }

        // 2. COB threshold
        rows.append(.valueStepper(
            title: "COB ≥",
            value: Double(UserDefaultsRepository.alertCOBAt.value),
            min: 1,
            max: 200,
            step: 1,
            unit: " g",
            id: "cob_at"
        ))

        // 3. Snooze (hours)
        rows.append(.valueStepper(
            title: "Snooze",
            value: Double(UserDefaultsRepository.alertCOBSnoozeHours.value),
            min: 1,
            max: 6,
            step: 1,
            unit: " h",
            id: "cob_snooze_hours"
        ))

        // 4. Sound
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertCOBSound.value ?? "Default",
            id: "cob_sound"
        ))

        // 5. Play Sound
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertCOBAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "cob_audible"
        ))

        // 6. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertCOBRepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "cob_repeat"
        ))

        // 7. Pre-Snooze
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertCOBAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "cob_autosnooze"
        ))

        // 8. Snoozad till
        let storedSnoozedTime = UserDefaultsRepository.alertCOBSnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertCOBIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(
            title: "Snoozad till",
            date: snoozedTime,
            id: "cob_snoozed_time"
        ))

        if snoozedTime != nil {
            rows.append(.toggle(
                title: "Är snoozad",
                isOn: isSnoozed,
                id: "cob_is_snoozed"
            ))
        }

        return rows
    }

    // MARK: - IOB Alert Logic
    func getIOBAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let isActive = UserDefaultsRepository.alertIOB.value

        // 1. Active
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "iob_active"))
        guard isActive else { return rows }

        // 2. Bolus size threshold
        rows.append(.valueStepper(
            title: "Enskild bolus ≥",
            value: Double(UserDefaultsRepository.alertIOBAt.value),
            min: 0.1,
            max: 50,
            step: 0.1,
            unit: " E",
            id: "iob_at"
        ))

        // 3. Number of boluses
        rows.append(.valueStepper(
            title: "Antal bolusar ≥",
            value: Double(UserDefaultsRepository.alertIOBNumber.value),
            min: 1,
            max: 10,
            step: 1,
            unit: " st",
            id: "iob_number"
        ))

        // 4. Within minutes
        rows.append(.valueStepper(
            title: "Inom",
            value: Double(UserDefaultsRepository.alertIOBBolusesWithin.value),
            min: 5,
            max: 120,
            step: 5,
            unit: " min",
            id: "iob_within"
        ))

        // 5. Or total IOB
        rows.append(.valueStepper(
            title: "Eller total IOB ≥",
            value: Double(UserDefaultsRepository.alertIOBMaxBoluses.value),
            min: 1,
            max: 20,
            step: 1,
            unit: " E",
            id: "iob_max_boluses"
        ))

        // 6. Snooze (hours)
        rows.append(.valueStepper(
            title: "Snooze",
            value: Double(UserDefaultsRepository.alertIOBSnoozeHours.value),
            min: 1,
            max: 6,
            step: 1,
            unit: " h",
            id: "iob_snooze_hours"
        ))

        // 7. Sound
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertIOBSound.value ?? "Default",
            id: "iob_sound"
        ))

        // 8. Play Sound
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertIOBAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "iob_audible"
        ))

        // 9. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertIOBRepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "iob_repeat"
        ))

        // 10. Pre-Snooze
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertIOBAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "iob_autosnooze"
        ))

        // 11. Snoozad till
        let storedSnoozedTime = UserDefaultsRepository.alertIOBSnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertIOBIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(
            title: "Snoozad till",
            date: snoozedTime,
            id: "iob_snoozed_time"
        ))

        if snoozedTime != nil {
            rows.append(.toggle(
                title: "Är snoozad",
                isOn: isSnoozed,
                id: "iob_is_snoozed"
            ))
        }

        return rows
    }

    // MARK: - Missed Bolus Alert Logic
    func getMissedBolusAlertRows() -> [AlarmRow] {
        var rows: [AlarmRow] = []
        let units = UserDefaultsRepository.units.value ?? "mg/dL"
        let isActive = UserDefaultsRepository.alertMissedBolusActive.value

        // 1. Active
        rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "missed_bolus_active"))
        guard isActive else { return rows }

        // 2. Time after carbs without bolus
        rows.append(.valueStepper(
            title: "Tid efter måltid",
            value: Double(UserDefaultsRepository.alertMissedBolus.value),
            min: 5,
            max: 60,
            step: 5,
            unit: " min",
            id: "missed_bolus_time"
        ))

        // 3. Prebolus max time
        rows.append(.valueStepper(
            title: "Prebolus max tid",
            value: Double(UserDefaultsRepository.alertMissedBolusPrebolus.value),
            min: 5,
            max: 45,
            step: 5,
            unit: " min",
            id: "missed_bolus_prebolus_time"
        ))

        // 4. Ignore bolus under
        rows.append(.valueStepper(
            title: "Ignorera när bolus ≤",
            value: Double(UserDefaultsRepository.alertMissedBolusIgnoreBolus.value),
            min: 0.05,
            max: 2.0,
            step: 0.05,
            unit: " E",
            id: "missed_bolus_ignore_bolus"
        ))

        // 5. Ignore low-treatment carbs under grams
        rows.append(.valueStepper(
            title: "Ignorera när kh <",
            value: Double(UserDefaultsRepository.alertMissedBolusLowGrams.value),
            min: 0,
            max: 15,
            step: 1,
            unit: " g",
            id: "missed_bolus_low_grams"
        ))

        // 6. Ignore under BG
        rows.append(.valueStepper(
            title: "Ignorera när glukos <",
            value: Double(UserDefaultsRepository.alertMissedBolusLowGramsBG.value),
            min: 40,
            max: 100,
            step: (units == "mmol/L" ? 0.1 : 1.0),
            unit: "",
            id: "missed_bolus_low_grams_bg"
        ))

        // 7. Snooze
        rows.append(.valueStepper(
            title: "Snooza",
            value: Double(UserDefaultsRepository.alertMissedBolusSnooze.value),
            min: 5,
            max: 60,
            step: 5,
            unit: " min",
            id: "missed_bolus_snooze"
        ))

        // 8. Sound
        rows.append(.soundPicker(
            title: "Larmljud",
            currentSound: UserDefaultsRepository.alertMissedBolusSound.value ?? "Default",
            id: "missed_bolus_sound"
        ))

        // 9. Play Sound
        rows.append(.optionPicker(
            title: "Spela larm",
            currentOption: UserDefaultsRepository.alertMissedBolusAudible.value,
            options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
            id: "missed_bolus_audible"
        ))

        // 10. Repeat Sound
        rows.append(.optionPicker(
            title: "Repetera larm",
            currentOption: UserDefaultsRepository.alertMissedBolusRepeat.value,
            options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
            id: "missed_bolus_repeat"
        ))

        // 11. Pre-Snooze
        rows.append(.optionPicker(
            title: "För-Snooza",
            currentOption: UserDefaultsRepository.alertMissedBolusAutosnooze.value,
            options: ["Aldrig", "Nattetid", "Dagtid"],
            id: "missed_bolus_autosnooze"
        ))

        // 12. Snoozad till
        let storedSnoozedTime = UserDefaultsRepository.alertMissedBolusSnoozedTime.value
        let isSnoozed = UserDefaultsRepository.alertMissedBolusIsSnoozed.value
        let snoozedTime = isSnoozed ? storedSnoozedTime : nil

        rows.append(.dateValue(
            title: "Snoozad till",
            date: snoozedTime,
            id: "missed_bolus_snoozed_time"
        ))

        if snoozedTime != nil {
            rows.append(.toggle(
                title: "Är snoozad",
                isOn: isSnoozed,
                id: "missed_bolus_is_snoozed"
            ))
        }

        return rows
    }


}
