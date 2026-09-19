import SwiftUI
import UIKit


@available(iOS 17.0, *)
struct TrainingStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: PeriodOption = .d14
    let sessions: [TrainingSessionEntry]

    private enum PeriodOption: CaseIterable {
        case d7, d14, d30, d90

        var days: Int {
            switch self {
            case .d7: return 7
            case .d14: return 14
            case .d30: return 30
            case .d90: return 90
            }
        }

        var title: String {
            switch self {
            case .d7: return "7 d"
            case .d14: return "14 d"
            case .d30: return "30 d"
            case .d90: return "90 d"
            }
        }
    }

    struct DayTotal: Identifiable {
        let id = UUID()
        let date: Date
        let metaQuestMinutes: Double
        let otherTrainingMinutes: Double
        let gympaMinutes: Double
        let highActivityMinutes: Double

        var minutes: Double {
            metaQuestMinutes + otherTrainingMinutes + gympaMinutes + highActivityMinutes
        }
    }

    private var filteredSessions: [TrainingSessionEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today
        let endDayExclusive = calendar.date(byAdding: .day, value: 1, to: today) ?? Date.distantFuture

        return sessions.filter { session in
            session.startDate >= startDay && session.startDate < endDayExclusive
        }
    }

    private var totalsPerDay: [DayTotal] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.date(byAdding: .day, value: -(selectedPeriod.days - 1), to: today) ?? today

        struct Bucket {
            var metaQuest: Double = 0
            var otherTraining: Double = 0
            var gympa: Double = 0
            var highActivity: Double = 0
        }

        var dict: [Date: Bucket] = [:]
        var days: [Date] = []

        for offset in 0..<selectedPeriod.days {
            if let day = calendar.date(byAdding: .day, value: offset, to: startDay) {
                let startOfDay = calendar.startOfDay(for: day)
                days.append(startOfDay)
                dict[startOfDay] = Bucket()
            }
        }

        for session in filteredSessions {
            let start = session.startDate
            let end = session.endDate ?? now
            let minutes = max(0, end.timeIntervalSince(start) / 60.0)
            let day = calendar.startOfDay(for: start)
            guard var bucket = dict[day] else { continue }

            switch session.category {
            case .metaQuest:
                bucket.metaQuest += minutes
            case .training:
                bucket.otherTraining += minutes
            case .gympa:
                bucket.gympa += minutes
            case .highActivity:
                bucket.highActivity += minutes
            }

            dict[day] = bucket
        }

        return days.map {
            let bucket = dict[$0] ?? Bucket()
            return DayTotal(
                date: $0,
                metaQuestMinutes: bucket.metaQuest,
                otherTrainingMinutes: bucket.otherTraining,
                gympaMinutes: bucket.gympa,
                highActivityMinutes: bucket.highActivity
            )
        }
    }

    private var totalSessionCount: Int {
        filteredSessions.count
    }

    private var averageMinutesPerSession: Double {
        guard totalSessionCount > 0 else { return 0 }
        let totalMinutes = filteredSessions.reduce(0.0) { partial, session in
            let end = session.endDate ?? Date()
            return partial + max(0, end.timeIntervalSince(session.startDate) / 60.0)
        }
        return totalMinutes / Double(totalSessionCount)
    }

    private var trainingDaysCount: Int {
        totalsPerDay.filter { $0.minutes > 0 }.count
    }

    private var averageMinutesPerTrainingDay: Double {
        guard trainingDaysCount > 0 else { return 0 }
        let totalMinutes = totalsPerDay.reduce(0.0) { $0 + $1.minutes }
        return totalMinutes / Double(trainingDaysCount)
    }

    private var percentageDaysWithTraining: Double {
        guard !totalsPerDay.isEmpty else { return 0 }
        return Double(trainingDaysCount) * 100.0 / Double(totalsPerDay.count)
    }

    private var longestTrainingStreak: Int {
        var best = 0
        var current = 0
        for item in totalsPerDay {
            if item.minutes > 0 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private static let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "sv_SE")
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 0
        return nf
    }()

    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(PeriodOption.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if totalsPerDay.allSatisfy({ $0.minutes == 0 }) {
                        ContentUnavailableView(
                            "Ingen träningsdata",
                            systemImage: "chart.bar",
                            description: Text("När träningssessioner registreras visas statistik här.")
                        )
                        .padding(.top, 40)
                    } else {
                        TrainingStatsBarChartView(dayTotals: totalsPerDay)
                            .frame(height: 320)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        VStack(spacing: 0) {
                            TrainingStatsRow(
                                title: "Totalt antal träningssessioner",
                                value: "\(totalSessionCount) st"
                            )
                            Divider().padding(.leading, 16)

                            TrainingStatsRow(
                                title: "Tid per träningssession",
                                value: "\(Int(averageMinutesPerSession.rounded())) min"
                            )
                            Divider().padding(.leading, 16)

                            TrainingStatsRow(
                                title: "Träningstid per träningsdag",
                                value: "\(Int(averageMinutesPerTrainingDay.rounded())) min"
                            )
                            Divider().padding(.leading, 16)

                            TrainingStatsRow(
                                title: "Andel dagar med träning",
                                value: "\(Int(percentageDaysWithTraining.rounded()))%"
                            )
                            Divider().padding(.leading, 16)

                            TrainingStatsRow(
                                title: "Längsta streak dagar med träning",
                                value: "\(longestTrainingStreak) d"
                            )
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(UIColor.systemGray).opacity(0.15))
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("Träningsstatistik")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Klar") {
                    dismiss()
                }
            }
        }
    }
}

@available(iOS 17.0, *)
private struct TrainingStatsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundColor(.primary)

            Spacer(minLength: 8)

            Text(value)
                .font(.body.monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

