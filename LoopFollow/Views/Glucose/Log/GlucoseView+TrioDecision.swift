import UIKit
import Charts

extension GlucoseView {
    // MARK: - Trio Decision Popup for BG Points

    /// Hämtar Trio-beslutsreason för en BG-timestamp och visar som alert.
    func showTrioDecisionAlert(for timestamp: TimeInterval, onDismiss: @escaping () -> Void) {
        let bgDate = Date(timeIntervalSince1970: timestamp)
        let adjustedTimestamp = bgDate.addingTimeInterval(180)

        NightscoutUtils.fetchDeviceStatusReasonBeforeTimestamp(timestamp: adjustedTimestamp) { [weak self] result in
            guard let self = self else { return }

            let handler = { (_: UIAlertAction) in
                onDismiss()
            }

            switch result {
            case .success(let reason):
                let formattedReason = self.formatGraphReason(reason)
                let alert = UIAlertController(
                    title: "Trio behandlingsbeslut",
                    message: formattedReason,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: handler))
                self.present(alert, animated: true, completion: nil)

            case .failure(let error):
                let alert = UIAlertController(
                    title: "Fel",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: handler))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }

}
