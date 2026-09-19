import UIKit
import Charts

extension BGCheckView {
    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch mode {
        case .fingerstick:
            return fingerstickEntries.count
        case .dextro:
            return dextroEntries.count
        }
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch mode {
        case .fingerstick:
            let cell = tableView.dequeueReusableCell(withIdentifier: "BGCheckCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "BGCheckCell")
            cell.textLabel?.numberOfLines = 1

            let entry = fingerstickEntries[indexPath.row]

            let mmolString = valueFormatter.string(from: NSNumber(value: entry.mmol)) ?? String(format: "%.1f", entry.mmol)

            var text = "\(mmolString) mmol/L".replacingOccurrences(of: ",", with: ".")
            if entry.hasDextroNearby {
                text += " 🍬"
            }

        cell.textLabel?.text = text
        cell.textLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)//.systemFont(ofSize: 17)

            if let cgm10 = entry.cgm10mMmol, let delta = entry.delta10m {
                let cgmString = valueFormatter.string(from: NSNumber(value: cgm10)) ?? String(format: "%.1f", cgm10)
                let deltaString = deltaFormatter.string(from: NSNumber(value: delta)) ?? String(format: "%+.1f", delta)

                cell.detailTextLabel?.text = "CGM +10 min: \(cgmString) Δ \(deltaString)".replacingOccurrences(of: ",", with: ".")
                cell.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)//.systemFont(ofSize: 12)
                cell.detailTextLabel?.textColor = .secondaryLabel
            } else {
                cell.detailTextLabel?.text = nil
            }

            cell.imageView?.image = UIImage(systemName: "drop.fill")
            cell.imageView?.tintColor = .systemRed

            let rightLabel = UILabel()
            rightLabel.text = DateFormatter.localizedString(from: entry.date, dateStyle: .short, timeStyle: .short)
            rightLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)//.systemFont(ofSize: 14)
            rightLabel.textColor = .secondaryLabel
            rightLabel.textAlignment = .right
            rightLabel.sizeToFit()
            cell.accessoryView = rightLabel

            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.backgroundView = nil
            if #available(iOS 14.0, *) {
                cell.backgroundConfiguration = nil
            }
            cell.textLabel?.backgroundColor = .clear
            cell.detailTextLabel?.backgroundColor = .clear

            cell.selectionStyle = .default
            cell.accessoryType = .none
            let selected = UIView()
            selected.backgroundColor = UIColor.label.withAlphaComponent(0.2)
            selected.layer.cornerRadius = 10
            selected.layer.masksToBounds = true
            cell.selectedBackgroundView = selected
            return cell

        case .dextro:
            let cell = tableView.dequeueReusableCell(withIdentifier: "LowTreatmentCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "LowTreatmentCell")
            cell.textLabel?.numberOfLines = 1

            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.backgroundView = nil
            if #available(iOS 14.0, *) {
                cell.backgroundConfiguration = nil
            }
            cell.textLabel?.backgroundColor = .clear
            cell.detailTextLabel?.backgroundColor = .clear

            let entry = dextroEntries[indexPath.row]
            let gramsString = gramsFormatter.string(from: NSNumber(value: entry.grams)) ?? String(format: "%.0f", entry.grams)

            if let cgm = entry.cgmMmol {
                let cgmString = mmolFormatter.string(from: NSNumber(value: cgm)) ?? String(format: "%.1f", cgm)
                if entry.hasBGCheckNearby, let bg = entry.bgCheckMmol {
                    let bgString = mmolFormatter.string(from: NSNumber(value: bg)) ?? String(format: "%.1f", bg)
                    cell.detailTextLabel?.text = "CGM: \(cgmString) • Finger: \(bgString) mmol/L".replacingOccurrences(of: ",", with: ".")
                } else {
                    cell.detailTextLabel?.text = "CGM: \(cgmString) mmol/L".replacingOccurrences(of: ",", with: ".")
                }
                cell.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)//.systemFont(ofSize: 12)
                cell.detailTextLabel?.textColor = .secondaryLabel
            } else {
                cell.detailTextLabel?.text = nil
            }

            var text = "Dextro • \(gramsString) g".replacingOccurrences(of: ",", with: ".")
            if entry.hasBGCheckNearby {
                text += " 🩸"
            }
            cell.textLabel?.text = text
            cell.textLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)//.systemFont(ofSize: 17)

            cell.imageView?.image = UIImage(systemName: "pill.fill")
            cell.imageView?.tintColor = .label

            let rightLabel = UILabel()
            rightLabel.text = DateFormatter.localizedString(from: entry.date, dateStyle: .short, timeStyle: .short)
            rightLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)//.systemFont(ofSize: 14)
            rightLabel.textColor = .secondaryLabel
            rightLabel.textAlignment = .right
            rightLabel.sizeToFit()
            cell.accessoryView = rightLabel

            cell.selectionStyle = .default
            cell.accessoryType = .none
            let selected = UIView()
            selected.backgroundColor = UIColor.label.withAlphaComponent(0.2)
            selected.layer.cornerRadius = 10
            selected.layer.masksToBounds = true
            cell.selectedBackgroundView = selected
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entryDate: Date
        let modalTitle: String

        switch mode {
        case .fingerstick:
            let entry = fingerstickEntries[indexPath.row]
            entryDate = entry.date
            modalTitle = "Analys Stick"
        case .dextro:
            let entry = dextroEntries[indexPath.row]
            entryDate = entry.date
            modalTitle = "Analys Dextro"
        }
        let startDate = entryDate - 60 * 20  // 20 min före
        let endDate = entryDate + 60 * 180  // 160 min efter

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow }),
            let tabBar = window.rootViewController as? UITabBarController,
            let tabViewControllers = tabBar.viewControllers
        else {
            return
        }

        var mainVC: MainViewController?

        for vc in tabViewControllers {
            if let nav = vc as? UINavigationController {
                if let candidate = nav.viewControllers.first(where: { $0 is MainViewController }) as? MainViewController {
                    mainVC = candidate
                    break
                }
            } else if let candidate = vc as? MainViewController {
                mainVC = candidate
                break
            }
        }

        guard let mainVC else {
            return
        }

        let events = mainVC.buildEventsForMealAnalysis()

        let analysisVC = MealAnalysisView(
            events: events,
            initialStart: startDate,
            initialEnd: nil,
            modalWithTimestamp: true,
            modalTitleString: modalTitle,
            preSelectedSegment: 2
        )
        let nav = UINavigationController(rootViewController: analysisVC)
        nav.modalPresentationStyle = .formSheet
        self.present(nav, animated: true) { [weak self] in
            self?.tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}
