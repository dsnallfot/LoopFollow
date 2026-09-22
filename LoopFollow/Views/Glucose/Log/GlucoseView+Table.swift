import UIKit
import Charts

extension GlucoseView {
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "GlucoseCell", for: indexPath) as? Value1TableViewCell else {
            return UITableViewCell(style: .value1, reuseIdentifier: "GlucoseCell")
        }

        let row = filteredRows[indexPath.row]

        // Ensure selection overlay renders over our gradient (avoid iOS 14+ backgroundConfiguration overriding)
        if #available(iOS 14.0, *) {
            cell.backgroundConfiguration = nil
        }

        // Match Treatments-style selection highlight (subtle overlay over the gradient)
        cell.selectionStyle = .default
        let selected = UIView()
        selected.backgroundColor = UIColor.label.withAlphaComponent(0.2)
        selected.layer.cornerRadius = 10
        selected.layer.masksToBounds = true
        cell.selectedBackgroundView = selected

        switch row {
        case .glucose(let entry):
            let valueString = String(format: "%.1f mmol/L", entry.mmol)
            let targetMgdl = Double(UserDefaultsRepository.targetLine.value)
            let targetMmolRaw = targetMgdl * GlucoseConversion.mgDlToMmolL

            // Avrunda target till 1 decimal
            let targetMmol = (targetMmolRaw * 10).rounded() / 10

            if abs(entry.mmol - 5.5) < 0.02 {
                cell.textLabel?.text = valueString + " 🦄"
            //} else if abs(entry.mmol - 6.7) < 0.02 {
            //    cell.textLabel?.text = valueString + " 👐"
            } else if abs(entry.mmol - targetMmol) < 0.02 {
                cell.textLabel?.text = valueString + " 🎯"
            } else if isSuspectedCompressionLow(entry: entry) {
                cell.textLabel?.text = valueString + " 🗜️"
            } else if abs(entry.mmol - 2.2) < 0.04 {
                cell.textLabel?.text = valueString + " 🆘"
            } else if abs(entry.mmol - 22.2) < 0.04 {
                cell.textLabel?.text = valueString + " ⚠️"
            } else {
                cell.textLabel?.text = valueString
            }

            if entry.delayedReading, let sentAt = entry.trioSentAt {
                cell.textLabel?.text = (cell.textLabel?.text ?? valueString)
                    + " ⏱️(\(timeFormatter.string(from: sentAt)))"
            }

            cell.textLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)//.systemFont(ofSize: 17)
            cell.detailTextLabel?.text = timeFormatter.string(from: entry.date)
            cell.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
            let tint = entry.delayedReading ? UIColor.systemBlue.withAlphaComponent(0.15) : .clear
            cell.backgroundColor = tint
            cell.contentView.backgroundColor = tint

        case .missing(let date, let reason):
            // Detect placeholder: no actual missing rows and showOnlyMissingGlucose = true
            let isPlaceholder = showOnlyMissingGlucose && dayRowsIncludingMissing.filter { $0.isMissing }.isEmpty
            if isPlaceholder {
                cell.textLabel?.text = "Inga filtrerade värden denna dag ✅"
                cell.detailTextLabel?.text = ""
                cell.textLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)//.systemFont(ofSize: 17)
                let tint = UIColor.systemGreen.withAlphaComponent(0.12)
                cell.backgroundColor = tint
                cell.contentView.backgroundColor = tint
            } else {
                switch reason {
                case .sensor:
                    cell.textLabel?.text = "[Sensoravläsning saknas]"
                    cell.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
                    cell.contentView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.15)
                }
                cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
                cell.detailTextLabel?.text = timeFormatter.string(from: date)
                cell.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
            }

        case .sensorError(let date, let durationMinutes, _):
            cell.textLabel?.text = "Sensorfel • \(durationMinutes) min"
            cell.textLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)//.systemFont(ofSize: 17, weight: .semibold)

            let df = DateFormatter()
            df.locale = Locale(identifier: "sv_SE")
            df.dateFormat = "yyyy-MM-dd, HH:mm"
            cell.detailTextLabel?.text = df.string(from: date)
            cell.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)

            let tint = UIColor.systemRed.withAlphaComponent(0.15)
            cell.backgroundColor = tint
            cell.contentView.backgroundColor = tint
        }

        cell.accessoryType = .none
        return cell
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = filteredRows[indexPath.row]
        switch row {
        case .glucose(let entry):
            let timestamp = entry.date.timeIntervalSince1970
            showTrioDecisionAlert(for: timestamp) {
                DispatchQueue.main.async {
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            }

        case .missing(let date, let reason):
            // Do not show alert for placeholder row ("Inga saknade värden denna dag")
            let isPlaceholder = showOnlyMissingGlucose && dayRowsIncludingMissing.filter { $0.isMissing }.isEmpty
            if isPlaceholder {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            showSensorStatusAlert(forMissingDate: date, reason: reason) {
                DispatchQueue.main.async {
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            }

        case .sensorError(_, let durationMinutes, let note):
            showExactDexcomNoteAlert(note: note, durationMinutes: durationMinutes) {
                DispatchQueue.main.async {
                    tableView.deselectRow(at: indexPath, animated: true)
                }
            }
        }
    }

}
