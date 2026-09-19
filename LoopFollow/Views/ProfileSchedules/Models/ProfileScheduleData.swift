import Foundation

struct ProfileScheduleData {
    let basalEntries: [ScheduleEntry]
    let carbRatioEntries: [ScheduleEntry]
    let isfEntries: [ScheduleEntry]
    let targetEntries: [ScheduleEntry]
    let csfEntries: [ScheduleEntry]
    let minCarbsEntries: [ScheduleEntry]
    let smbEntries: [ScheduleEntry]
    let basalIOBEntries: [ScheduleEntry]
    let lastChangedBasalProfile: Date?
    let lastChangedCRProfile: Date?
    let lastChangedISFProfile: Date?
    let lastChangedTargetProfile: Date?

    init(viewModel: ProfileSchedulesViewModel) {
        basalEntries = viewModel.basalEntries
        carbRatioEntries = viewModel.carbRatioEntries
        isfEntries = viewModel.isfEntries
        targetEntries = viewModel.targetEntries
        csfEntries = viewModel.csfEntries
        minCarbsEntries = viewModel.minCarbsEntries
        smbEntries = viewModel.smbEntries
        basalIOBEntries = viewModel.basalIOBEntries
        lastChangedBasalProfile = viewModel.lastChangedBasalProfile
        lastChangedCRProfile = viewModel.lastChangedCRProfile
        lastChangedISFProfile = viewModel.lastChangedISFProfile
        lastChangedTargetProfile = viewModel.lastChangedTargetProfile
    }
}
