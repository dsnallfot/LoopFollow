import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct NightscoutDayReportView: View {
    let date: Date

    var body: some View {
        NightscoutDayReportControllerRepresentable(date: date)
            .ignoresSafeArea()
    }
}

struct NightscoutDayReportControllerRepresentable: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let date: Date

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = NightscoutDayReportViewController()
        vc.reportDate = date
        vc.onClose = { dismiss() }
        let nav = UINavigationController(rootViewController: vc)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let vc = uiViewController.viewControllers.first as? NightscoutDayReportViewController {
            vc.reportDate = date
        }
    }
}

