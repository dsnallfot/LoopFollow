import Foundation

struct ActiveAlarmRow {
    let title: String
    let getIsOn: () -> Bool
    let setIsOn: (Bool) -> Void
}

enum ActiveAlarmSection: Int, CaseIterable {
    case bg
    case trend
    case trio
    case tech
    case other

    var title: String {
        switch self {
        case .bg:
            return "Hög/Låg-larm"
        case .trend:
            return "Trendlarm"
        case .trio:
            return "Trio-larm"
        case .tech:
            return "Tekniklarm"
        case .other:
            return "Övriga larm"
        }
    }
}
