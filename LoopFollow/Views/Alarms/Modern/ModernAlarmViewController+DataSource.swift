import UIKit
import Combine

extension ModernAlarmViewController {
    // MARK: - Diffable Data Source
    func configureDataSource() {
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { [weak self] (tableView, indexPath, row) -> UITableViewCell? in
            guard let self = self else { return nil }

            switch row {
            case .toggle(let title, let isOn, let id):
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingSwitchCell.reuseIdentifier, for: indexPath) as! SettingSwitchCell
                cell.configure(title: title, isOn: isOn) { [weak self] newValue in
                    guard let self = self else { return }
                    self.viewModel.updateActiveToggle(id: id, value: newValue)
                    // ViewModel har nu uppdaterat sina sektioner, bara applicera snapshot
                    self.applySnapshot()
                }
                var background = UIBackgroundConfiguration.listGroupedCell()
                background.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
                cell.backgroundConfiguration = background

                return cell

            case .valueStepper(let title, let value, let min, let max, let step, let unit, let id):
                let cell = tableView.dequeueReusableCell(withIdentifier: SettingStepperCell.reuseIdentifier, for: indexPath) as! SettingStepperCell
                cell.configure(title: title, value: value, min: min, max: max, step: step, unit: unit) { [weak self] newValue in
                    self?.viewModel.updateAlarmValue(id: id, value: newValue)
                }
                var background = UIBackgroundConfiguration.listGroupedCell()
                background.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
                cell.backgroundConfiguration = background

                return cell

            case .soundPicker(let title, let currentSound, _):
                let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)

                var background = UIBackgroundConfiguration.listGroupedCell()
                background.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
                cell.backgroundConfiguration = background

                cell.textLabel?.text = title
                cell.accessoryType = .disclosureIndicator

                // Skapa en modern detail label
                let detailLabel = UILabel()
                detailLabel.text = currentSound.replacingOccurrences(of: "_", with: " ")
                detailLabel.textColor = .secondaryLabel
                detailLabel.sizeToFit()
                cell.accessoryView = detailLabel
                return cell

            case .optionPicker(let title, let currentOption, _, _):
                let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)

                var background = UIBackgroundConfiguration.listGroupedCell()
                background.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
                cell.backgroundConfiguration = background

                cell.textLabel?.text = title
                cell.detailTextLabel?.text = currentOption
                cell.accessoryType = .disclosureIndicator

                let detailLabel = UILabel()
                detailLabel.text = currentOption
                detailLabel.textColor = .secondaryLabel
                detailLabel.sizeToFit()
                cell.accessoryView = detailLabel
                return cell

            case .dateValue(let title, let date, let id):
                let cell = tableView.dequeueReusableCell(withIdentifier: "DefaultCell", for: indexPath)

                var background = UIBackgroundConfiguration.listGroupedCell()
                background.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
                cell.backgroundConfiguration = background

                cell.textLabel?.text = title

                let detailLabel = UILabel()
                detailLabel.textColor = .secondaryLabel

                if let date = date {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    detailLabel.text = formatter.string(from: date)
                } else {
                    // Dynamisk text baserat på ID
                    if id.contains("Snooze") || id.contains("snoozed") {
                        detailLabel.text = "Ej snoozad"
                    } else if id.contains("Mute") {
                        detailLabel.text = "Ej tystad"
                    } else {
                        detailLabel.text = "Ej inställd"
                    }
                }

                detailLabel.sizeToFit()
                cell.accessoryView = detailLabel
                return cell

            default:
                return UITableViewCell()
            }
        }
    }

    func applySnapshot(animatingDifferences: Bool = true) {
        guard isViewLoaded, dataSource != nil else { return }
        var snapshot = NSDiffableDataSourceSnapshot<AlarmSection, AlarmRow>()
        snapshot.appendSections(viewModel.sections)

        for section in viewModel.sections {
            snapshot.appendItems(viewModel.rows(for: section), toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

}
