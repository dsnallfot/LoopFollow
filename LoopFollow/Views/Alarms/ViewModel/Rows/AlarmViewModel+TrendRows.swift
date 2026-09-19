import Foundation

extension AlarmViewModel {
        // MARK: - Fast Drop Alert Logic
        func getFastDropAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let units = UserDefaultsRepository.units.value ?? "mg/dL"
            let isActive = UserDefaultsRepository.alertFastDropActive.value

            // 1. Active
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "fast_drop_active"))
            guard isActive else { return rows }

            // 2. Delta
            rows.append(.valueStepper(
                title: "Delta sjunkning",
                value: Double(UserDefaultsRepository.alertFastDropDelta.value),
                min: 3,
                max: 20,
                step: (units == "mmol/L" ? 0.1 : 1.0),
                unit: "",
                id: "fast_drop_delta"
            ))

            // 3. # Readings
            rows.append(.valueStepper(
                title: "Mätningar",
                value: Double(UserDefaultsRepository.alertFastDropReadings.value),
                min: 2,
                max: 4,
                step: 1,
                unit: " st",
                id: "fast_drop_readings"
            ))

            // 4. Use BG Limit
            let useLimit = UserDefaultsRepository.alertFastDropUseLimit.value
            rows.append(.toggle(title: "Använd BG-gräns", isOn: useLimit, id: "fast_drop_use_limit"))

            // 5. Dropping below BG (optional)
            if useLimit {
                rows.append(.valueStepper(
                    title: "Sjunker under BG",
                    value: Double(UserDefaultsRepository.alertFastDropBelowBG.value),
                    min: 40,
                    max: 300,
                    step: (units == "mmol/L" ? 0.1 : 1.0),
                    unit: "",
                    id: "fast_drop_below_bg"
                ))
            }

            // 6. Snooze
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertFastDropSnooze.value),
                min: 5,
                max: 60,
                step: 5,
                unit: " min",
                id: "fast_drop_snooze"
            ))

            // 7. Sound
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertFastDropSound.value ?? "Default",
                id: "fast_drop_sound"
            ))

            // 8. Play Sound
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertFastDropAudible.value,
                options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
                id: "fast_drop_audible"
            ))

            // 9. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertFastDropRepeat.value,
                options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
                id: "fast_drop_repeat"
            ))

            // 10. Pre-Snooze
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertFastDropAutosnooze.value,
                options: ["Aldrig", "Nattetid", "Dagtid"],
                id: "fast_drop_autosnooze"
            ))

            // 11. Snoozed Until
            let storedSnoozedTime = UserDefaultsRepository.alertFastDropSnoozedTime.value
            let isSnoozed = UserDefaultsRepository.alertFastDropIsSnoozed.value
            let snoozedTime = isSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "fast_drop_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "fast_drop_is_snoozed"))
            }

            return rows
        }

        // MARK: - Fast Rise Alert Logic
        func getFastRiseAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let units = UserDefaultsRepository.units.value ?? "mg/dL"
            let isActive = UserDefaultsRepository.alertFastRiseActive.value

            // 1. Active
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "fast_rise_active"))
            guard isActive else { return rows }

            // 2. Delta
            rows.append(.valueStepper(
                title: "Delta stigning",
                value: Double(UserDefaultsRepository.alertFastRiseDelta.value),
                min: 3,
                max: 20,
                step: (units == "mmol/L" ? 0.1 : 1.0),
                unit: "",
                id: "fast_rise_delta"
            ))

            // 3. # Readings
            rows.append(.valueStepper(
                title: "Mätningar",
                value: Double(UserDefaultsRepository.alertFastRiseReadings.value),
                min: 2,
                max: 4,
                step: 1,
                unit: " st",
                id: "fast_rise_readings"
            ))

            // 4. Use BG Limit
            let useLimit = UserDefaultsRepository.alertFastRiseUseLimit.value
            rows.append(.toggle(title: "Använd BG-gräns", isOn: useLimit, id: "fast_rise_use_limit"))

            // 5. Rising above BG (optional)
            if useLimit {
                rows.append(.valueStepper(
                    title: "Stiger över BG",
                    value: Double(UserDefaultsRepository.alertFastRiseAboveBG.value),
                    min: 40,
                    max: 300,
                    step: (units == "mmol/L" ? 0.1 : 1.0),
                    unit: "",
                    id: "fast_rise_above_bg"
                ))
            }

            // 6. Snooze
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertFastRiseSnooze.value),
                min: 5,
                max: 60,
                step: 5,
                unit: " min",
                id: "fast_rise_snooze"
            ))

            // 7. Sound
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertFastRiseSound.value ?? "Default",
                id: "fast_rise_sound"
            ))

            // 8. Play Sound
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertFastRiseAudible.value,
                options: ["Alltid", "Nattetid", "Dagtid", "Aldrig"],
                id: "fast_rise_audible"
            ))

            // 9. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertFastRiseRepeat.value,
                options: ["Aldrig", "Alltid", "Nattetid", "Dagtid"],
                id: "fast_rise_repeat"
            ))

            // 10. Pre-Snooze
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertFastRiseAutosnooze.value,
                options: ["Aldrig", "Nattetid", "Dagtid"],
                id: "fast_rise_autosnooze"
            ))

            // 11. Snoozed Until
            let storedSnoozedTime = UserDefaultsRepository.alertFastRiseSnoozedTime.value
            let isSnoozed = UserDefaultsRepository.alertFastRiseIsSnoozed.value
            let snoozedTime = isSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "fast_rise_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "fast_rise_is_snoozed"))
            }

            return rows
        }

        // MARK: - Temporary Alert Logic
        func getTemporaryAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let isActive = UserDefaultsRepository.alertTemporaryActive.value

            // 1. Active
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "temporary_active"))
            guard isActive else { return rows }

            // 2. Alert Below BG (if off => treat as high alert above BG)
            rows.append(.toggle(title: "Larma under glukos", isOn: UserDefaultsRepository.alertTemporaryBelow.value, id: "temporary_below"))

            // 3. BG threshold
            rows.append(.valueStepper(
                title: "Glukos",
                value: Double(UserDefaultsRepository.alertTemporaryBG.value),
                min: 40,
                max: 400,
                step: 1,
                unit: "",
                id: "temporary_bg"
            ))

            // 4. Sound
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertTemporarySound.value ?? "Default",
                id: "temporary_sound"
            ))

            // 5. Repeat Sound (simple on/off)
            rows.append(.toggle(title: "Repetera ljud", isOn: UserDefaultsRepository.alertTemporaryBGRepeat.value, id: "temporary_repeat"))

            return rows
        }
}
