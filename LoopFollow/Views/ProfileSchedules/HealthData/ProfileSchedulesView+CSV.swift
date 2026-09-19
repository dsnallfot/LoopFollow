import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension ProfileSchedulesView {
    func handleCSVExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            break
        case .failure(let error):
            userCSVImportError = "Export misslyckades: \(error.localizedDescription)"
        }
    }

    func handleCSVImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                var dataURL = url
                var needsStop = false
                if dataURL.startAccessingSecurityScopedResource() {
                    needsStop = true
                }
                defer {
                    if needsStop {
                        dataURL.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: dataURL)
                if let csvString = String(data: data, encoding: .utf8) {
                    Storage.shared.importUserProfilesCSV(from: csvString)
                } else {
                    userCSVImportError = "Kunde inte läsa CSV-filen (ogiltig textkodning)."
                }
            } catch {
                userCSVImportError = "Kunde inte läsa CSV-filen: \(error.localizedDescription)"
            }
        case .failure(let error):
            userCSVImportError = "Import misslyckades: \(error.localizedDescription)"
        }
    }
}
