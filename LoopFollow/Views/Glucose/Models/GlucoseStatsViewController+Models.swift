import UIKit
import Charts

extension GlucoseStatsViewController {
    struct SensorErrorOutage {
        let noteDate: Date
        let durationMinutes: Int
    }
    enum ChartMode: Int {
        case glucoseValues = 0
        case sensorErrors = 1
    }
    enum PeriodOption: CaseIterable {
        case d1, d7, d14, d30, d90

        var days: Int {
            switch self {
            case .d1:  return 1
            case .d7:  return 7
            case .d14: return 14
            case .d30: return 30
            case .d90: return 90
            }
        }

        var title: String {
            switch self {
            case .d1:  return "1 d"
            case .d7:  return "7 d"
            case .d14: return "14 d"
            case .d30: return "30 d"
            case .d90: return "90 d"
            }
        }
    }
}
