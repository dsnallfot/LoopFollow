import SwiftUI
import UIKit
import Charts

@available(iOS 26.0, *)
struct ProfileScheduleContentView: View {
    let schedules: ProfileScheduleData
    @Binding var selectedSection: ProfileSchedulesView.SectionType
    let multiChartData: [(data: [ChartDataEntry], label: String)]
    let openSettingsLog: (String) -> Void

    @ViewBuilder
    var body: some View {
        Picker("Select Section", selection: $selectedSection) {
            ForEach(ProfileSchedulesView.SectionType.allCases, id: \.self) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)

        LineChartWrapper(chartData: multiChartData, title: selectedSection.displayName)
            .frame(height: 220)
            .padding(.horizontal)

        List {
            if selectedSection == .targets {
                Section(header: sectionHeader(title: "🟪 Mål (mmol/L)", lastChanged: schedules.lastChangedTargetProfile)) {
                    ForEach(schedules.targetEntries) { entry in
                        scheduleRow(entry)
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                            .contentShape(Rectangle())
                            .onTapGesture { openSettingsLog("Mål-profil") }
                    }
                }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }

            if selectedSection == .basal {
                Section(header: sectionHeader(title: "🟪 Basal (E/h)", lastChanged: schedules.lastChangedBasalProfile)) {
                    ForEach(schedules.basalEntries) { entry in
                        scheduleRow(entry, isBold: entry.time == "Total daglig basal")
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                            .contentShape(Rectangle())
                    }
                }
                .onTapGesture { openSettingsLog("Basalprofil") }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))

                Section(header: Text("🟦 Basal IOB (E aktiv/h)")) {
                    ForEach(schedules.basalIOBEntries) { entry in
                        scheduleRow(entry, isBold: entry.time == "Medel basal IOB/h")
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                            .contentShape(Rectangle())
                    }
                }
                .onTapGesture { openSettingsLog("Basalprofil") }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }

            if selectedSection == .cr {
                Section(header: sectionHeader(title: "🟪 Insulinkvoter (g/E)", lastChanged: schedules.lastChangedCRProfile)) {
                    ForEach(schedules.carbRatioEntries) { entry in
                        scheduleRow(entry)
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                            .contentShape(Rectangle())
                    }
                }
                .onTapGesture { openSettingsLog("CR-profil") }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }

            if selectedSection == .isf {
                Section(header: sectionHeader(title: "🟪 Känslighet (mmol/L/E)", lastChanged: schedules.lastChangedISFProfile)) {
                    ForEach(schedules.isfEntries) { entry in
                        scheduleRow(entry)
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                            .contentShape(Rectangle())
                            .onTapGesture { openSettingsLog("ISF-profil") }
                    }
                }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }

            if selectedSection == .csf {
                Section(header: Text("🟪 Kh-känslighet (mmol/L/g)")) {
                    ForEach(schedules.csfEntries) { entry in
                        scheduleRow(entry)
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                    }
                }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }

            if selectedSection == .cHr {
                Section(header: Text("🟪 Minsta absorption Kh (g/h)")) {
                    ForEach(schedules.minCarbsEntries) { entry in
                        scheduleRow(entry, isBold: entry.time == "Medelvärde")
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                    }
                }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }

            if selectedSection == .smb {
                Section(header: Text("🟦 Maxgräns SMB / UAMSMB (E/SMB)")) {
                    ForEach(schedules.smbEntries) { entry in
                        scheduleRow(entry)
                            .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
                    }
                }
                .listRowBackground(Color(UIColor.systemGray).opacity(0.15))
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }

    @ViewBuilder
    private func scheduleRow(_ entry: ScheduleEntry, isBold: Bool = false) -> some View {
        HStack {
            Text(entry.time)
                .font(isBold ? .headline.bold().monospacedDigit() : .subheadline.monospacedDigit())
            Spacer()
            Text(entry.value)
                .font(isBold ? .headline.bold().monospacedDigit() : .subheadline.monospacedDigit())
        }
    }
    
    @ViewBuilder
    private func sectionHeader(title: String, lastChanged: Date?) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let d = lastChanged {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                    Text(d.formatted(.dateTime.year().month().day()))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
}
}
