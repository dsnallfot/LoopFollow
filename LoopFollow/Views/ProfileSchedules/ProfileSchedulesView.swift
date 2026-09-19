//
//  ProfileSchedulesView.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2025-02-26.

//

import SwiftUI
import Charts
import PhotosUI
import UIKit
import HealthKit
import UniformTypeIdentifiers

@available(iOS 26.0, *)
struct ProfileSchedulesView: View {
    var onDone: (() -> Void)? = nil
    @ObservedObject var viewModel = ProfileSchedulesViewModel()
    
    @State var selectedSection: SectionType = .targets // Default section
    @State var showProfileUpdatedAlert: Bool = false
    @State var selectedLogSearchItem: LogSearchItem?
    @State var selectedMode: Mode = .user
    @State var showAddUserData: Bool = false
    @State var showStatsView: Bool = false
    @State var showTrainingStats: Bool = false
    @State var isExportingUserCSV: Bool = false
    @State var isImportingUserCSV: Bool = false
    @State var userCSVDocument: UserProfileCSVDocument = UserProfileCSVDocument(text: "")
    @State var userCSVImportError: String?
    @State var showAddSickDay: Bool = false
    @State var showAddTraining: Bool = false
    @State var showSickDayCalendar: Bool = false
    @State private var sickDayToDelete: SickDayHistoryEntry?
    
    private static let sickDayDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    @ViewBuilder
    private var modePickerView: some View {
        Picker("Mode", selection: $selectedMode) {
            ForEach(Mode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.top)
        .padding(.bottom, 6)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var trainingModeContent: some View {
        TrainingSessionsView(
            sessions: viewModel.trainingSessions,
            onTapSession: { session in
                presentTrainingAnalysis(for: session)
            }
        )
    }

    @available(iOS 26.0, *)
    var body: some View {
        ZStack {
            ThemeBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                modePickerView

                if selectedMode == .profile {
                    ProfileScheduleContentView(
                        schedules: ProfileScheduleData(viewModel: viewModel),
                        selectedSection: $selectedSection,
                        multiChartData: multiChartData,
                        openSettingsLog: openSettingsLog
                    )
                } else if selectedMode == .sick {
                    SickDayListView(
                        entries: viewModel.sickDayEntries,
                        dateFormatter: Self.sickDayDateFormatter,
                        onSelect: presentSickDayAnalysis,
                        onDelete: { sickDayToDelete = $0 }
                    )
                } else if selectedMode == .training {
                    trainingModeContent
                } else {
                    UserDataViewController()
                }
            }
        }
        .navigationTitle(selectedMode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedMode) { _, newMode in
            if newMode == .sick {
                viewModel.reloadSickDays()
            } else if newMode == .training {
                viewModel.reloadTrainingSessions()
            }
        }
        .sheet(item: $selectedLogSearchItem) { item in
            ZStack {
                // Lägg till bakgrunden här för att fylla hela modalen
                ThemeBackground()
                    .ignoresSafeArea()
                
                // Din wrapper ovanpå bakgrunden
                ProfileSettingsLogModal(initialSearchText: item.term)
            }
        }
        .sheet(isPresented: $showAddUserData) {
            NavigationStack {
                AddUserDataView()
            }
        }
        .sheet(isPresented: $showStatsView) {
            NavigationStack {
                UserDataStatsView()
            }
        }
        .sheet(isPresented: $showAddSickDay) {
            NavigationStack {
                AddSickDayView()
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSickDayCalendar) {
            NavigationStack {
                SickDayCalendarView(entries: viewModel.sickDayEntries)
            }
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $showTrainingStats) {
            NavigationStack {
                TrainingStatsView(sessions: viewModel.trainingSessions)
            }
        }
        .sheet(isPresented: $showAddTraining) {
            NavigationStack {
                AddTrainingView()
            }
            .presentationDetents([.medium])
        }
        
        .alert(
            "Profil uppdaterades \n\(ProfileManager.shared.profileCreatedAtFormatted ?? "Okänt")",
            isPresented: $showProfileUpdatedAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("""
            
            Senaste ändringsdatum
            • Målprofil: \(fmt(viewModel.lastChangedTargetProfile))
            • Basalprofil: \(fmt(viewModel.lastChangedBasalProfile))
            • CR-profil: \(fmt(viewModel.lastChangedCRProfile))
            • ISF-profil: \(fmt(viewModel.lastChangedISFProfile))
            """)
        }
        .alert("Radera sjukdag", isPresented: Binding(
            get: { sickDayToDelete != nil },
            set: { newValue in
                if !newValue {
                    sickDayToDelete = nil
                }
            }
        )) {
            Button("Radera", role: .destructive) {
                if let entry = sickDayToDelete {
                    viewModel.deleteSickDay(entry)
                }
                sickDayToDelete = nil
            }
            Button("Avbryt", role: .cancel) {
                sickDayToDelete = nil
            }
        } message: {
            if let entry = sickDayToDelete {
                Text("Vill du verkligen radera sjukdagen \(Self.sickDayDateFormatter.string(from: Date(timeIntervalSince1970: entry.date))) med noteringen \"\(entry.notes)\"?")
            } else {
                Text("Vill du verkligen radera denna sjukdag?")
            }
        }
        .fileExporter(
            isPresented: $isExportingUserCSV,
            document: userCSVDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "UserProfiles"
        ) { result in
            handleCSVExport(result)
        }
        .fileImporter(
            isPresented: $isImportingUserCSV,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            handleCSVImport(result)
        }
        .alert("Fel vid CSV-import/export", isPresented: Binding(
            get: { userCSVImportError != nil },
            set: { newValue in
                if !newValue {
                    userCSVImportError = nil
                }
            }
        )) {
            Button("OK", role: .cancel) { userCSVImportError = nil }
        } message: {
            Text(userCSVImportError ?? "Okänt fel")
        }
    }
    
    private var shortDateFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }

    private func fmt(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        return shortDateFormatter.string(from: date)
    }

}
