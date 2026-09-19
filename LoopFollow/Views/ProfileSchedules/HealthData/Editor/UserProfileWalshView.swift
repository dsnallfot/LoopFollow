import SwiftUI
import UIKit

struct UserProfileComparisonValue {
    let value: Double?
    let percentage: String?
}

@available(iOS 16.0, *)
struct UserProfileWalshView: View {
    let walsh500CR: UserProfileComparisonValue
    let walsh300CR: UserProfileComparisonValue
    let walshWeightCR: UserProfileComparisonValue
    let walsh100ISF: UserProfileComparisonValue
    let walshTDD: UserProfileComparisonValue
    let walshBasal: UserProfileComparisonValue
    let walshBasalPerHour: UserProfileComparisonValue

    var body: some View {
        Divider()
            .padding(.top, 6)
        HStack {

            Text("Walsh baseline")
            Spacer()
            Text("Beräknat värde (% vs inställt)")
        }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)

        // Kalkylerade rader (icke-editable)
        Group {
            HStack {
                Text("Walsh 500-regeln CR:")
                Spacer()
                Text(walsh500CR.value.map { String(format: "%.1f", $0) } ?? "--")
                Text("g/E")
                if let pct = walsh500CR.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Text("Walsh 300-regeln CR:")
                Spacer()
                Text(walsh300CR.value.map { String(format: "%.1f", $0) } ?? "--")
                Text("g/E")
                if let pct = walsh300CR.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Text("Walsh Vikt-beräkning CR:")
                Spacer()
                Text(walshWeightCR.value.map { String(format: "%.1f", $0) } ?? "--")
                Text("g/E")
                if let pct = walshWeightCR.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Text("Walsh 100-regeln ISF:")
                Spacer()
                Text(walsh100ISF.value.map { String(format: "%.1f", $0) } ?? "--")
                Text("mmol/L/E")
                if let pct = walsh100ISF.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Text("Walsh TDD:")
                Spacer()
                Text(walshTDD.value.map { String(format: "%.2f", $0) } ?? "--")
                Text("E/dag")
                if let pct = walshTDD.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Text("Walsh Basal:")
                Spacer()
                Text(walshBasal.value.map { String(format: "%.2f", $0) } ?? "--")
                Text("E/dag")
                if let pct = walshBasal.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 6)

            HStack {
                Text("Walsh Basal/h:")
                Spacer()
                Text(walshBasalPerHour.value.map { String(format: "%.2f", $0) } ?? "--")
                Text("E/h")
                if let pct = walshBasalPerHour.percentage {
                    Text(pct)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
