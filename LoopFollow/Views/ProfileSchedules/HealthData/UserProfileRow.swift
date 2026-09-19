import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct UserProfileRow: View {
    let entry: UserProfileEntry

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Self.dateFormatter.string(from: entry.updatedAt))
                    .font(.subheadline.monospacedDigit())
                    .fontWeight(.semibold)

                Spacer()

                if let hb = entry.hbA1c {
                    ZStack {
                        Circle()
                            .fill(hbColor(for: hb))
                            .frame(width: 30, height: 30)

                        Text(String(format: "%.0f", hb))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .offset(x: 0, y: 13)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 30, height: 30)

                        Text("--")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .offset(x: 0, y: 12)
                }
            }

            let tddString = entry.tdd.map { String(format: "%.1f", $0) } ?? "--"
            let weightString = entry.weightKg.map { String(format: "%.1f", $0) } ?? "--"
            let heightString = entry.heightCm.map { String(format: "%.1f", $0) } ?? "--"
            let insulinPerKgString = entry.insulinPerKg.map { String(format: "%.2f", $0) } ?? "--"

            Text("TDD: \(tddString) E • Vikt: \(weightString) kg • \(insulinPerKgString) E/kg/d • Längd: \(heightString) cm")
                .font(.system(size: 10).monospacedDigit())
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func hbColor(for hbA1c: Double) -> Color {
        if hbA1c <= 48 {
            return Color(UIColor.systemGreen)
        } else if hbA1c <= 52 {
            return Color(UIColor.systemOrange)
        } else {
            return Color(UIColor.systemRed)
        }
    }
}
