import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct ClippyHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showStats = false

    private enum RowItem {
        case reached(ClippyDailyTargetHistoryEntry)
        case missed(Date)
    }

    private var sortedHistory: [ClippyDailyTargetHistoryEntry] {
        Storage.shared.clippyDailyTargetHistory.sorted { $0.date > $1.date }
    }

    private var rows: [RowItem] {
        guard !sortedHistory.isEmpty else { return [] }

        let calendar = Calendar.current
        var result: [RowItem] = []

        for index in sortedHistory.indices {
            let entry = sortedHistory[index]
            let entryDate = Date(timeIntervalSince1970: entry.date)
            result.append(.reached(entry))

            guard index < sortedHistory.count - 1 else { continue }

            let nextEntry = sortedHistory[index + 1]
            let nextDate = Date(timeIntervalSince1970: nextEntry.date)

            let currentStartOfDay = calendar.startOfDay(for: entryDate)
            let nextStartOfDay = calendar.startOfDay(for: nextDate)

            guard let daysBetween = calendar.dateComponents([.day], from: nextStartOfDay, to: currentStartOfDay).day,
                  daysBetween > 1 else {
                continue
            }

            for offset in 1..<daysBetween {
                if let missingDay = calendar.date(byAdding: .day, value: -offset, to: currentStartOfDay) {
                    result.append(.missed(missingDay))
                }
            }
        }

        return result
    }

    private static let rowFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "yyyy-MM-dd, HH:mm"
        return formatter
    }()

    private static let missedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()
                    .ignoresSafeArea()

                if rows.isEmpty {
                    ContentUnavailableView {
                        Label("Ingen Clippy-historik", systemImage: "star.fill")
                    } description: {
                        Text("Det finns inga sparade tider ännu.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                                VStack(spacing: 0) {
                                    HStack(alignment: .center, spacing: 12) {
                                        switch row {
                                        case .reached(let entry):
                                            HStack(spacing: 8) {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(.yellow)
                                                    .frame(width: 18)
                                                Text("Mål nåddes")
                                            }

                                            Spacer(minLength: 8)

                                            Text(Self.rowFormatter.string(from: Date(timeIntervalSince1970: entry.date)))
                                                .font(.system(size: 13).monospacedDigit())
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.trailing)

                                        case .missed(let date):
                                            HStack(spacing: 8) {
                                                Image(systemName: "xmark")
                                                    .foregroundStyle(.red)
                                                    .frame(width: 18)
                                                Text("Mål nåddes ej")
                                            }

                                            Spacer(minLength: 8)

                                            Text("\(Self.missedFormatter.string(from: date)), 00:00")
                                                .font(.system(size: 13).monospacedDigit())
                                                .foregroundStyle(.secondary)
                                                .multilineTextAlignment(.trailing)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        presentLoopFollowDayReport(for: reportDate(for: row))
                                    }

                                    if index < rows.count - 1 {
                                        Divider().opacity(0.8)
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Daglig 12h TITR Målgång")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis.ascending")
                    }
                }
                ToolbarSpacer(placement: .topBarTrailing)
                
                ToolbarItemGroup(placement: .topBarTrailing) {

                    Button("Klar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showStats) {
                ClippyHistoryStatsView()
            }
        }
    }
    
    private func reportDate(for row: RowItem) -> Date {
        switch row {
        case .reached(let entry):
            return Date(timeIntervalSince1970: entry.date)
        case .missed(let date):
            return date
        }
    }

    private func presentLoopFollowDayReport(for selectedDate: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = startOfDay + 24 * 60 * 60

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

        if let rootVC = window.rootViewController {
            let presenter = topViewController(from: rootVC)
            presenter?.present(nav, animated: true)
        }
    }

    private func topViewController(from root: UIViewController?) -> UIViewController? {
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
}

