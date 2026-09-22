import UIKit
import Charts

extension GlucoseView {
    @objc func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func showGlucoseStats() {
        let statsVC = GlucoseStatsViewController()
        let nav = UINavigationController(rootViewController: statsVC)

        nav.modalPresentationStyle = .formSheet
        nav.view.backgroundColor = .clear
        nav.view.isOpaque = false
        nav.view.layer.backgroundColor = UIColor.clear.cgColor

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance

        nav.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle
        present(nav, animated: true)
    }

    @objc func toggleMissingOnly() {
        showOnlyMissingGlucose.toggle()

        if let filterButton = navigationItem.rightBarButtonItems?.last {
        //if let filterButton = navigationItem.leftBarButtonItems?.last {
            let name = showOnlyMissingGlucose
                ? "line.3.horizontal.decrease.circle.fill"
                : "line.3.horizontal.decrease.circle"
            filterButton.image = UIImage(systemName: name)
            filterButton.tintColor = showOnlyMissingGlucose ? .systemBlue : .label
        }

        tableView.reloadData()
        updateStatsLabel()
    }

    @objc private func prevDayTapped() { stepDay(by: -1) }
    @objc private func nextDayTapped() { stepDay(by: 1) }

    private func stepDay(by delta: Int) {
        let cal = Calendar.current
        guard let newDate = cal.date(byAdding: .day, value: delta, to: selectedDate) else { return }

        // Clamp to picker range (no future days, no earlier than cache window)
        if let minDate = datePicker.minimumDate, newDate < cal.startOfDay(for: minDate) { return }
        if newDate > Date() { return }

        selectedDate = newDate
        datePicker.setDate(newDate, animated: true)
        loadBG(for: newDate)
        updateStatsLabel()
    }

    @objc func modeChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            title = "Glukos"
            dataMode = .allValues
        default:
            title = "Sensorfel"
            dataMode = .sensorErrors
        }

        // UI tweaks for Sensorfel mode
        let isSensorErrors = (dataMode == .sensorErrors)
        datePicker.isHidden = isSensorErrors

        if let filterButton = navigationItem.rightBarButtonItems?.last {
            if isSensorErrors {
                // När vi går in i Sensorfel-läget: nollställ filtret och inaktivera knappen.
                showOnlyMissingGlucose = false
                filterButton.isEnabled = false
                filterButton.image = UIImage(systemName: "line.3.horizontal.decrease.circle")
                filterButton.tintColor = .secondaryLabel
            } else {
                // I glukosläget:
                // behåll showOnlyMissingGlucose-state och återspegla den i ikonen.
                filterButton.isEnabled = true
                let name = showOnlyMissingGlucose
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
                filterButton.image = UIImage(systemName: name)
                filterButton.tintColor = showOnlyMissingGlucose ? .systemBlue : .label
            }
        }

        if isSensorErrors {

            // Visa cached lista direkt (instant)
            let cached = loadSensorErrorRowsFromCache()
            if !cached.isEmpty {
                sensorErrorRows = cached.sorted { $0.date > $1.date }
                tableView.reloadData()
                updateStatsLabel()
            }

            showRefreshIndicator()
            Task {
                await self.loadSensorErrors90Days()
            }

        } else {
            loadBG(for: selectedDate)
            updateStatsLabel()
        }
    }

    @objc func dateChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
        loadBG(for: selectedDate)
        updateStatsLabel()
    }
}
