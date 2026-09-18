import SwiftUI
import UIKit

@available(iOS 26.0, *)
struct ClippyHistoryStatsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ClippyHistoryStatsViewControllerRepresentable()
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Klar") {
                            dismiss()
                        }
                    }
                }
                .navigationTitle("Daglig 12h TITR målgångstid")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@available(iOS 26.0, *)
private struct ClippyHistoryStatsViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ClippyHistoryStatsViewController {
        ClippyHistoryStatsViewController()
    }

    func updateUIViewController(_ uiViewController: ClippyHistoryStatsViewController, context: Context) {
    }
}

