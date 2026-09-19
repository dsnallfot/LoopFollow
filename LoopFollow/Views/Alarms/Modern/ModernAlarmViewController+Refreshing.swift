import UIKit
import Combine

// MARK: - Legacy AlarmUIRefreshing API
// Dessa metoder anropas från andra delar av appen (SnoozeViewController, SAge, Alarms,
// SnoozeMuteIntentHelper, SnoozeStatusView) via ViewControllerManager.shared.alarmViewController.
// Bygg om snapshoten baserat på UserDefaults när larmstatus ändras.
extension ModernAlarmViewController: AlarmUIRefreshing {

    // 2-param variant: används där datumet inte bryr sig, bara UI-refresh
    func reloadSnoozeTime(key: String, setNil: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.dataSource != nil else { return }
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
    }

    // 3-param variant: används där ett explicit datum skickas med
    func reloadSnoozeTime(key: String, setNil: Bool, value: Date) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.dataSource != nil else { return }
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
    }

    func reloadIsSnoozed(key: String, value: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.dataSource != nil else { return }
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
    }

    func reloadMuteTime(key: String, setNil: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.dataSource != nil else { return }
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
    }

    func reloadMuteTime(key: String, setNil: Bool, value: Date) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.dataSource != nil else { return }
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
    }

    func reloadIsMuted(key: String, value: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  self.isViewLoaded,
                  self.dataSource != nil else { return }
            self.viewModel.updateSnapshotData()
            self.applySnapshot(animatingDifferences: false)
        }
    }
}
