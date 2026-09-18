// LoopFollow
// DailyStatsView.swift

import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct DailyStatsView: View {
    @ObservedObject var viewModel: DailyStatsViewModel
    var showsDoneButton: Bool = true
    @Environment(\.dismiss) var dismiss
    
    @State var exportURL: URL?
    @State private var showingTitrSummary: Bool = true
    @State var selectedDateForReport: Date?
    @State var showNightscoutAlert: Bool = false
    @State var showNightscoutReport: Bool = false
    @State var showDatabaseInfo: Bool = false
    @State var showWeekdayFilter: Bool = false
    @State private var showRealCRandTitrChart: Bool = false
    @State var showClippyHistoryStats: Bool = false
    
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = " yy-MM-dd"
        return df
    }()
    
    @available(iOS 26.0, *)
    var body: some View {
        ZStack {
            ThemeBackground()
            coreContent
                .navigationTitle("Dag")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .onAppear(perform: loadOnAppear)
                .sheet(isPresented: $showClippyHistoryStats) {
                    ClippyHistoryView()
                }
                .sheet(
                    isPresented: Binding(
                        get: { exportURL != nil },
                        set: { isPresented in
                            if !isPresented {
                                exportURL = nil
                            }
                        }
                    )
                ) {
                    if let url = exportURL {
                        ActivityView(activityItems: [url])
                    }
                }
                .sheet(isPresented: $showDatabaseInfo) {
                    DailyStatsDatabaseInfoView(
                        mainViewController: viewModel.mainViewController,
                        showDatabaseInfo: $showDatabaseInfo
                    )
                }
                .sheet(isPresented: $showWeekdayFilter) {
                    NavigationStack {
                        WeekdayFilterView(
                            selectedWeekdays: Binding(
                                get: { viewModel.selectedWeekdays },
                                set: { viewModel.selectedWeekdays = $0 }
                            ),
                            usePumpChangeDays: Binding(
                                get: { viewModel.usePumpChangeDays },
                                set: { viewModel.usePumpChangeDays = $0 }
                            ),
                            useSensorChangeDays: Binding(
                                get: { viewModel.useSensorChangeDays },
                                set: { viewModel.useSensorChangeDays = $0 }
                            ),
                            useSickDays: Binding(
                                get: { viewModel.useSickDays },
                                set: { viewModel.useSickDays = $0 }
                            ),
                            useNonSickDays: Binding(
                                get: { viewModel.useNonSickDays },
                                set: { viewModel.useNonSickDays = $0 }
                            )
                        )
                        .navigationTitle("Filtrera tabellen")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
                .fullScreenCover(isPresented: $showNightscoutReport) {
                    if let date = selectedDateForReport {
                        NightscoutDayReportView(date: date)
                    }
                }
                .alert("Fel", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                    Button("OK", role: .cancel) { viewModel.errorMessage = nil }
                }, message: {
                    Text(viewModel.errorMessage ?? "")
                })
                .overlay(nightscoutAlertOverlay)
        }
    }
    

    @ViewBuilder
    private var coreContent: some View {
        // För-highlighting av bästa/sämsta dag baserat på aktuell TITR/TIR-vy
        let daysInScope = viewModel.numberOfDaysInScope
        
        // Samma filtrering som tabellen använder (endast dagar med tightRangePercent)
        let filteredRowsForHighlight = viewModel.filteredRowsForDisplay
            .filter { $0.tightRangePercent != nil }
        
        Group {
            if viewModel.isLoading && viewModel.rows.isEmpty {
                ProgressView("Beräknar daglig statistik…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    DailyStatsAveragesView(
                        averages: DailyStatsAverages(viewModel: viewModel),
                        thresholds: DailyStatsDisplayThresholds(viewModel: viewModel),
                        showingTitrSummary: showingTitrSummary
                    )
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                    DailyStatsSummaryView(
                        rows: viewModel.filteredRowsForDisplay,
                        numberOfDaysInScope: viewModel.numberOfDaysInScope,
                        numberOfDaysMeetingTitrTarget: viewModel.numberOfDaysMeetingTitrTarget,
                        numberOfDaysMeetingTirTarget: viewModel.numberOfDaysMeetingTirTarget,
                        thresholds: DailyStatsDisplayThresholds(viewModel: viewModel),
                        showingTitrSummary: $showingTitrSummary
                    )
                        .padding(.horizontal, 15)
                        .padding(.top, 8)

                    DailyStatsTableView(
                        rows: filteredRowsForHighlight,
                        numberOfDaysInScope: daysInScope,
                        showingTitrSummary: showingTitrSummary,
                        thresholds: DailyStatsDisplayThresholds(viewModel: viewModel),
                        dateFormatter: dateFormatter,
                        onSelectDate: selectReportDate
                    )
                    // Bar chart (TDD + KH) for the same days as the table
                    if !filteredRowsForHighlight.isEmpty {
                        Divider()
                            .padding(.horizontal, 15)

                        DailyStatsChartsView(
                            rows: filteredRowsForHighlight,
                            showingTitrSummary: showingTitrSummary,
                            showRealCRandTitrChart: $showRealCRandTitrChart
                        )
                            .padding(.horizontal, 15)
                            .padding(.top, 15)
                            .padding(.bottom, 12)
                    }
                }
            }
        }
    }


}
