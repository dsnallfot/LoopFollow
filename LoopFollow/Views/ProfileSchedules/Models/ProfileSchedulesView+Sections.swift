import SwiftUI
import UIKit

@available(iOS 26.0, *)
extension ProfileSchedulesView {
    enum Mode: String, CaseIterable {
        case user = "Hälsodata"
        case sick = "Sjukdagar"
        case training = "Träning"
        case profile = "Profil"
    }

    enum SectionType: String, CaseIterable {
        case targets = "Mål"
        case basal = "Basal"
        case cr = "CR"
        case isf = "ISF"
        case csf = "CSF"
        case cHr = "Kh/h"
        case smb = "SMB"

        var displayName: String {
            switch self {
            case .targets: return "Targets"
            case .basal: return "Basal"
            case .cr: return "Carb Ratios"
            case .isf: return "Insulin Sensitivity Factor"
            case .csf: return "Carb Sensitivity Factor"
            case .cHr: return "Minimum Carbs grams/hour"
            case .smb: return "SMB Limits"
            }
        }
    }
}
