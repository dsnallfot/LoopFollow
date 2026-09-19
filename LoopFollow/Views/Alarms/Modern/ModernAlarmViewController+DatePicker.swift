import UIKit
import Combine

extension ModernAlarmViewController {
    // Denna funktion skapar en snygg pop-up med en DatePicker
    func showDateSheet(title: String, currentDate: Date?, id: String) {
        let vc = UIViewController()
        vc.preferredContentSize = CGSize(width: view.frame.width, height: 260)

        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.date = currentDate ?? Date()
        datePicker.minuteInterval = 5
        datePicker.locale = Locale(identifier: "sv_SE")

        if id.contains("quietHour") {
            datePicker.datePickerMode = .time // Visa bara klockslag för nattinställningar
        } else {
            datePicker.datePickerMode = .dateAndTime // Visa både och för snooze
        }

        vc.view.addSubview(datePicker)
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: vc.view.topAnchor),
            datePicker.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            datePicker.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            datePicker.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        ])

        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        alert.setValue(vc, forKey: "contentViewController")

        alert.addAction(UIAlertAction(title: "Spara", style: .default) { _ in
            // För nattinställningar vill vi bara spara tiden
            // För snooze/mute vill vi även aktivera togglen (sköts i ViewModel.updateDate)
            self.viewModel.updateDate(id: id, date: datePicker.date)
            self.applySnapshot()
        })

        alert.addAction(UIAlertAction(title: "Rensa", style: .destructive) { _ in
            switch id {
            case "low_snoozed_time":
                UserDefaultsRepository.alertLowSnoozedTime.setNil(key: "alertLowSnoozedTime")
                UserDefaultsRepository.alertLowIsSnoozed.value = false

            case "alertSnoozeAllTime":
                UserDefaultsRepository.alertSnoozeAllTime.setNil(key: "alertSnoozeAllTime")
                UserDefaultsRepository.alertSnoozeAllIsSnoozed.value = false

            case "alertMuteAllTime":
                UserDefaultsRepository.alertMuteAllTime.setNil(key: "alertMuteAllTime")
                UserDefaultsRepository.alertMuteAllIsMuted.value = false

            case "quietHourStart", "quietHourEnd":
                break
            default:
                break
            }

            self.viewModel.updateSnapshotData()
            self.applySnapshot()
        })

        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel))

            present(alert, animated: true)
    }

}
