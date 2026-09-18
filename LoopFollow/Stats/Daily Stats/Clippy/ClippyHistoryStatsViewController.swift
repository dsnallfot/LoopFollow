import SwiftUI
import UIKit
import Charts

@available(iOS 26.0, *)
final class ClippyHistoryStatsViewController: ThemedTableViewController {

    private enum PeriodOption: CaseIterable {
        case d7, d14, d30, d90

        var days: Int {
            switch self {
            case .d7:  return 7
            case .d14: return 14
            case .d30: return 30
            case .d90: return 90
            }
        }

        var title: String {
            switch self {
            case .d7:  return "7 d"
            case .d14: return "14 d"
            case .d30: return "30 d"
            case .d90: return "90 d"
            }
        }
    }

    private let allHistory: [ClippyDailyTargetHistoryEntry] = Storage.shared.clippyDailyTargetHistory
        .sorted { $0.date < $1.date }

    private var selectedPeriod: PeriodOption = .d14
    var selectedDays: [Date] = []
    var reachedEntries: [ChartDataEntry] = []
    var missedEntries: [ChartDataEntry] = []
    private var reachedHistoryByDay: [Date: ClippyDailyTargetHistoryEntry] = [:]

    lazy var periodControl: UISegmentedControl = {
        let items = PeriodOption.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = PeriodOption.allCases.firstIndex(of: selectedPeriod) ?? 1
        sc.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)
        return sc
    }()

    let timeChartView: ScatterChartView = {
        let v = ScatterChartView()
        v.chartDescription.enabled = false
        v.legend.enabled = true
        v.rightAxis.enabled = false
        v.minOffset = 8
        v.pinchZoomEnabled = false
        v.doubleTapToZoomEnabled = true
        v.scaleXEnabled = true
        v.scaleYEnabled = false
        v.dragEnabled = true
        v.highlightPerTapEnabled = false
        v.highlightPerDragEnabled = false
        v.drawMarkers = false
        v.maxVisibleCount = 1000000
        return v
    }()

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBackgroundForCurrentMode()
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.isOpaque = false
        tableView.layer.backgroundColor = UIColor.clear.cgColor
        title = "Clippyhistorik"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ClippyHistoryStatsCell")

        setupChartHeader()
        applyPeriod(selectedPeriod)
    }

    private enum Row: Int, CaseIterable {
        case reachedPercentage
        case reachedDays
        case fastestReached
        case slowestReached
        case averageReached
        case longestReachedStreak
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    @objc private func periodChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard index >= 0 && index < PeriodOption.allCases.count else { return }
        applyPeriod(PeriodOption.allCases[index])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = tableView.tableHeaderView {
            let targetSize = CGSize(width: tableView.bounds.width, height: 340)
            if header.frame.size != targetSize {
                header.frame.size = targetSize
                tableView.tableHeaderView = header
            }
        }
    }

    private func applyPeriod(_ period: PeriodOption) {
        selectedPeriod = period

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        selectedDays = (0..<period.days).compactMap { offset in
            cal.date(byAdding: .day, value: -(period.days - 1 - offset), to: todayStart)
        }

        rebuildEntries()
        loadChartData()
        tableView.reloadData()
    }

    private func rebuildEntries() {
        let cal = Calendar.current
        let historyByDay: [Date: ClippyDailyTargetHistoryEntry] = Dictionary(
            uniqueKeysWithValues: allHistory.map { entry in
                let date = Date(timeIntervalSince1970: entry.date)
                return (cal.startOfDay(for: date), entry)
            }
        )

        reachedHistoryByDay = [:]
        reachedEntries = []
        missedEntries = []

        for (index, day) in selectedDays.enumerated() {
            if let entry = historyByDay[day] {
                reachedHistoryByDay[day] = entry

                let date = Date(timeIntervalSince1970: entry.date)
                let comps = cal.dateComponents([.hour, .minute, .second], from: date)
                let hour = Double(comps.hour ?? 0)
                let minute = Double(comps.minute ?? 0)
                let second = Double(comps.second ?? 0)
                let yValue = hour + (minute / 60.0) + (second / 3600.0)
                reachedEntries.append(ChartDataEntry(x: Double(index), y: yValue))
            } else {
                missedEntries.append(ChartDataEntry(x: Double(index), y: 24.0))
            }
        }
    }

    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "yyyy-MM-dd, HH:mm"
        return formatter
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var reachedEntriesInSelectedPeriod: [ClippyDailyTargetHistoryEntry] {
        selectedDays.compactMap { reachedHistoryByDay[$0] }
    }

    private var reachedDayCountText: String {
        "\(reachedEntriesInSelectedPeriod.count) av \(selectedDays.count) dagar"
    }

    private var reachedPercentageText: String {
        guard selectedDays.count > 0 else { return "–" }
        let pct = Double(reachedEntriesInSelectedPeriod.count) * 100.0 / Double(selectedDays.count)
        return String(format: "%.0f %%", pct)
    }

    private var fastestReachedText: String {
        guard let fastest = reachedEntriesInSelectedPeriod.min(by: {
            let lhs = secondsSinceStartOfDay(for: Date(timeIntervalSince1970: $0.date))
            let rhs = secondsSinceStartOfDay(for: Date(timeIntervalSince1970: $1.date))
            return lhs < rhs
        }) else {
            return "–"
        }

        return Self.fullDateTimeFormatter.string(from: Date(timeIntervalSince1970: fastest.date))
    }

    private var slowestReachedText: String {
        guard let slowest = reachedEntriesInSelectedPeriod.max(by: {
            let lhs = secondsSinceStartOfDay(for: Date(timeIntervalSince1970: $0.date))
            let rhs = secondsSinceStartOfDay(for: Date(timeIntervalSince1970: $1.date))
            return lhs < rhs
        }) else {
            return "–"
        }

        return Self.fullDateTimeFormatter.string(from: Date(timeIntervalSince1970: slowest.date))
    }

    private var averageReachedText: String {
        let entries = reachedEntriesInSelectedPeriod
        guard !entries.isEmpty else { return "–" }

        let averageSeconds = entries
            .map { secondsSinceStartOfDay(for: Date(timeIntervalSince1970: $0.date)) }
            .reduce(0, +) / entries.count

        let hours = averageSeconds / 3600
        let minutes = (averageSeconds % 3600) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }

    private var longestReachedStreakText: String {
        let streak = longestReachedStreak()
        return "\(streak) dagar"
    }

    private func secondsSinceStartOfDay(for date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        return (hour * 3600) + (minute * 60) + second
    }

    private func longestReachedStreak() -> Int {
        guard !selectedDays.isEmpty else { return 0 }

        var longest = 0
        var current = 0

        for day in selectedDays {
            if reachedHistoryByDay[day] != nil {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }

        return longest
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "ClippyHistoryStatsCell")
        cell.selectionStyle = .none

        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        if #available(iOS 14.0, *) {
            var bg = UIBackgroundConfiguration.clear()
            bg.backgroundColor = .systemGray.withAlphaComponent(0.15)
            cell.backgroundConfiguration = bg
        }

        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.numberOfLines = 1
        cell.detailTextLabel?.textAlignment = .right
        cell.detailTextLabel?.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)

        guard let row = Row(rawValue: indexPath.row) else { return cell }

        switch row {
        case .reachedPercentage:
            cell.textLabel?.text = "Andel målgångsdagar"
            cell.detailTextLabel?.text = reachedPercentageText

        case .reachedDays:
            cell.textLabel?.text = "Mål nåddes (12h TITR)"
            cell.detailTextLabel?.text = reachedDayCountText

        case .fastestReached:
            cell.textLabel?.text = "Snabbast i mål"
            cell.detailTextLabel?.text = fastestReachedText

        case .slowestReached:
            cell.textLabel?.text = "Långsammast i mål"
            cell.detailTextLabel?.text = slowestReachedText

        case .averageReached:
            cell.textLabel?.text = "Genomsnittlig målgång"
            cell.detailTextLabel?.text = averageReachedText

        case .longestReachedStreak:
            cell.textLabel?.text = "Längsta streak målgång"
            cell.detailTextLabel?.text = longestReachedStreakText
        }

        return cell
    }
}

