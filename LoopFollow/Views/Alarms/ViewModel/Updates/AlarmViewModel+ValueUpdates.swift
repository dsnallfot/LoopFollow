import Foundation

extension AlarmViewModel {
        // Hantera Stepper-ändringar
        func updateAlarmValue(id: String, value: Double) {
            switch id {
            case "backgroundAlertFirstMinutes":
                BackgroundAlertSettings.setFirstMinutes(Int(value))
            case "backgroundAlertSecondMinutes":
                BackgroundAlertSettings.setSecondMinutes(Int(value))
            case "low_bg":
                UserDefaultsRepository.alertLowBG.value = Float(value)
            case "low_persistent":
                UserDefaultsRepository.alertLowPersistent.value = Int(value)
            case "low_persistence_max":
                UserDefaultsRepository.alertLowPersistenceMax.value = Float(value)
            case "low_snooze":
                UserDefaultsRepository.alertLowSnooze.value = Int(value)
            case "forcedOutputVolume":
                UserDefaultsRepository.forcedOutputVolume.value = Float(value / 100.0)
            case "urgent_low_bg":
                UserDefaultsRepository.alertUrgentLowBG.value = Float(value)
            case "urgent_low_predictive":
                UserDefaultsRepository.alertUrgentLowPredictiveMinutes.value = Int(value)
            case "urgent_low_snooze":
                UserDefaultsRepository.alertUrgentLowSnooze.value = Int(value)
            case "high_bg":
                UserDefaultsRepository.alertHighBG.value = Float(value)
            case "high_persistent":
                UserDefaultsRepository.alertHighPersistent.value = Int(value)
            case "high_snooze":
                UserDefaultsRepository.alertHighSnooze.value = Int(value)
            case "urgent_high_bg":
                UserDefaultsRepository.alertUrgentHighBG.value = Float(value)
            case "urgent_high_snooze":
                UserDefaultsRepository.alertUrgentHighSnooze.value = Int(value)
            case "fast_drop_delta":
                UserDefaultsRepository.alertFastDropDelta.value = Float(value)
            case "fast_drop_readings":
                UserDefaultsRepository.alertFastDropReadings.value = Int(value)
            case "fast_drop_below_bg":
                UserDefaultsRepository.alertFastDropBelowBG.value = Float(value)
            case "fast_drop_snooze":
                UserDefaultsRepository.alertFastDropSnooze.value = Int(value)
            case "fast_rise_delta":
                UserDefaultsRepository.alertFastRiseDelta.value = Float(value)
            case "fast_rise_readings":
                UserDefaultsRepository.alertFastRiseReadings.value = Int(value)
            case "fast_rise_above_bg":
                UserDefaultsRepository.alertFastRiseAboveBG.value = Float(value)
            case "fast_rise_snooze":
                UserDefaultsRepository.alertFastRiseSnooze.value = Int(value)
            case "temporary_bg":
                UserDefaultsRepository.alertTemporaryBG.value = Float(value)

            case "missing_readings_time":
                UserDefaultsRepository.alertMissedReading.value = Int(value)
            case "missing_readings_snooze":
                UserDefaultsRepository.alertMissedReadingSnooze.value = Int(value)

            case "not_looping_time":
                UserDefaultsRepository.alertNotLooping.value = Int(value)
            case "not_looping_lower_limit":
                UserDefaultsRepository.alertNotLoopingLowerLimit.value = Float(value)
            case "not_looping_upper_limit":
                UserDefaultsRepository.alertNotLoopingUpperLimit.value = Float(value)
            case "not_looping_snooze":
                UserDefaultsRepository.alertNotLoopingSnooze.value = Int(value)

            case "low_battery_level":
                UserDefaultsRepository.alertBatteryLevel.value = Int(value)
            case "low_battery_snooze_hours":
                UserDefaultsRepository.alertBatterySnoozeHours.value = Int(value)

            case "sage_time":
                UserDefaultsRepository.alertSAGE.value = Int(value)

            case "sage_snooze":
                UserDefaultsRepository.alertSAGESnooze.value = Int(value)

            case "cage_time":
                UserDefaultsRepository.alertCAGE.value = Int(value)

            case "cage_snooze":
                UserDefaultsRepository.alertCAGESnooze.value = Int(value)

            case "reservoir_units":
                UserDefaultsRepository.alertPumpAt.value = Int(value)

            case "reservoir_snooze_hours":
                UserDefaultsRepository.alertPumpSnoozeHours.value = Int(value)

            case "cob_at":
                UserDefaultsRepository.alertCOBAt.value = Int(value)
            case "cob_snooze_hours":
                UserDefaultsRepository.alertCOBSnoozeHours.value = Int(value)

            case "iob_at":
                UserDefaultsRepository.alertIOBAt.value = value
            case "iob_number":
                UserDefaultsRepository.alertIOBNumber.value = Int(value)
            case "iob_within":
                UserDefaultsRepository.alertIOBBolusesWithin.value = Int(value)
            case "iob_max_boluses":
                UserDefaultsRepository.alertIOBMaxBoluses.value = Int(value)
            case "iob_snooze_hours":
                UserDefaultsRepository.alertIOBSnoozeHours.value = Int(value)

            case "missed_bolus_time":
                UserDefaultsRepository.alertMissedBolus.value = Int(value)
            case "missed_bolus_prebolus_time":
                UserDefaultsRepository.alertMissedBolusPrebolus.value = Int(value)
            case "missed_bolus_ignore_bolus":
                UserDefaultsRepository.alertMissedBolusIgnoreBolus.value = value
            case "missed_bolus_low_grams":
                UserDefaultsRepository.alertMissedBolusLowGrams.value = Int(value)
            case "missed_bolus_low_grams_bg":
                UserDefaultsRepository.alertMissedBolusLowGramsBG.value = Float(value)
            case "missed_bolus_snooze":
                UserDefaultsRepository.alertMissedBolusSnooze.value = Int(value)

            default: break
            }
        }
}
