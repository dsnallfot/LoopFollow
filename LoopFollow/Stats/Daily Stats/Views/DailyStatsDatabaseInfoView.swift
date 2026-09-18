import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct DailyStatsDatabaseInfoView: View {
    let mainViewController: MainViewController?
    @Binding var showDatabaseInfo: Bool

    @ViewBuilder
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackground()

                VStack(spacing: 16) {
                    if let mainVC = mainViewController {
                        // Formatter for date/time rows
                        let dateTimeFormatter: DateFormatter = {
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd HH:mm"
                            return df
                        }()

                        // Precompute texts to keep the view tree simple
                        let lastUpdatedText: String = {
                            if let lastUpdated = mainVC.statsCacheLastUpdated {
                                return dateTimeFormatter.string(from: lastUpdated)
                            } else {
                                return "—"
                            }
                        }()

                        let oldestTimestamp: TimeInterval? = {
                            let oldestBG = mainVC.statsBGData.min(by: { $0.date < $1.date })?.date
                            let oldestBolus = mainVC.statsBolusData.min(by: { $0.date < $1.date })?.date
                            let oldestSMB = mainVC.statsSMBData.min(by: { $0.date < $1.date })?.date
                            let oldestCarb = mainVC.statsCarbData.min(by: { $0.date < $1.date })?.date
                            let oldestBasal = mainVC.statsBasalData.min(by: { $0.date < $1.date })?.date
                            let oldestBGCheck = mainVC.statsBGCheckData.min()

                            return [oldestBG, oldestBolus, oldestSMB, oldestCarb, oldestBasal, oldestBGCheck]
                                .compactMap { $0 }
                                .min()
                        }()

                        let oldestEntryText: String = {
                            if let oldest = oldestTimestamp {
                                let oldestDate = Date(timeIntervalSince1970: oldest)
                                return dateTimeFormatter.string(from: oldestDate)
                            } else {
                                return "—"
                            }
                        }()

                        let newestTimestamp: TimeInterval? = {
                            let newestBG = mainVC.statsBGData.max(by: { $0.date < $1.date })?.date
                            let newestBolus = mainVC.statsBolusData.max(by: { $0.date < $1.date })?.date
                            let newestSMB = mainVC.statsSMBData.max(by: { $0.date < $1.date })?.date
                            let newestCarb = mainVC.statsCarbData.max(by: { $0.date < $1.date })?.date
                            let newestBasal = mainVC.statsBasalData.max(by: { $0.date < $1.date })?.date
                            let newestBGCheck = mainVC.statsBGCheckData.max()

                            return [newestBG, newestBolus, newestSMB, newestCarb, newestBasal, newestBGCheck]
                                .compactMap { $0 }
                                .max()
                        }()

                        let newestEntryText: String = {
                            if let newest = newestTimestamp {
                                let newestDate = Date(timeIntervalSince1970: newest)
                                return dateTimeFormatter.string(from: newestDate)
                            } else {
                                return "—"
                            }
                        }()

                        // Metadata rows
                        Group {
                            HStack {
                                Text("Databas uppdaterad:")
                                Spacer()
                                Text(lastUpdatedText)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Äldsta post:")
                                Spacer()
                                Text(oldestEntryText)
                                    .foregroundColor(.secondary)
                            }

                            HStack {
                                Text("Nyaste post:")
                                Spacer()
                                Text(newestEntryText)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .font(.footnote)

                        Divider()
                            .padding(.vertical, 4)

                        // Content rows with leading label and trailing value
                        Group {
                            HStack {
                                Text("Glukosavläsningar:")
                                Spacer()
                                Text("\(mainVC.statsBGData.count) st")
                            }
                            HStack {
                                Text("Fingerstick:")
                                Spacer()
                                Text("\(mainVC.statsBGCheckData.count) st")
                            }
                            HStack {
                                Text("Manuell bolus:")
                                Spacer()
                                Text("\(mainVC.statsBolusData.count) st")
                            }
                            HStack {
                                Text("SMB:")
                                Spacer()
                                Text("\(mainVC.statsSMBData.count) st")
                            }
                            HStack {
                                Text("Måltider (Kolhydrater):")
                                Spacer()
                                Text("\(mainVC.statsCarbData.count) st")
                            }
                            HStack {
                                Text("Temp basal:")
                                Spacer()
                                Text("\(mainVC.statsBasalData.count) st")
                            }
                        }
                        .font(.body)
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        Group {
                            HStack {
                                Text("Glukosavläsningar per dag:")
                                Spacer()
                                Text(String(format: "%.0f st", Double(mainVC.statsBGData.count) / 91.0))
                            }
                            HStack {
                                Text("Fingerstick per dag:")
                                Spacer()
                                Text(String(format: "%.1f st", Double(mainVC.statsBGCheckData.count) / 91.0))
                            }
                            HStack {
                                Text("Manuell bolus per dag:")
                                Spacer()
                                Text(String(format: "%.0f st", Double(mainVC.statsBolusData.count) / 91.0))
                            }
                            HStack {
                                Text("SMB per dag:")
                                Spacer()
                                Text(String(format: "%.0f st", Double(mainVC.statsSMBData.count) / 91.0))
                            }
                            HStack {
                                Text("Måltider (Kolhydrater) per dag:")
                                Spacer()
                                Text(String(format: "%.0f st", Double(mainVC.statsCarbData.count) / 91.0))
                            }
                            HStack {
                                Text("Temp basal per dag:")
                                Spacer()
                                Text(String(format: "%.0f st", Double(mainVC.statsBasalData.count) / 91.0))
                            }
                        }
                        .font(.body)

                    } else {
                        Text("Ingen data tillgänglig.")
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Databasens innehåll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") {
                        showDatabaseInfo = false
                    }
                }
            }
        }
    }
}
