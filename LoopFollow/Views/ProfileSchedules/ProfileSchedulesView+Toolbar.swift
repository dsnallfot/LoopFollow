import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension ProfileSchedulesView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if selectedMode == .profile {
                Button {
                    showProfileUpdatedAlert = true
                } label: {
                    Image(systemName: "info")
                }
                .accessibilityLabel("Profil laddades ner:")
            } else if selectedMode == .user {
                HStack(spacing: 12){
                    Button {
                        showAddUserData = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .padding(.leading, 3)
                    .accessibilityLabel("Lägg till användardata")

                    Button {
                        let csv = Storage.shared.exportUserProfilesCSV()
                        userCSVDocument = UserProfileCSVDocument(text: csv)
                        isExportingUserCSV = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Exportera användardata (CSV)")

                    Button {
                        isImportingUserCSV = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .accessibilityLabel("Importera användardata (CSV)")

                    Button {
                        showStatsView = true
                    } label: {
                        Image(systemName: "chart.bar.xaxis.ascending")
                    }
                    .padding(.trailing, 3)
                    .accessibilityLabel("Visa hälsostatistik")
                }
            } else if selectedMode == .sick {
                HStack(spacing: 12) {
                    Button {
                        showAddSickDay = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .padding(.leading, 3)
                    .accessibilityLabel("Lägg till sjukdag")

                    Button {
                        showSickDayCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .padding(.trailing, 3)
                    .accessibilityLabel("Visa sjukdagshistorik som kalender")
                }
            } else if selectedMode == .training {
                HStack(spacing: 12) {
                    Button {
                        showAddTraining = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .padding(.leading, 3)
                    .accessibilityLabel("Lägg till träning")
                Button {
                    showTrainingStats = true
                } label: {
                    Image(systemName: "chart.bar.xaxis.ascending")
                }
                .accessibilityLabel("Visa träningsstatistik")
                .padding(.trailing, 3)
            }
            }
        }
    }
}
