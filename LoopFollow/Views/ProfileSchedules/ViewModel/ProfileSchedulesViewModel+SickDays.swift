import Foundation
import Combine

extension ProfileSchedulesViewModel {
    func reloadSickDays() {
        sickDayEntries = Storage.shared.sickDayHistory.sorted { $0.date > $1.date }
    }
    
    func deleteSickDay(_ entry: SickDayHistoryEntry) {
        var history = Storage.shared.sickDayHistory
        history.removeAll { $0 == entry }
        Storage.shared.sickDayHistory = history.sorted { $0.date < $1.date }
        NotificationCenter.default.post(name: .sickDaysUpdated, object: nil)
    }

    func loadSickDayEntries() {
        reloadSickDays()
    }
    
    func observeSickDayUpdates() {
        NotificationCenter.default.publisher(for: .sickDaysUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadSickDays()
            }
            .store(in: &cancellables)
    }
}
