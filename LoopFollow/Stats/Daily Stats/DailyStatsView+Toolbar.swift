import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension DailyStatsView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showWeekdayFilter = true
            } label: {
                let (symbolName, symbolColor): (String, Color) = {
                    if viewModel.usePumpChangeDays {
                        // Pumpbytesdagar-filter aktivt
                        return ("fuelpump", .blue)
                    }
                    if viewModel.useSensorChangeDays {
                        // Sensorbytesdagar-filter aktivt
                        return ("sensor.tag.radiowaves.forward", .blue)
                    }
                    if viewModel.useSickDays {
                        // Sjukdagar-filter aktivt
                        return ("medical.thermometer", .blue)
                    }
                    if viewModel.useNonSickDays {
                        // Ej sjukdagar-filter aktivt
                        return ("figure.taichi", .blue)
                    }

                    let weekdayCount = viewModel.selectedWeekdays.count
                    switch weekdayCount {
                    case 7:
                        // Alla dagar valda – standardkalender, neutral färg
                        return ("7.calendar", .primary)
                    case 0:
                        // Inga dagar valda – varna med badge
                        return ("calendar.badge.exclamationmark", .blue)
                    case 1...6:
                        // 1–6 dagar valda – använd siffra + kalender
                        return ("\(weekdayCount).calendar", .blue)
                    default:
                        // Fallback
                        return ("calendar", .primary)
                    }
                }()

                Image(systemName: symbolName)
                    .foregroundColor(symbolColor)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                exportCSV()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showDatabaseInfo = true
            } label: {
                Image(systemName: "internaldrive")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showClippyHistoryStats = true
            } label: {
                Image(systemName: "target")
            }
        }

        ToolbarSpacer(placement: .topBarTrailing)

        if showsDoneButton {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Klar") {
                    dismiss()
                }
            }
        }
    }

    func loadOnAppear() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            viewModel.loadDailyStats()
        }
        LogManager.shared.log(
            category: .analysis,
            message: "SUMMARY appear – rows=\(viewModel.rows.count), sufficient=\(viewModel.rowsWithSufficientGlucose.count), daysToAnalyze=\(viewModel.dataService.daysToAnalyze)",
            isDebug: true
        )
    }

    private func exportCSV() {
        if let url = viewModel.writeCSVToDisk() {
            exportURL = url
        }
    }
}
