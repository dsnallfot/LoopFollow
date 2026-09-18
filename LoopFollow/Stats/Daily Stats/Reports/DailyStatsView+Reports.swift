import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension DailyStatsView {
    // Öppnar MealAnalysisView för den valda dagen med start kl 00:00
    private func presentLoopFollowDayReport() {
        guard let selectedDateForReport else { return }

        // Säkerställ att vi använder dagens start (00:00)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDateForReport)
        let endOfDay = startOfDay + 24 * 60 * 60

        // Hitta MainViewController via root UITabBarController för att bygga events
        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow }),
            let tabBar = window.rootViewController as? UITabBarController,
            let tabViewControllers = tabBar.viewControllers
        else {
            return
        }

        var mainVC: MainViewController?

        for vc in tabViewControllers {
            if let nav = vc as? UINavigationController {
                if let candidate = nav.viewControllers.first(where: { $0 is MainViewController }) as? MainViewController {
                    mainVC = candidate
                    break
                }
            } else if let candidate = vc as? MainViewController {
                mainVC = candidate
                break
            }
        }

        guard let mainVC else { return }

        // Bygg events via MainViewController
        let events = mainVC.buildEventsForMealAnalysis()

        let analysisVC = MealAnalysisView(
            events: events,
            initialStart: startOfDay,
            initialEnd: endOfDay,
            modalWithTimestamp: true,
            modalTitleString: "Dagens utfall",
            preSelectedSegment: nil
        )
        let nav = UINavigationController(rootViewController: analysisVC)
        nav.modalPresentationStyle = .formSheet

        // Presentera från den översta vyn (t.ex. DailyStatsView's hosting controller),
        // så att vi kommer tillbaka hit när modalen stängs.
        if let rootVC = window.rootViewController {
            let presenter = DailyStatsView.topViewController(from: rootVC)
            presenter?.present(nav, animated: true)
        }
    }

    var nightscoutAlertOverlay: some View {
        Color.clear
            .allowsHitTesting(false)
            .alert(
                "Visa dagsrapport?",
                isPresented: $showNightscoutAlert
            ) {
                Button("Avbryt", role: .cancel) { }
                Button("Visa i Loop Follow") {
                    presentLoopFollowDayReport()
                }
                Button("Öppna i Nightscout") {
                    showNightscoutReport = true
                }
            } message: {
                if let date = selectedDateForReport {
                    Text("Datum: \(dateFormatter.string(from: date))")
                } else {
                    Text("Visa daglig rapport.")
                }
            }
    }

    /// Hjälpfunktion för att hitta den översta presenterade viewcontrollern,
    /// oavsett om vi är i en TabBar, NavigationController eller presenterad stack.
    private static func topViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
    
    func selectReportDate(_ date: Date) {
        selectedDateForReport = date
        showNightscoutAlert = true
    }
}
