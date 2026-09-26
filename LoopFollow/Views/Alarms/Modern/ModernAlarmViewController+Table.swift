import UIKit
import Combine

extension ModernAlarmViewController {
    // MARK: - TableView Delegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }

        switch row {
        case .action(_, let id) where id == "alarmKitPermission":
            requestAlarmKitPermission()

        case .dateValue(let title, let currentDate, let id):
            showDateSheet(title: title, currentDate: currentDate, id: id)

        case .soundPicker(_, let current, let id):
            showSoundPicker(currentSound: current, id: id)

        case .optionPicker(let title, let current, let options, let id):
            showOptionPicker(title: title, current: current, options: options, id: id)

        default: break
        }
    }

    // MARK: - Section Headers & Footers

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let snapshot = dataSource.snapshot()
        guard section >= 0 && section < snapshot.sectionIdentifiers.count else {
            return nil
        }
        let sectionType = snapshot.sectionIdentifiers[section]
        switch sectionType {
        case .alarmKitSettings:
            return "AlarmKit inställningar"
        case .globalSettings:
            return "Snooza eller tysta alla larm"
        case .specificAlarm(let name):
            return "Alarminställningar för \(name)"
        case .nightSettings:
            return "Allmänna alarminställningar"
        case .inactivitySettings:
            return "Larm om Loop Follow inaktiveras"
        default:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        // Reuse the existing logic to determine the title
        guard let title = self.tableView(tableView, titleForHeaderInSection: section) else {
            return nil
        }

        let label = UILabel()
        label.text = title
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel

        let container = UIView()
        container.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        return container
    }

    func footerText(for section: Int) -> String? {
        let snapshot = dataSource.snapshot()
        guard section >= 0 && section < snapshot.sectionIdentifiers.count else {
            return nil
        }
        let sectionType = snapshot.sectionIdentifiers[section]
        if case .alarmKitSettings = sectionType {
            if #available(iOS 26.0, *) {
                return LoopFollowAlarmKit.shared.permissionText + "\nKvittering i iOS snoozar enligt larmets vanliga snoozetid. Dag/natt följer Nattid startar och Dagtid startar under Allmänna alarminställningar. Utan båda tiderna räknas dygnet som dag; vid lika tider som natt."
            }
            return "AlarmKit kräver iOS 26 eller senare. Vanliga larm används."
        }
        if case .inactivitySettings = sectionType {
            return "Aktiverat gäller både notiser och AlarmKit. AlarmKit kräver också Tillåt AlarmKit globalt och iOS-behörighet. Dag/natt bedöms vid respektive larms tidpunkt; annars används vanliga notiser. Tiderna räknas från senaste livstecknet och förutsätter aktiverad bakgrundsuppdatering."
        }
        //Förberett nedan för ev fler förklaringstexter per larm om så önskas
        //if case .specificAlarm(let name) = sectionType, name == "Låg" {
        //    return "Alerts when BG drops below value. Persistent for minutes will allow the alert to be ignored..."
        //}
        return nil
    }

}
