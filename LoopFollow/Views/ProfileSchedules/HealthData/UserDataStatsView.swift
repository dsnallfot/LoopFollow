import SwiftUI
import UIKit
import Charts


@available(iOS 16.0, *)
struct UserDataStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State var selectedMetric: Metric = .hba1c

    enum Metric: String, CaseIterable, Identifiable {
        case hba1c = "HbA1c"
        case weight = "Vikt"
        case height = "Längd"
        case bmi = "BMI"
        case tdd = "TDD"
        var id: String { rawValue }
    }

    enum ComparisonMetric: String, CaseIterable, Identifiable {
        case tdd = "TDD"
        case basal = "Basal"
        case isf = "ISF"
        case morningCR = "Morgon"
        case dayCR = "Dag"

        var id: String { rawValue }
    }

    @State var selectedComparison: ComparisonMetric = .tdd

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Övre graf – enskild metric över tid
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(Metric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if let chartConfig = chartConfig {
                    StatsLineChartWrapper(
                        entries: chartConfig.entries,
                        dates: chartConfig.dates,
                        title: selectedMetric.rawValue,
                        style: chartConfig.style
                    )
                    .frame(height: 250)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                } else {
                    Text("Ingen data att visa ännu.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding()
                        .padding(.bottom, 10)
                }

                // Nedre graf – Walsh baseline vs inställt värde
                if let walshConfig = walshChartConfig {
                    Picker("WalshMetric", selection: $selectedComparison) {
                        ForEach(ComparisonMetric.allCases) { metric in
                            Text(metric.rawValue).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Text("Jämförelse aktuella inställningar vs Walsh baseline")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                        .padding(.bottom, -8)

                    WalshComparisonLineChartWrapper(
                        walshEntries: walshConfig.walshEntries,
                        actualEntries: walshConfig.actualEntries,
                        dates: walshConfig.dates,
                        title: selectedComparison.rawValue,
                        walshLabel: walshConfig.walshLabel,
                        actualLabel: walshConfig.actualLabel
                    )
                    .frame(height: 270)
                    .padding(.horizontal)
                } else {
                    Text("Ingen Walsh-data att jämföra ännu.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
        .navigationTitle("Utveckling över tid")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Klar") { dismiss() }
            }
        }
    }
}
