import UIKit
import Combine

extension ModernAlarmViewController {
    // MARK: - Modal Done Button
    /// Konfigurerar alltid switch.2-knappen och lägger till "Klar" när vyn är presenterad modalt.
    func configureDoneButtonIfNeeded() {
        // Om denna VC är root i en navigation controller och är presenterad modalt
        // ska vi visa både switch.2-knappen och en Klar-knapp.
        if navigationController?.viewControllers.first === self,
           presentingViewController != nil {
            let doneItem = UIBarButtonItem(
                title: "Klar",
                style: .done,
                target: self,
                action: #selector(doneButtonTapped)
            )
            // switch.2 till vänster om Klar
            navigationItem.rightBarButtonItems = [doneItem, activeAlarmsButton, alarmStatsButton]
        } else {
            // I icke-modalt läge visar vi bara switch.2-knappen
            navigationItem.rightBarButtonItems = [activeAlarmsButton, alarmStatsButton]
        }
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    @objc func activeAlarmsButtonTapped() {
        let activeVC = ActiveAlarmsViewController()
        activeVC.onDismiss = { [weak self] in
            guard let self = self else { return }
            // Rebuild snapshot based on any changes done in ActiveAlarmsViewController
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
        let nav = UINavigationController(rootViewController: activeVC)
        nav.modalPresentationStyle = .automatic
        present(nav, animated: true, completion: nil)
    }

    @objc func didTapAlarmStats() {
        let alarmstatsVC = AlarmStatsViewController()
        alarmstatsVC.onDismiss = { [weak self] in
            guard let self = self else { return }
            // Rebuild snapshot based on any changes done in ActiveAlarmsViewController
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
        let vc = AlarmStatsViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .automatic
        present(nav, animated: true)
    }

    // MARK: - Navigation Helpers

    func showSoundPicker(currentSound: String, id: String) {
        let soundVC = SoundSelectionViewController()
        soundVC.selectedSound = currentSound
        soundVC.onSelection = { [weak self] newSound in
            self?.viewModel.updateAlarmStringOption(id: id, value: newSound)
            self?.applySnapshot(animatingDifferences: false)
            self?.navigationController?.popViewController(animated: true)
        }
        navigationController?.pushViewController(soundVC, animated: true)
    }

    func showOptionPicker(title: String, current: String, options: [String], id: String) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        for option in options {
            let action = UIAlertAction(title: option, style: .default) { [weak self] _ in
                self?.viewModel.updateAlarmStringOption(id: id, value: option)
                self?.applySnapshot(animatingDifferences: false)
            }
            // Markera vald?
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: "Avbryt", style: .cancel))
        present(alert, animated: true)
    }

    func showDatePicker(title: String) {
        // Enkel implementation: ActionSheet med DatePicker inuti, eller en Custom VC
        // För "proffsig" look, pusha in en vy som heter "Snooze Settings"
    }
}
