//
//  CalendarSettingsViewController.swift
//  LoopFollow
//
//  Created by Jose Paredes on 7/16/20.
//  Copyright © 2020 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit
import EventKit
import EventKitUI

class CalendarSettingsViewController: ThemedViewController, UITableViewDataSource, UITableViewDelegate {
    
    var appStateController: AppStateController?
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    // Background color used for section "cards", mirroring other settings views.
    private let sectionBackgroundColor = UIColor.systemGray.withAlphaComponent(0.15)
    
    private struct CalendarInfo {
        let title: String
        let identifier: String
    }
    
    private enum Section: Int, CaseIterable {
        case calendarIntegration
        case variables
    }
    
    private enum CalendarRow {
        case calendarAccessDeniedLabel
        case writeCalendarEvent
        case calendarIdentifier
        case watchLine1
        case watchLine2
    }
    
    private var calendars: [CalendarInfo] = []
    private var hasCalendarAccess: Bool = false
    private var isNightscoutEnabled: Bool = true
    
    private var calendarRows: [CalendarRow] {
        var rows: [CalendarRow] = []
        if !hasCalendarAccess {
            rows.append(.calendarAccessDeniedLabel)
        }
        rows.append(contentsOf: [
            .writeCalendarEvent,
            .calendarIdentifier,
            .watchLine1,
            .watchLine2
        ])
        return rows
    }
    
    private var variableRows: [CalendarLineVariable] {
        let all = CalendarLineVariable.allCases
        guard !all.isEmpty else { return [] }
        
        if isNightscoutEnabled {
            return all
        } else {
            // Hide Nightscout-specific variables when disabled, matching previous Eureka behavior.
            return all.filter { row in
                switch row {
                case .IOB, .COB, .BASAL, .LOOP, .OVERRIDE:
                    return false
                default:
                    return true
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Kalender"
        
        if UserDefaultsRepository.forceDarkMode.value {
            overrideUserInterfaceStyle = .dark
        }
        
        // Configure table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Initial Nightscout state
        showHideNSDetails()
        
        // Request calendar access and load calendars accordingly
        let eventStore = EKEventStore()
        eventStore.requestCalendarAccess { [weak self] (granted, error) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hasCalendarAccess = granted
                if granted {
                    self.reloadCalendars()
                }
                self.tableView.reloadData()
                self.showHideNSDetails()
            }
        }
    }
    
    // MARK: - Calendar loading
    
    private func reloadCalendars() {
        let store = EKEventStore()
        let ekCalendars = store.calendars(for: .event)
        calendars = ekCalendars.map { cal in
            CalendarInfo(title: cal.title, identifier: cal.calendarIdentifier)
        }
    }
    
    // MARK: - Nightscout visibility
    
    func showHideNSDetails() {
        isNightscoutEnabled = IsNightscoutEnabled()
        
        if let variablesSectionIndex = Section.allCases.firstIndex(of: .variables) {
            tableView.reloadSections(IndexSet(integer: variablesSectionIndex), with: .automatic)
        } else {
            tableView.reloadData()
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionKind = Section(rawValue: section) else { return 0 }
        switch sectionKind {
        case .calendarIntegration:
            return calendarRows.count
        case .variables:
            return variableRows.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let sectionKind = Section(rawValue: section) else { return nil }
        switch sectionKind {
        case .calendarIntegration:
            return "Kalenderintegration"
        case .variables:
            return "Tillgängliga variabler"
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let sectionKind = Section(rawValue: section) else { return nil }
        switch sectionKind {
        case .calendarIntegration:
            return "Lägg till Apples kalenderkomplikation på urtavlan på din Apple Watch eller i CarPlay för att se BG-värden. Skapa en ny kalender som heter ”Follow” och ändra kalenderinställningarna i iPhones Watch-/CarPlay-app så att endast Follow-kalendern visas på klockan eller i bilen. Det är viktigt att använda en ny kalender eftersom andra händelser i samma kalender kommer att raderas. Tryck på Linje 1 eller Linje 2 för att välja värden, ordna dem och lägga till separatorer. Värdena ersätts automatiskt med aktuella diabetesdata."
        case .variables:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let sectionKind = Section(rawValue: indexPath.section) else {
            return UITableViewCell(style: .default, reuseIdentifier: "Cell")
        }
        
        switch sectionKind {
        case .calendarIntegration:
            let rowKind = calendarRows[indexPath.row]
            switch rowKind {
            case .calendarAccessDeniedLabel:
                let cell = tableView.dequeueReusableCell(withIdentifier: "DeniedCell")
                    ?? UITableViewCell(style: .default, reuseIdentifier: "DeniedCell")
                cell.textLabel?.text = "Kalenderaccess nekades"
                cell.textLabel?.textColor = .red
                cell.selectionStyle = .none
                cell.accessoryView = nil
                cell.accessoryType = .none
                return cell
                
            case .writeCalendarEvent:
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell")
                    ?? UITableViewCell(style: .default, reuseIdentifier: "SwitchCell")
                cell.textLabel?.text = "Spara BG till kalender"
                cell.selectionStyle = .none
                
                let toggle = UISwitch()
                toggle.isOn = UserDefaultsRepository.writeCalendarEvent.value
                toggle.addTarget(self, action: #selector(writeCalendarEventChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
                cell.accessoryType = .none
                return cell
                
            case .calendarIdentifier:
                let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell")
                    ?? UITableViewCell(style: .value1, reuseIdentifier: "ValueCell")
                cell.textLabel?.text = "Kalender"
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                
                let currentId = UserDefaultsRepository.calendarIdentifier.value

                if !currentId.isEmpty,
                   let match = calendars.first(where: {
                       $0.identifier == currentId || $0.title.range(of: currentId) != nil
                   }) {
                    cell.detailTextLabel?.text = match.title
                } else {
                    cell.detailTextLabel?.text = " - "
                }
                return cell
                
            case .watchLine1:
                let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell")
                    ?? UITableViewCell(style: .value1, reuseIdentifier: "ValueCell")
                cell.textLabel?.text = "Linje 1"
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                let value = UserDefaultsRepository.watchLine1.value ?? ""
                cell.detailTextLabel?.text = CalendarLineVariable.display(value)
                cell.detailTextLabel?.numberOfLines = 0
                return cell
                
            case .watchLine2:
                let cell = tableView.dequeueReusableCell(withIdentifier: "ValueCell")
                    ?? UITableViewCell(style: .value1, reuseIdentifier: "ValueCell")
                cell.textLabel?.text = "Linje 2"
                cell.accessoryType = .disclosureIndicator
                cell.selectionStyle = .default
                let value = UserDefaultsRepository.watchLine2.value ?? ""
                cell.detailTextLabel?.text = CalendarLineVariable.display(value)
                cell.detailTextLabel?.numberOfLines = 0
                return cell
            }
            
        case .variables:
            let rowKind = variableRows[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "VariableCell")
                ?? UITableViewCell(style: .default, reuseIdentifier: "VariableCell")
            cell.selectionStyle = .none
            cell.accessoryType = .none
            
            cell.textLabel?.text = "\(rowKind.title): \(rowKind.explanation)"
            cell.textLabel?.numberOfLines = 0

            return cell
        }
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        // Match the semi-transparent card background used in other settings views, including under the accessory chevrons.
        if #available(iOS 14.0, *) {
            var background = UIBackgroundConfiguration.listGroupedCell()
            background.backgroundColor = sectionBackgroundColor
            cell.backgroundConfiguration = background
        } else {
            cell.backgroundColor = sectionBackgroundColor
            cell.contentView.backgroundColor = sectionBackgroundColor
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sectionKind = Section(rawValue: indexPath.section) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        
        switch sectionKind {
        case .calendarIntegration:
            let rowKind = calendarRows[indexPath.row]
            switch rowKind {
            case .calendarIdentifier:
                presentCalendarPicker(from: indexPath)
            case .watchLine1:
                presentWatchLineEditor(title: "Linje 1",
                                        currentValue: UserDefaultsRepository.watchLine1.value ?? "") { newValue in
                    UserDefaultsRepository.watchLine1.value = newValue
                    if let cell = tableView.cellForRow(at: indexPath) {
                        cell.detailTextLabel?.text = CalendarLineVariable.display(newValue)
                    }
                }
            case .watchLine2:
                presentWatchLineEditor(title: "Linje 2",
                                        currentValue: UserDefaultsRepository.watchLine2.value ?? "") { newValue in
                    UserDefaultsRepository.watchLine2.value = newValue
                    if let cell = tableView.cellForRow(at: indexPath) {
                        cell.detailTextLabel?.text = CalendarLineVariable.display(newValue)
                    }
                }
            default:
                break
            }
            
        case .variables:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    // MARK: - Actions
    
    @objc private func writeCalendarEventChanged(_ sender: UISwitch) {
        UserDefaultsRepository.writeCalendarEvent.value = sender.isOn
    }
    
    // MARK: - Helpers
    
    private func presentCalendarPicker(from indexPath: IndexPath) {
        guard hasCalendarAccess else {
            let alert = UIAlertController(title: "Kalenderaccess nekades",
                                          message: "Gå till Inställningar → Sekretess → Kalender för att ge Loop Follow tillgång.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        guard !calendars.isEmpty else {
            let alert = UIAlertController(title: "Inga kalendrar",
                                          message: "Inga kalendrar hittades i Kalender-appen.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let alert = UIAlertController(title: "Välj kalender", message: nil, preferredStyle: .actionSheet)
        
        let currentId = UserDefaultsRepository.calendarIdentifier.value
        
        for calendar in calendars {
            let title = calendar.title
            let style: UIAlertAction.Style = (calendar.identifier == currentId) ? .destructive : .default
            
            let action = UIAlertAction(title: title, style: style) { [weak self] _ in
                guard let self = self else { return }
                UserDefaultsRepository.calendarIdentifier.value = calendar.identifier
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel, handler: nil))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX,
                                        y: view.bounds.midY,
                                        width: 0,
                                        height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(alert, animated: true, completion: nil)
    }
    
    private func presentWatchLineEditor(title: String,
                                        currentValue: String,
                                        onSave: @escaping (String) -> Void) {
        let editor = CalendarLineEditor(title: title, value: currentValue,
                                        variables: variableRows, onSave: onSave)
        let navigation = UINavigationController(rootViewController: editor)
        navigation.overrideUserInterfaceStyle = overrideUserInterfaceStyle
        present(navigation, animated: true)
    }
}

// Keep the stored placeholders compatible with existing calendars and settings.
private enum CalendarLineVariable: String, CaseIterable {
    case BG, DIRECTION, DELTA, IOB, COB, BASAL, LOOP, OVERRIDE, MINAGO, MIN15

    var placeholder: String { "%\(self == .MIN15 ? "15MIN" : rawValue)%" }

    var title: String {
        switch self {
        case .BG, .IOB, .COB: return rawValue
        case .MINAGO: return "MinAgo"
        case .MIN15: return "15Min"
        default: return rawValue.capitalized
        }
    }

    var explanation: String {
        switch self {
        case .BG: return "Glukosvärde"
        case .DIRECTION: return "Trendpil"
        case .DELTA: return "Förändring sedan föregående värde"
        case .IOB: return "Aktivt insulin"
        case .COB: return "Aktiva kolhydrater"
        case .BASAL: return "Aktuell basal, E/h"
        case .LOOP: return "Loopstatus"
        case .OVERRIDE: return "Aktiv override i procent"
        case .MINAGO: return "Tid sedan mätning, visas endast vid gamla värden"
        case .MIN15: return "Beräknad glukostrend om 15 minuter"
        }
    }

    static func display(_ value: String) -> String {
        guard !value.isEmpty else { return "Tom rad" }
        return allCases.reduce(value) { $0.replacingOccurrences(of: $1.placeholder, with: $1.title) }
    }
}

/// A draft preserves the original string exactly until the user changes its contents.
/// Literal text from older formats stays visible and can be moved or removed too.
private struct CalendarLineDraft {
    let original: String
    var parts: [String]
    var modified = false

    init(_ value: String) {
        original = value
        let tokens = CalendarLineVariable.allCases.map { NSRegularExpression.escapedPattern(for: $0.placeholder) }
        let pattern = tokens.joined(separator: "|") + "|•"
        let expression = try! NSRegularExpression(pattern: pattern)
        let source = value as NSString
        var result: [String] = []
        var offset = 0
        for match in expression.matches(in: value, range: NSRange(location: 0, length: source.length)) {
            let literal = source.substring(with: NSRange(location: offset, length: match.range.location - offset))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !literal.isEmpty { result.append(literal) }
            result.append(source.substring(with: match.range))
            offset = NSMaxRange(match.range)
        }
        let remaining = source.substring(from: offset).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty { result.append(remaining) }
        parts = result
    }

    var value: String { modified ? parts.joined(separator: " ") : original }
}

private final class CalendarLineEditor: UITableViewController {
    private var draft: CalendarLineDraft
    private let variables: [CalendarLineVariable]
    private let onSave: (String) -> Void

    init(title: String, value: String, variables: [CalendarLineVariable], onSave: @escaping (String) -> Void) {
        draft = CalendarLineDraft(value)
        self.variables = variables
        self.onSave = onSave
        super.init(style: .insetGrouped)
        self.title = title
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Avbryt", style: .plain, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Spara", style: .done, target: self, action: #selector(save))
        tableView.allowsSelectionDuringEditing = true
        tableView.setEditing(true, animated: false)
        updateBackgroundForCurrentMode()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            updateBackgroundForCurrentMode()
        }
    }

    private func updateBackgroundForCurrentMode() {
        tableView.backgroundColor = .systemBackground
        if traitCollection.userInterfaceStyle == .dark {
            // A table background stays fixed while the editable rows scroll.
            tableView.backgroundView = GradientView(colors: ThemedViewController.themeGradientColors())
        } else {
            tableView.backgroundView = nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        var background = UIBackgroundConfiguration.listGroupedCell()
        background.backgroundColor = UIColor.systemGray.withAlphaComponent(0.15)
        cell.backgroundConfiguration = background
    }

    @objc private func cancel() { dismiss(animated: true) }
    @objc private func save() {
        onSave(draft.value)
        dismiss(animated: true)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 3 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return draft.parts.count
        default: return variables.count + 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Förhandsvisning", "Valda delar", "Lägg till"][section]
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Namnen ersätts med aktuella värden i kalendern."
        case 1: return "Dra i handtagen för att ändra ordning. Tryck på minus för att ta bort. Mellan delarna används blanksteg."
        default: return "Tryck på ett värde för att lägga till det sist i raden. Lägg till • där du vill ha en separator och dra den till rätt plats."
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = CalendarLineVariable.display(draft.value)
            cell.textLabel?.font = .preferredFont(forTextStyle: .headline)
        case 1:
            cell.textLabel?.text = CalendarLineVariable.display(draft.parts[indexPath.row])
            cell.showsReorderControl = true
        default:
            cell.selectionStyle = .default
            cell.imageView?.image = UIImage(systemName: "plus.circle.fill")
            cell.imageView?.tintColor = .systemGreen
            if indexPath.row < variables.count {
                let variable = variables[indexPath.row]
                cell.textLabel?.text = variable.title
                cell.detailTextLabel?.text = variable.explanation
            } else {
                cell.textLabel?.text = "• Separator"
            }
        }
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 2 else { return }
        draft.parts.append(indexPath.row < variables.count ? variables[indexPath.row].placeholder : "•")
        changed()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 1
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt source: IndexPath,
                            toProposedIndexPath destination: IndexPath) -> IndexPath {
        guard destination.section != 1 else { return destination }
        return IndexPath(row: destination.section < 1 ? 0 : draft.parts.count - 1, section: 1)
    }

    override func tableView(_ tableView: UITableView, moveRowAt source: IndexPath, to destination: IndexPath) {
        let part = draft.parts.remove(at: source.row)
        draft.parts.insert(part, at: destination.row)
        draft.modified = true
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.section == 1 else { return }
        draft.parts.remove(at: indexPath.row)
        changed()
    }

    private func changed() {
        draft.modified = true
        tableView.reloadData()
    }
}
