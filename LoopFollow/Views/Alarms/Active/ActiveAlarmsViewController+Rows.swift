import UIKit
import Combine

extension ActiveAlarmsViewController {
    func buildRows() {
        // Hög/Låg-larm
        let bgRows: [ActiveAlarmRow] = [
            ActiveAlarmRow(
                title: "Akut låg",
                getIsOn: { UserDefaultsRepository.alertUrgentLowActive.value },
                setIsOn: { UserDefaultsRepository.alertUrgentLowActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Låg",
                getIsOn: { UserDefaultsRepository.alertLowActive.value },
                setIsOn: { UserDefaultsRepository.alertLowActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Hög",
                getIsOn: { UserDefaultsRepository.alertHighActive.value },
                setIsOn: { UserDefaultsRepository.alertHighActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Akut hög",
                getIsOn: { UserDefaultsRepository.alertUrgentHighActive.value },
                setIsOn: { UserDefaultsRepository.alertUrgentHighActive.value = $0 }
            )
        ]

        // Trendlarm
        let trendRows: [ActiveAlarmRow] = [
            ActiveAlarmRow(
                title: "Sjunker snabbt",
                getIsOn: { UserDefaultsRepository.alertFastDropActive.value },
                setIsOn: { UserDefaultsRepository.alertFastDropActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Stiger snabbt",
                getIsOn: { UserDefaultsRepository.alertFastRiseActive.value },
                setIsOn: { UserDefaultsRepository.alertFastRiseActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Tillfälligt",
                getIsOn: { UserDefaultsRepository.alertTemporaryActive.value },
                setIsOn: { UserDefaultsRepository.alertTemporaryActive.value = $0 }
            )
        ]

        // Trio-larm
        let trioRows: [ActiveAlarmRow] = [
            ActiveAlarmRow(
                title: "Saknar värden",
                getIsOn: { UserDefaultsRepository.alertMissedReadingActive.value },
                setIsOn: { UserDefaultsRepository.alertMissedReadingActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Loopar inte",
                getIsOn: { UserDefaultsRepository.alertNotLoopingActive.value },
                setIsOn: { UserDefaultsRepository.alertNotLoopingActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Lågt batteri",
                getIsOn: { UserDefaultsRepository.alertBatteryActive.value },
                setIsOn: { UserDefaultsRepository.alertBatteryActive.value = $0 }
            )
        ]

        // Tekniklarm
        let techRows: [ActiveAlarmRow] = [
            ActiveAlarmRow(
                title: "Sensorbyte",
                getIsOn: { UserDefaultsRepository.alertSAGEActive.value },
                setIsOn: { UserDefaultsRepository.alertSAGEActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Pumpbyte",
                getIsOn: { UserDefaultsRepository.alertCAGEActive.value },
                setIsOn: { UserDefaultsRepository.alertCAGEActive.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Reservoar",
                getIsOn: { UserDefaultsRepository.alertPump.value },
                setIsOn: { UserDefaultsRepository.alertPump.value = $0 }
            )
        ]

        // Övriga larm
        let otherRows: [ActiveAlarmRow] = [
            ActiveAlarmRow(
                title: "COB",
                getIsOn: { UserDefaultsRepository.alertCOB.value },
                setIsOn: { UserDefaultsRepository.alertCOB.value = $0 }
            ),
            ActiveAlarmRow(
                title: "IOB",
                getIsOn: { UserDefaultsRepository.alertIOB.value },
                setIsOn: { UserDefaultsRepository.alertIOB.value = $0 }
            ),
            ActiveAlarmRow(
                title: "Missad bolus",
                getIsOn: { UserDefaultsRepository.alertMissedBolusActive.value },
                setIsOn: { UserDefaultsRepository.alertMissedBolusActive.value = $0 }
            )
        ]

        rowsBySection = [bgRows, trendRows, trioRows, techRows, otherRows]
    }
}
