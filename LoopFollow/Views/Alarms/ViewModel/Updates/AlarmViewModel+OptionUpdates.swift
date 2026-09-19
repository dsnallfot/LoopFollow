import Foundation

extension AlarmViewModel {
        // MARK: - Uppdateringslogik (Hanterar .onChange från Eureka)

        // Hjälpfunktion från originalkoden för att parsa dag/natt-inställningar
        private func timeBasedSettings(pickerValue: String) -> (dayTime: Bool, nightTime: Bool) {
            var dayTime = false
            var nightTime = false

            if pickerValue.contains("Alltid") {
                dayTime = true
                nightTime = true
            } else if pickerValue.contains("Aldrig") {
                dayTime = false
                nightTime = false
            } else {
                if pickerValue.contains("Nattetid") { nightTime = true }
                if pickerValue.contains("Dagtid") { dayTime = true }
            }
            return (dayTime, nightTime)
        }

        // Hantera Picker-ändringar (Ljud & Alternativ)
        func updateAlarmStringOption(id: String, value: String) {
            switch id {

            case "low_sound":
                UserDefaultsRepository.alertLowSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

            case "low_audible":
                UserDefaultsRepository.alertLowAudible.value = value
                let settings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertLowDayTimeAudible.value = settings.dayTime
                UserDefaultsRepository.alertLowNightTimeAudible.value = settings.nightTime

            case "low_repeat":
                UserDefaultsRepository.alertLowRepeat.value = value
                let settings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertLowDayTime.value = settings.dayTime
                UserDefaultsRepository.alertLowNightTime.value = settings.nightTime

            case "low_autosnooze":
                UserDefaultsRepository.alertLowAutosnooze.value = value
                let settings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertLowAutosnoozeDay.value = settings.dayTime
                UserDefaultsRepository.alertLowAutosnoozeNight.value = settings.nightTime

            case "urgent_low_sound":
                UserDefaultsRepository.alertUrgentLowSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

            case "urgent_low_audible":
                UserDefaultsRepository.alertUrgentLowAudible.value = value
                let settings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentLowDayTimeAudible.value = settings.dayTime
                UserDefaultsRepository.alertUrgentLowNightTimeAudible.value = settings.nightTime

            case "urgent_low_repeat":
                UserDefaultsRepository.alertUrgentLowRepeat.value = value
                let settings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentLowDayTime.value = settings.dayTime
                UserDefaultsRepository.alertUrgentLowNightTime.value = settings.nightTime

            case "urgent_low_autosnooze":
                UserDefaultsRepository.alertUrgentLowAutosnooze.value = value
                let settings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentLowAutosnoozeDay.value = settings.dayTime
                UserDefaultsRepository.alertUrgentLowAutosnoozeNight.value = settings.nightTime

            case "high_sound":
                UserDefaultsRepository.alertHighSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

            case "high_audible":
                UserDefaultsRepository.alertHighAudible.value = value
                let highAudibleSettings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertHighDayTimeAudible.value = highAudibleSettings.dayTime
                UserDefaultsRepository.alertHighNightTimeAudible.value = highAudibleSettings.nightTime

            case "high_repeat":
                UserDefaultsRepository.alertHighRepeat.value = value
                let highRepeatSettings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertHighDayTime.value = highRepeatSettings.dayTime
                UserDefaultsRepository.alertHighNightTime.value = highRepeatSettings.nightTime

            case "high_autosnooze":
                UserDefaultsRepository.alertHighAutosnooze.value = value
                let highAutosnoozeSettings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertHighAutosnoozeDay.value = highAutosnoozeSettings.dayTime
                UserDefaultsRepository.alertHighAutosnoozeNight.value = highAutosnoozeSettings.nightTime

            case "urgent_high_sound":
                UserDefaultsRepository.alertUrgentHighSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

            case "urgent_high_audible":
                UserDefaultsRepository.alertUrgentHighAudible.value = value
                let urgentHighAudibleSettings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentHighDayTimeAudible.value = urgentHighAudibleSettings.dayTime
                UserDefaultsRepository.alertUrgentHighNightTimeAudible.value = urgentHighAudibleSettings.nightTime

            case "urgent_high_repeat":
                UserDefaultsRepository.alertUrgentHighRepeat.value = value
                let urgentHighRepeatSettings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentHighDayTime.value = urgentHighRepeatSettings.dayTime
                UserDefaultsRepository.alertUrgentHighNightTime.value = urgentHighRepeatSettings.nightTime

            case "urgent_high_autosnooze":
                UserDefaultsRepository.alertUrgentHighAutosnooze.value = value
                let urgentHighAutosnoozeSettings = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertUrgentHighAutosnoozeDay.value = urgentHighAutosnoozeSettings.dayTime
                UserDefaultsRepository.alertUrgentHighAutosnoozeNight.value = urgentHighAutosnoozeSettings.nightTime

            case "fast_drop_sound":
                UserDefaultsRepository.alertFastDropSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

            case "fast_drop_audible":
                UserDefaultsRepository.alertFastDropAudible.value = value
                let settingsFD = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastDropDayTimeAudible.value = settingsFD.dayTime
                UserDefaultsRepository.alertFastDropNightTimeAudible.value = settingsFD.nightTime

            case "fast_drop_repeat":
                UserDefaultsRepository.alertFastDropRepeat.value = value
                let settingsFDRepeat = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastDropDayTime.value = settingsFDRepeat.dayTime
                UserDefaultsRepository.alertFastDropNightTime.value = settingsFDRepeat.nightTime

            case "fast_drop_autosnooze":
                UserDefaultsRepository.alertFastDropAutosnooze.value = value
                let settingsFDAuto = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastDropAutosnoozeDay.value = settingsFDAuto.dayTime
                UserDefaultsRepository.alertFastDropAutosnoozeNight.value = settingsFDAuto.nightTime

            case "fast_rise_sound":
                UserDefaultsRepository.alertFastRiseSound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

            case "fast_rise_audible":
                UserDefaultsRepository.alertFastRiseAudible.value = value
                let settingsFR = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastRiseDayTimeAudible.value = settingsFR.dayTime
                UserDefaultsRepository.alertFastRiseNightTimeAudible.value = settingsFR.nightTime

            case "fast_rise_repeat":
                UserDefaultsRepository.alertFastRiseRepeat.value = value
                let settingsFRRepeat = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastRiseDayTime.value = settingsFRRepeat.dayTime
                UserDefaultsRepository.alertFastRiseNightTime.value = settingsFRRepeat.nightTime

            case "fast_rise_autosnooze":
                UserDefaultsRepository.alertFastRiseAutosnooze.value = value
                let settingsFRAuto = timeBasedSettings(pickerValue: value)
                UserDefaultsRepository.alertFastRiseAutosnoozeDay.value = settingsFRAuto.dayTime
                UserDefaultsRepository.alertFastRiseAutosnoozeNight.value = settingsFRAuto.nightTime

            case "temporary_sound":
                UserDefaultsRepository.alertTemporarySound.value = value
                AlarmSound.setSoundFile(str: value)
                AlarmSound.stop()
                AlarmSound.playTest()

                // Trio segment (Missing readings, Not looping, Low battery)
                case "missing_readings_sound":
                    UserDefaultsRepository.alertMissedReadingSound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "missing_readings_audible":
                    UserDefaultsRepository.alertMissedReadingAudible.value = value
                    let missedAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedReadingDayTimeAudible.value = missedAudible.dayTime
                    UserDefaultsRepository.alertMissedReadingNightTimeAudible.value = missedAudible.nightTime

                case "missing_readings_repeat":
                    UserDefaultsRepository.alertMissedReadingRepeat.value = value
                    let missedRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedReadingDayTime.value = missedRepeat.dayTime
                    UserDefaultsRepository.alertMissedReadingNightTime.value = missedRepeat.nightTime

                case "missing_readings_autosnooze":
                    UserDefaultsRepository.alertMissedReadingAutosnooze.value = value
                    let missedAuto = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedReadingAutosnoozeDay.value = missedAuto.dayTime
                    UserDefaultsRepository.alertMissedReadingAutosnoozeNight.value = missedAuto.nightTime

                case "not_looping_sound":
                    UserDefaultsRepository.alertNotLoopingSound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "not_looping_audible":
                    UserDefaultsRepository.alertNotLoopingAudible.value = value
                    let notLoopingAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertNotLoopingDayTimeAudible.value = notLoopingAudible.dayTime
                    UserDefaultsRepository.alertNotLoopingNightTimeAudible.value = notLoopingAudible.nightTime

                case "not_looping_repeat":
                    UserDefaultsRepository.alertNotLoopingRepeat.value = value
                    let notLoopingRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertNotLoopingDayTime.value = notLoopingRepeat.dayTime
                    UserDefaultsRepository.alertNotLoopingNightTime.value = notLoopingRepeat.nightTime

                case "not_looping_autosnooze":
                    UserDefaultsRepository.alertNotLoopingAutosnooze.value = value
                    let notLoopingAuto = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertNotLoopingAutosnoozeDay.value = notLoopingAuto.dayTime
                    UserDefaultsRepository.alertNotLoopingAutosnoozeNight.value = notLoopingAuto.nightTime

                case "low_battery_sound":
                    UserDefaultsRepository.alertBatterySound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                // --- SAGE (Sensorbyte) ---
                case "sage_sound":
                    UserDefaultsRepository.alertSAGESound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "sage_audible":
                    UserDefaultsRepository.alertSAGEAudible.value = value
                    let sageAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertSAGEDayTimeAudible.value = sageAudible.dayTime
                    UserDefaultsRepository.alertSAGENightTimeAudible.value = sageAudible.nightTime

                case "sage_repeat":
                    UserDefaultsRepository.alertSAGERepeat.value = value
                    let sageRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertSAGEDayTime.value = sageRepeat.dayTime
                    UserDefaultsRepository.alertSAGENightTime.value = sageRepeat.nightTime

                case "sage_autosnooze":
                    UserDefaultsRepository.alertSAGEAutosnooze.value = value
                    let sageAutosnooze = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertSAGEAutosnoozeDay.value = sageAutosnooze.dayTime
                    UserDefaultsRepository.alertSAGEAutosnoozeNight.value = sageAutosnooze.nightTime

                // --- CAGE (Pumpbyte) ---
                case "cage_sound":
                    UserDefaultsRepository.alertCAGESound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "cage_audible":
                    UserDefaultsRepository.alertCAGEAudible.value = value
                    let cageAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCAGEDayTimeAudible.value = cageAudible.dayTime
                    UserDefaultsRepository.alertCAGENightTimeAudible.value = cageAudible.nightTime

                case "cage_repeat":
                    UserDefaultsRepository.alertCAGERepeat.value = value
                    let cageRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCAGEDayTime.value = cageRepeat.dayTime
                    UserDefaultsRepository.alertCAGENightTime.value = cageRepeat.nightTime

                case "cage_autosnooze":
                    UserDefaultsRepository.alertCAGEAutosnooze.value = value
                    let cageAutosnooze = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCAGEAutosnoozeDay.value = cageAutosnooze.dayTime
                    UserDefaultsRepository.alertCAGEAutosnoozeNight.value = cageAutosnooze.nightTime

                // --- Pump / Reservoir ---
                case "reservoir_sound":
                    UserDefaultsRepository.alertPumpSound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "reservoir_audible":
                    UserDefaultsRepository.alertPumpAudible.value = value
                    let pumpAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertPumpDayTimeAudible.value = pumpAudible.dayTime
                    UserDefaultsRepository.alertPumpNightTimeAudible.value = pumpAudible.nightTime

                case "reservoir_repeat":
                    UserDefaultsRepository.alertPumpRepeat.value = value
                    let pumpRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertPumpDayTime.value = pumpRepeat.dayTime
                    UserDefaultsRepository.alertPumpNightTime.value = pumpRepeat.nightTime

                case "reservoir_autosnooze":
                    UserDefaultsRepository.alertPumpAutosnooze.value = value
                    let pumpAutosnooze = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertPumpAutosnoozeDay.value = pumpAutosnooze.dayTime
                    UserDefaultsRepository.alertPumpAutosnoozeNight.value = pumpAutosnooze.nightTime

                // --- COB ---
                case "cob_sound":
                    UserDefaultsRepository.alertCOBSound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "cob_audible":
                    UserDefaultsRepository.alertCOBAudible.value = value
                    let cobAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCOBDayTimeAudible.value = cobAudible.dayTime
                    UserDefaultsRepository.alertCOBNightTimeAudible.value = cobAudible.nightTime

                case "cob_repeat":
                    UserDefaultsRepository.alertCOBRepeat.value = value
                    let cobRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCOBDayTime.value = cobRepeat.dayTime
                    UserDefaultsRepository.alertCOBNightTime.value = cobRepeat.nightTime

                case "cob_autosnooze":
                    UserDefaultsRepository.alertCOBAutosnooze.value = value
                    let cobAutosnooze = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertCOBAutosnoozeDay.value = cobAutosnooze.dayTime
                    UserDefaultsRepository.alertCOBAutosnoozeNight.value = cobAutosnooze.nightTime

                // --- IOB ---
                case "iob_sound":
                    UserDefaultsRepository.alertIOBSound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "iob_audible":
                    UserDefaultsRepository.alertIOBAudible.value = value
                    let iobAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertIOBDayTimeAudible.value = iobAudible.dayTime
                    UserDefaultsRepository.alertIOBNightTimeAudible.value = iobAudible.nightTime

                case "iob_repeat":
                    UserDefaultsRepository.alertIOBRepeat.value = value
                    let iobRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertIOBDayTime.value = iobRepeat.dayTime
                    UserDefaultsRepository.alertIOBNightTime.value = iobRepeat.nightTime

                case "iob_autosnooze":
                    UserDefaultsRepository.alertIOBAutosnooze.value = value
                    let iobAutosnooze = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertIOBAutosnoozeDay.value = iobAutosnooze.dayTime
                    UserDefaultsRepository.alertIOBAutosnoozeNight.value = iobAutosnooze.nightTime

                // --- Missed Bolus ---
                case "missed_bolus_sound":
                    UserDefaultsRepository.alertMissedBolusSound.value = value
                    AlarmSound.setSoundFile(str: value)
                    AlarmSound.stop()
                    AlarmSound.playTest()

                case "missed_bolus_audible":
                    UserDefaultsRepository.alertMissedBolusAudible.value = value
                    let missedAudible = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedBolusDayTimeAudible.value = missedAudible.dayTime
                    UserDefaultsRepository.alertMissedBolusNightTimeAudible.value = missedAudible.nightTime

                case "missed_bolus_repeat":
                    UserDefaultsRepository.alertMissedBolusRepeat.value = value
                    let missedRepeat = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedBolusDayTime.value = missedRepeat.dayTime
                    UserDefaultsRepository.alertMissedBolusNightTime.value = missedRepeat.nightTime

                case "missed_bolus_autosnooze":
                    UserDefaultsRepository.alertMissedBolusAutosnooze.value = value
                    let missedAuto = timeBasedSettings(pickerValue: value)
                    UserDefaultsRepository.alertMissedBolusAutosnoozeDay.value = missedAuto.dayTime
                    UserDefaultsRepository.alertMissedBolusAutosnoozeNight.value = missedAuto.nightTime

            default: break
            }
        }

}
