import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension ProfileSchedulesView {
    func openSettingsLog(for term: String) {
        selectedLogSearchItem = LogSearchItem(term: term)
    }
    
    func presentSickDayAnalysis(for entry: SickDayHistoryEntry) {
        let entryDate = Date(timeIntervalSince1970: entry.date)
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: entryDate)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)

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

        guard let mainVC, let endDate else {
            return
        }

        let events = mainVC.buildEventsForMealAnalysis()

        let analysisVC = MealAnalysisView(
            events: events,
            initialStart: startDate,
            initialEnd: endDate,
            modalWithTimestamp: true,
            modalTitleString: entry.notes,
            preSelectedSegment: 6
        )

        let nav = UINavigationController(rootViewController: analysisVC)
        nav.modalPresentationStyle = .formSheet
        window.rootViewController?.present(nav, animated: true)
    }

    func presentTrainingAnalysis(for session: TrainingSessionEntry) {
        let entryDate = session.startDate
        let calendar = Calendar.current
        let startDate = entryDate//calendar.startOfDay(for: entryDate)
        let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)

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

        guard let mainVC, let endDate else {
            return
        }

        let events = mainVC.buildEventsForMealAnalysis()

        let analysisVC = MealAnalysisView(
            events: events,
            initialStart: startDate,
            initialEnd: endDate,
            modalWithTimestamp: true,
            modalTitleString: session.trainingType,
            preSelectedSegment: 2
        )

        let nav = UINavigationController(rootViewController: analysisVC)
        nav.modalPresentationStyle = .formSheet
        window.rootViewController?.present(nav, animated: true)
    }
}
