//
//  ProfileSchedulesViewModel.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2025-02-26.

//

import Foundation
import HealthKit
import Combine

class ProfileSchedulesViewModel: ObservableObject {
    @Published var basalEntries: [ScheduleEntry] = []
    @Published var carbRatioEntries: [ScheduleEntry] = []
    @Published var isfEntries: [ScheduleEntry] = []
    @Published var targetEntries: [ScheduleEntry] = []
    @Published var csfEntries: [ScheduleEntry] = []
    @Published var minCarbsEntries: [ScheduleEntry] = []
    @Published var smbEntries: [ScheduleEntry] = []
    @Published var basalIOBEntries: [ScheduleEntry] = []
    @Published var lastChangedBasalProfile: Date?
    @Published var lastChangedCRProfile: Date?
    @Published var lastChangedISFProfile: Date?
    @Published var lastChangedTargetProfile: Date?
    @Published var sickDayEntries: [SickDayHistoryEntry] = []
    @Published var trainingSessions: [TrainingSessionEntry] = []
    
    var minCarbImpact: Double = 8 // Default value, will be fetched
    let lastChangedStore = ProfileSchedulesLastChangedStore.shared
    var cancellables = Set<AnyCancellable>()

    init() {
        fetchProfileData()
        scanCachedProfileNoteTreatments()
        loadSickDayEntries()
        loadTrainingSessions()
        observeSickDayUpdates()
    }

}
