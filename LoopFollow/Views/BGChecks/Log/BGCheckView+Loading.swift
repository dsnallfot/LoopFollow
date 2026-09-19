import UIKit
import Charts

extension BGCheckView {
    // MARK: - Loading from cache

    func showActivity() {
        guard let reloadButton = reloadButton else { return }

        if activityIndicator == nil {
            let ind = UIActivityIndicatorView(style: .medium)
            ind.hidesWhenStopped = true
            activityIndicator = ind
        }

        reloadButton.image = nil
        reloadButton.customView = activityIndicator
        activityIndicator?.startAnimating()
    }

    func hideActivity() {
        activityIndicator?.stopAnimating()
        reloadButton?.customView = nil
        reloadButton?.image = UIImage(systemName: "arrow.clockwise")
        activityIndicator = nil
    }
}
