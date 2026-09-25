import Foundation

extension AlarmViewModel {
        // MARK: - Missing Readings Alert Logic
        func getMissingReadingsAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let isActive = UserDefaultsRepository.alertMissedReadingActive.value

            // 1. Active
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "missing_readings_active"))
            guard isActive else { return rows }

            // 2. Time without readings (minutes)
            rows.append(.valueStepper(
                title: "Tid utan värden",
                value: Double(UserDefaultsRepository.alertMissedReading.value),
                min: 11,
                max: 121,
                step: 5,
                unit: " min",
                id: "missing_readings_time"
            ))

            // 3. Snooze (minutes)
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertMissedReadingSnooze.value),
                min: 10,
                max: 180,
                step: 5,
                unit: " min",
                id: "missing_readings_snooze"
            ))

            // 4. Sound
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertMissedReadingSound.value ?? "Default",
                id: "missing_readings_sound"
            ))

            // 5. Play Sound
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertMissedReadingAudible.value,
                options: ["Alltid", "Nattid", "Dagtid", "Aldrig"],
                id: "missing_readings_audible"
            ))

            // 6. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertMissedReadingRepeat.value,
                options: ["Aldrig", "Alltid", "Nattid", "Dagtid"],
                id: "missing_readings_repeat"
            ))

            // 7. Pre-Snooze
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertMissedReadingAutosnooze.value,
                options: ["Aldrig", "Nattid", "Dagtid"],
                id: "missing_readings_autosnooze"
            ))

            // 8. Snoozed Until
            let storedSnoozedTime = UserDefaultsRepository.alertMissedReadingSnoozedTime.value
            let isSnoozed = UserDefaultsRepository.alertMissedReadingIsSnoozed.value
            let snoozedTime = isSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "missing_readings_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "missing_readings_is_snoozed"))
            }

            return rows
        }

        // MARK: - Not Looping Alert Logic
        func getNotLoopingAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let units = UserDefaultsRepository.units.value ?? "mg/dL"
            let isActive = UserDefaultsRepository.alertNotLoopingActive.value

            // 1. Active
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "not_looping_active"))
            guard isActive else { return rows }

            // 2. Time (minutes since last successful loop)
            rows.append(.valueStepper(
                title: "Tid utan loop",
                value: Double(UserDefaultsRepository.alertNotLooping.value),
                min: 16,
                max: 61,
                step: 5,
                unit: " min",
                id: "not_looping_time"
            ))

            // 3. Use BG Limits
            let useLimits = UserDefaultsRepository.alertNotLoopingUseLimits.value
            rows.append(.toggle(title: "Använd BG-gränser", isOn: useLimits, id: "not_looping_use_limits"))

            // 4. If Below BG (optional)
            if useLimits {
                rows.append(.valueStepper(
                    title: "Om under glukos",
                    value: Double(UserDefaultsRepository.alertNotLoopingLowerLimit.value),
                    min: 50,
                    max: 200,
                    step: (units == "mmol/L" ? 0.1 : 1.0),
                    unit: "",
                    id: "not_looping_lower_limit"
                ))

                rows.append(.valueStepper(
                    title: "Om över glukos",
                    value: Double(UserDefaultsRepository.alertNotLoopingUpperLimit.value),
                    min: 100,
                    max: 300,
                    step: (units == "mmol/L" ? 0.1 : 1.0),
                    unit: "",
                    id: "not_looping_upper_limit"
                ))
            }

            // 5. Snooze
            rows.append(.valueStepper(
                title: "Snooza",
                value: Double(UserDefaultsRepository.alertNotLoopingSnooze.value),
                min: 10,
                max: 120,
                step: 5,
                unit: " min",
                id: "not_looping_snooze"
            ))

            // 6. Sound
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertNotLoopingSound.value ?? "Default",
                id: "not_looping_sound"
            ))

            // 7. Play Sound
            rows.append(.optionPicker(
                title: "Spela larm",
                currentOption: UserDefaultsRepository.alertNotLoopingAudible.value,
                options: ["Alltid", "Nattid", "Dagtid", "Aldrig"],
                id: "not_looping_audible"
            ))

            // 8. Repeat Sound
            rows.append(.optionPicker(
                title: "Repetera larm",
                currentOption: UserDefaultsRepository.alertNotLoopingRepeat.value,
                options: ["Aldrig", "Alltid", "Nattid", "Dagtid"],
                id: "not_looping_repeat"
            ))

            // 9. Pre-Snooze
            rows.append(.optionPicker(
                title: "För-Snooza",
                currentOption: UserDefaultsRepository.alertNotLoopingAutosnooze.value,
                options: ["Aldrig", "Nattid", "Dagtid"],
                id: "not_looping_autosnooze"
            ))

            // 10. Snoozed Until
            let storedSnoozedTime = UserDefaultsRepository.alertNotLoopingSnoozedTime.value
            let isSnoozed = UserDefaultsRepository.alertNotLoopingIsSnoozed.value
            let snoozedTime = isSnoozed ? storedSnoozedTime : nil

            rows.append(.dateValue(title: "Snoozad till", date: snoozedTime, id: "not_looping_snoozed_time"))

            if snoozedTime != nil {
                rows.append(.toggle(title: "Är snoozad", isOn: isSnoozed, id: "not_looping_is_snoozed"))
            }

            return rows
        }

        // MARK: - Low Battery Alert Logic
        func getLowBatteryAlertRows() -> [AlarmRow] {
            var rows: [AlarmRow] = []
            let isActive = UserDefaultsRepository.alertBatteryActive.value

            // 1. Active
            rows.append(.toggle(title: "Aktiverat", isOn: isActive, id: "low_battery_active"))
            guard isActive else { return rows }

            // 2. Battery Level
            rows.append(.valueStepper(
                title: "Batterinivå",
                value: Double(UserDefaultsRepository.alertBatteryLevel.value),
                min: 0,
                max: 100,
                step: 5,
                unit: " %",
                id: "low_battery_level"
            ))

            // 3. Snooze Hours
            rows.append(.valueStepper(
                title: "Snooze (timmar)",
                value: Double(UserDefaultsRepository.alertBatterySnoozeHours.value),
                min: 1,
                max: 24,
                step: 1,
                unit: " h",
                id: "low_battery_snooze_hours"
            ))

            // 4. Sound
            rows.append(.soundPicker(
                title: "Larmljud",
                currentSound: UserDefaultsRepository.alertBatterySound.value ?? "Default",
                id: "low_battery_sound"
            ))

            // 5. Repeat Sound (simple on/off)
            rows.append(.toggle(
                title: "Repetera ljud",
                isOn: UserDefaultsRepository.alertBatteryRepeat.value,
                id: "low_battery_repeat"
            ))

            return rows
        }


}
