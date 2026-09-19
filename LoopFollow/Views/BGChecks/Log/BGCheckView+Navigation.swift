import UIKit
import Charts

extension BGCheckView {
    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func refreshTapped() {
        switch mode {
        case .fingerstick:
            loadBGChecks()
        case .dextro:
            loadLowTreatments()
        }
    }

    func updateDatePickerBounds() {
        let dates: [Date]
        switch mode {
        case .fingerstick:
            dates = fingerstickEntries.map { $0.date }
        case .dextro:
            dates = dextroEntries.map { $0.date }
        }

        guard !dates.isEmpty else { return }


        let cal = Calendar.current

        // Vi antar att listorna är sorterade nyast först → äldsta = last
        let sorted = dates.sorted()
        if let oldest = sorted.first {
            let minDate = cal.startOfDay(for: oldest)
            datePicker.minimumDate = minDate
        } else {
            datePicker.minimumDate = nil
        }

        // Maxdatum = idag
        datePicker.maximumDate = Date()

        // Klampa vald datum inom intervallet om den hamnat utanför
        if let min = datePicker.minimumDate, datePicker.date < min {
            datePicker.date = min
        }
        if let max = datePicker.maximumDate, datePicker.date > max {
            datePicker.date = max
        }
    }

    @objc func datePickerChanged(_ picker: UIDatePicker) {
        let cal = Calendar.current
        let selected = picker.date
        let startOfDay = cal.startOfDay(for: selected)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        switch mode {
        case .fingerstick:
            guard !fingerstickEntries.isEmpty else { return }
            var targetIndex: Int?

            for (idx, entry) in fingerstickEntries.enumerated() {
                if entry.date >= startOfDay && entry.date < endOfDay {
                    targetIndex = idx
                    break
                }
            }

            if targetIndex == nil {
                var candidateIndex: Int?
                for (idx, entry) in fingerstickEntries.enumerated() {
                    if entry.date >= selected {
                        candidateIndex = idx
                    }
                }

                if let candidateIndex {
                    targetIndex = candidateIndex
                } else {
                    targetIndex = 0
                }
            }

            guard let index = targetIndex,
                  index >= 0,
                  index < tableView.numberOfRows(inSection: 0) else { return }

            let indexPath = IndexPath(row: index, section: 0)
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)

        case .dextro:
            guard !dextroEntries.isEmpty else { return }
            var targetIndex: Int?

            for (idx, entry) in dextroEntries.enumerated() {
                if entry.date >= startOfDay && entry.date < endOfDay {
                    targetIndex = idx
                    break
                }
            }

            if targetIndex == nil {
                var candidateIndex: Int?
                for (idx, entry) in dextroEntries.enumerated() {
                    if entry.date >= selected {
                        candidateIndex = idx
                    }
                }

                if let candidateIndex {
                    targetIndex = candidateIndex
                } else {
                    targetIndex = 0
                }
            }

            guard let index = targetIndex,
                  index >= 0,
                  index < tableView.numberOfRows(inSection: 0) else { return }

            let indexPath = IndexPath(row: index, section: 0)
            tableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }

    @objc func modeChanged(_ sender: UISegmentedControl) {
        let newMode: Mode = (sender.selectedSegmentIndex == 0) ? .fingerstick : .dextro
        mode = newMode

        switch mode {
        case .fingerstick:
            title = "Fingerstick"
            updateDatePickerBounds()
            tableView.reloadData()
            // Autoscrolla till rätt rad för det aktuella datumet
            datePickerChanged(datePicker)

        case .dextro:
            title = "Dextro"
            if dextroEntries.isEmpty {
                // När dextro laddas första gången, låt loadLowTreatments sköta bounds + autoscroll
                loadLowTreatments()
            } else {
                updateDatePickerBounds()
                tableView.reloadData()
                // Autoscrolla även här till rätt rad
                datePickerChanged(datePicker)
            }
        }
    }
}
