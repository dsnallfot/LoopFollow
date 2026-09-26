import Foundation

extension AlarmViewModel {
    // Hantera Switch-ändringar
    func updateActiveToggle(id: String, value: Bool) {
        if id == "alarmKitEnabled" {
            AlarmKitSettings.enabled.value = value
            updateSnapshotData()
            return
        }
        if id.hasPrefix("alarmKitEnabled."), let alarm = AlarmKitAlarm(rawValue: String(id.dropFirst("alarmKitEnabled.".count))) {
            alarm.enabled.value = value
            updateSnapshotData()
            return
        }
        switch id {
        case "backgroundAlertEnabled":
            BackgroundAlertSettings.enabled.value = value
        case "backgroundAlertAlarmKitEnabled":
            BackgroundAlertSettings.alarmKitEnabled.value = value
        case "missing_readings_active":
            UserDefaultsRepository.alertMissedReadingActive.value = value

        case "missing_readings_is_snoozed":
            UserDefaultsRepository.alertMissedReadingIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertMissedReadingSnoozedTime.setNil(key: "alertMissedReadingSnoozedTime")
            }

        case "not_looping_active":
            UserDefaultsRepository.alertNotLoopingActive.value = value

        case "not_looping_use_limits":
            UserDefaultsRepository.alertNotLoopingUseLimits.value = value

        case "not_looping_is_snoozed":
            UserDefaultsRepository.alertNotLoopingIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertNotLoopingSnoozedTime.setNil(key: "alertNotLoopingSnoozedTime")
            }

        case "low_battery_active":
            UserDefaultsRepository.alertBatteryActive.value = value

        case "low_battery_repeat":
            UserDefaultsRepository.alertBatteryRepeat.value = value

        case "sage_active":
            UserDefaultsRepository.alertSAGEActive.value = value

        case "sage_is_snoozed":
            UserDefaultsRepository.alertSAGEIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertSAGESnoozedTime.setNil(key: "alertSAGESnoozedTime")
            }

        case "cage_active":
            UserDefaultsRepository.alertCAGEActive.value = value

        case "cage_is_snoozed":
            UserDefaultsRepository.alertCAGEIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertCAGESnoozedTime.setNil(key: "alertCAGESnoozedTime")
            }

        case "reservoir_active":
            UserDefaultsRepository.alertPump.value = value

        case "reservoir_is_snoozed":
            UserDefaultsRepository.alertPumpIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertPumpSnoozedTime.setNil(key: "alertPumpSnoozedTime")
            }

        case "cob_active":
            UserDefaultsRepository.alertCOB.value = value

        case "cob_is_snoozed":
            UserDefaultsRepository.alertCOBIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertCOBSnoozedTime.setNil(key: "alertCOBSnoozedTime")
            }

        case "iob_active":
            UserDefaultsRepository.alertIOB.value = value

        case "iob_is_snoozed":
            UserDefaultsRepository.alertIOBIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertIOBSnoozedTime.setNil(key: "alertIOBSnoozedTime")
            }

        case "missed_bolus_active":
            UserDefaultsRepository.alertMissedBolusActive.value = value

        case "missed_bolus_is_snoozed":
            UserDefaultsRepository.alertMissedBolusIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertMissedBolusSnoozedTime.setNil(key: "alertMissedBolusSnoozedTime")
            }

        // --- Globala Inställningar ---
        case "alertSnoozeAllIsSnoozed":
            UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = value
            if !value {
                // När vi stänger av ska datumet rensas i UserDefaults
                UserDefaultsRepository.alertSnoozeAllTime.setNil(key: "alertSnoozeAllTime")
            }

        case "alertMuteAllIsMuted":
            UserDefaultsRepository.alertMuteAllIsMuted.value = value
            if !value {
                UserDefaultsRepository.alertMuteAllTime.setNil(key: "alertMuteAllTime")
            }

        case "low_active":
            UserDefaultsRepository.alertLowActive.value = value

        case "low_is_snoozed":
            UserDefaultsRepository.alertLowIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertLowSnoozedTime.setNil(key: "alertLowSnoozedTime")
            }

        case "urgent_low_active":
            UserDefaultsRepository.alertUrgentLowActive.value = value

        case "urgent_low_is_snoozed":
            UserDefaultsRepository.alertUrgentLowIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertUrgentLowSnoozedTime.setNil(key: "alertUrgentLowSnoozedTime")
            }

        case "high_active":
            UserDefaultsRepository.alertHighActive.value = value

        case "high_is_snoozed":
            UserDefaultsRepository.alertHighIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertHighSnoozedTime.setNil(key: "alertHighSnoozedTime")
            }

        case "urgent_high_active":
            UserDefaultsRepository.alertUrgentHighActive.value = value

        case "urgent_high_is_snoozed":
            UserDefaultsRepository.alertUrgentHighIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertUrgentHighSnoozedTime.setNil(key: "alertUrgentHighSnoozedTime")
            }

        case "fast_drop_active":
            UserDefaultsRepository.alertFastDropActive.value = value

        case "fast_drop_use_limit":
            UserDefaultsRepository.alertFastDropUseLimit.value = value

        case "fast_drop_is_snoozed":
            UserDefaultsRepository.alertFastDropIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertFastDropSnoozedTime.setNil(key: "alertFastDropSnoozedTime")
            }

        case "fast_rise_active":
            UserDefaultsRepository.alertFastRiseActive.value = value

        case "fast_rise_use_limit":
            UserDefaultsRepository.alertFastRiseUseLimit.value = value

        case "fast_rise_is_snoozed":
            UserDefaultsRepository.alertFastRiseIsSnoozed.value = value
            if !value {
                UserDefaultsRepository.alertFastRiseSnoozedTime.setNil(key: "alertFastRiseSnoozedTime")
            }

        case "temporary_active":
            UserDefaultsRepository.alertTemporaryActive.value = value

        case "temporary_below":
            UserDefaultsRepository.alertTemporaryBelow.value = value

        case "temporary_repeat":
            UserDefaultsRepository.alertTemporaryBGRepeat.value = value

        case "overrideSystemOutputVolume":
            UserDefaultsRepository.overrideSystemOutputVolume.value = value

        case "alertAudioDuringPhone":
            UserDefaultsRepository.alertAudioDuringPhone.value = value

        case "alertIgnoreZero":
            UserDefaultsRepository.alertIgnoreZero.value = value

        case "alertAutoSnoozeCGMStart":
            UserDefaultsRepository.alertAutoSnoozeCGMStart.value = value

        case "enableVolumeButtonSnooze":
            UserDefaultsRepository.enableVolumeButtonSnooze.value = value

        case "autoSwitchToSnoozeView":
            UserDefaultsRepository.autoSwitchToSnoozeView.value = value

        default:
            break
        }

        // Uppdatera UI
        updateSnapshotData()
    }
}
