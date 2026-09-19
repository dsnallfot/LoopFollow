import UIKit
import Combine

extension ActiveAlarmsViewController {
    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return ActiveAlarmSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section >= 0 && section < rowsBySection.count else { return 0 }
        return rowsBySection[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ActiveAlarmCell", for: indexPath)
        guard indexPath.section < rowsBySection.count,
              indexPath.row < rowsBySection[indexPath.section].count else {
            cell.textLabel?.text = nil
            cell.accessoryView = nil
            return cell
        }

        let row = rowsBySection[indexPath.section][indexPath.row]
        cell.textLabel?.text = row.title
        cell.selectionStyle = .none

        let toggle = UISwitch()
        toggle.isOn = row.getIsOn()
        toggle.tag = indexPath.section * 100 + indexPath.row
        toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        var background = UIBackgroundConfiguration.listGroupedCell()
        background.backgroundColor = UIColor.gray.withAlphaComponent(0.15)
        cell.backgroundConfiguration = background

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionType = ActiveAlarmSection(rawValue: section) else { return nil }
        return sectionType.title
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Toggla även när man trycker på raden
        guard let cell = tableView.cellForRow(at: indexPath),
              let toggle = cell.accessoryView as? UISwitch else { return }
        toggle.setOn(!toggle.isOn, animated: true)
        toggleChanged(toggle)
    }

    // MARK: - Actions

    @objc private func toggleChanged(_ sender: UISwitch) {
        let section = sender.tag / 100
        let rowIndex = sender.tag % 100
        guard section >= 0, section < rowsBySection.count,
              rowIndex >= 0, rowIndex < rowsBySection[section].count else { return }
        let row = rowsBySection[section][rowIndex]
        row.setIsOn(sender.isOn)
    }
}
