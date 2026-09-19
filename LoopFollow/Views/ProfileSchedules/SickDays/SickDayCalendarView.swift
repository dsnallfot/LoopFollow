import SwiftUI
import UIKit


@available(iOS 16.0, *)
struct SickDayCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    let entries: [SickDayHistoryEntry]

    private var sickDayEntriesByDay: [Date: SickDayHistoryEntry] {
        Dictionary(
            uniqueKeysWithValues: entries.map {
                (calendar.startOfDay(for: Date(timeIntervalSince1970: $0.date)), $0)
            }
        )
    }

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "sv_SE")
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    private let monthSymbols: [String] = [
        "Januari", "Februari", "Mars",
        "April", "Maj", "Juni",
        "Juli", "Augusti", "September",
        "Oktober", "November", "December"
    ]

    private let weekdayHeaders = ["M", "T", "O", "T", "F", "L", "S"]

    private var sickDaySet: Set<Date> {
        Set(entries.map { calendar.startOfDay(for: Date(timeIntervalSince1970: $0.date)) })
    }

    private var displayYears: [Int] {
        let currentYear = calendar.component(.year, from: Date())
        let sickYears = entries.map { entry in
            calendar.component(.year, from: Date(timeIntervalSince1970: entry.date))
        }
        let earliestSickYear = sickYears.min() ?? currentYear
        let earliestDisplayYear = min(earliestSickYear, currentYear - 1)
        return Array(earliestDisplayYear...currentYear)
    }

    private func presentSickDayAnalysis(for entry: SickDayHistoryEntry) {
        let entryDate = Date(timeIntervalSince1970: entry.date)
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

        func topMostPresenter(from root: UIViewController) -> UIViewController {
            var current = root
            while let presented = current.presentedViewController {
                current = presented
            }
            return current
        }

        let presenter = topMostPresenter(from: window.rootViewController ?? tabBar)
        presenter.present(nav, animated: true)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ThemeBackground()
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        Color.clear
                            .frame(height: 1)
                            .id("calendarTopAnchor")

                        ForEach(displayYears, id: \.self) { year in
                            VStack(alignment: .leading, spacing: 16) {
                                Text(String(year))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.horizontal)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top), count: 3), spacing: 28) {
                                    ForEach(1...12, id: \.self) { month in
                                        SickDayMiniMonthView(
                                            year: year,
                                            month: month,
                                            calendar: calendar,
                                            monthName: monthSymbols[month - 1],
                                            weekdayHeaders: weekdayHeaders,
                                            sickDaySet: sickDaySet,
                                            sickDayEntriesByDay: sickDayEntriesByDay,
                                            onTapSickDay: { entry in
                                                presentSickDayAnalysis(for: entry)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Sjukdagshistorik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") {
                        dismiss()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ScrollSickDayCalendarToCurrentYear"))) { _ in
                let currentYear = calendar.component(.year, from: Date())
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(currentYear, anchor: .top)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("ScrollSickDayCalendarToCurrentYear"), object: nil)
            }
        }
    }
}
