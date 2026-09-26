import Foundation

extension AlarmViewModel {
    // Hantera Datum-ändringar (Snoozed Until, Global Snooze/Mute, Nattinställningar)
            func updateDate(id: String, date: Date) {
                switch id {
                case "urgent_low_snoozed_time":
                    UserDefaultsRepository.alertUrgentLowSnoozedTime.value = date
                    UserDefaultsRepository.alertUrgentLowIsSnoozed.value = true
                    updateSnapshotData()

                case "low_snoozed_time":
                    UserDefaultsRepository.alertLowSnoozedTime.value = date
                    UserDefaultsRepository.alertLowIsSnoozed.value = true
                    updateSnapshotData()

                case "high_snoozed_time":
                    UserDefaultsRepository.alertHighSnoozedTime.value = date
                    UserDefaultsRepository.alertHighIsSnoozed.value = true
                    updateSnapshotData()

                case "urgent_high_snoozed_time":
                    UserDefaultsRepository.alertUrgentHighSnoozedTime.value = date
                    UserDefaultsRepository.alertUrgentHighIsSnoozed.value = true
                    updateSnapshotData()

                case "missing_readings_snoozed_time":
                    UserDefaultsRepository.alertMissedReadingSnoozedTime.value = date
                    UserDefaultsRepository.alertMissedReadingIsSnoozed.value = true
                    updateSnapshotData()

                case "not_looping_snoozed_time":
                    UserDefaultsRepository.alertNotLoopingSnoozedTime.value = date
                    UserDefaultsRepository.alertNotLoopingIsSnoozed.value = true
                    updateSnapshotData()

                case "fast_drop_snoozed_time":
                    UserDefaultsRepository.alertFastDropSnoozedTime.value = date
                    UserDefaultsRepository.alertFastDropIsSnoozed.value = true
                    updateSnapshotData()

                case "fast_rise_snoozed_time":
                    UserDefaultsRepository.alertFastRiseSnoozedTime.value = date
                    UserDefaultsRepository.alertFastRiseIsSnoozed.value = true
                    updateSnapshotData()

                case "sage_snoozed_time":
                    UserDefaultsRepository.alertSAGESnoozedTime.value = date
                    UserDefaultsRepository.alertSAGEIsSnoozed.value = true
                    updateSnapshotData()

                case "cage_snoozed_time":
                    UserDefaultsRepository.alertCAGESnoozedTime.value = date
                    UserDefaultsRepository.alertCAGEIsSnoozed.value = true
                    updateSnapshotData()

                case "reservoir_snoozed_time":
                    UserDefaultsRepository.alertPumpSnoozedTime.value = date
                    UserDefaultsRepository.alertPumpIsSnoozed.value = true
                    updateSnapshotData()

                case "cob_snoozed_time":
                    UserDefaultsRepository.alertCOBSnoozedTime.value = date
                    UserDefaultsRepository.alertCOBIsSnoozed.value = true
                    updateSnapshotData()

                case "iob_snoozed_time":
                    UserDefaultsRepository.alertIOBSnoozedTime.value = date
                    UserDefaultsRepository.alertIOBIsSnoozed.value = true
                    updateSnapshotData()

                case "missed_bolus_snoozed_time":
                    UserDefaultsRepository.alertMissedBolusSnoozedTime.value = date
                    UserDefaultsRepository.alertMissedBolusIsSnoozed.value = true
                    updateSnapshotData()

                // --- Globala inställningar ---
                case "alertSnoozeAllTime":
                    UserDefaultsRepository.alertSnoozeAllTime.value = date
                    UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = true
                    updateSnapshotData()

                case "alertMuteAllTime":
                    UserDefaultsRepository.alertMuteAllTime.value = date
                    UserDefaultsRepository.alertMuteAllIsMuted.value = true
                    updateSnapshotData()

                // --- Nattinställningar (Dina nya rader) ---
                case "quietHourStart":
                    UserDefaultsRepository.quietHourStart.value = date

                case "quietHourEnd":
                    UserDefaultsRepository.quietHourEnd.value = date

                default:
                    break
                }
            }
}
