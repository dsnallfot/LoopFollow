import UIKit
import Charts

final class BGCheckStatsViewController: ThemedTableViewController {

    // Full data set (upp till t.ex. 90 dagar)
    let allDays: [Date]
    let allCounts: [Int]
    let allDextroCounts: [Int]
    let allBGCheckDates: [Date]
    let allBGCheckDextroDates: [Date]
    let allBGCheckEntries: [BGCheckEntry]

    // Aktuell vy (styrd av segmented control)
    var selectedDays: [Date] = []
    var selectedCounts: [Int] = []
    var selectedDextroCounts: [Int] = []
    var selectedBGCheckDates: [Date] = []
    var selectedBGCheckDextroDates: [Date] = []
    var selectedBGCheckEntries: [BGCheckEntry] = []

    var selectedPeriod: PeriodOption = .d90

    var selectedMode: ChartMode = .count

    lazy var modeControl: UISegmentedControl = {
        let items = ChartMode.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = ChartMode.allCases.firstIndex(of: selectedMode) ?? 0
        sc.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        return sc
    }()

    lazy var periodControl: UISegmentedControl = {
        let items = PeriodOption.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = PeriodOption.allCases.firstIndex(of: selectedPeriod) ?? (items.count - 1)
        sc.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)
        return sc
    }()

    let chartView: BarChartView = {
        let v = BarChartView()
        v.legend.enabled = false
        v.chartDescription.enabled = false
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

    let timeChartView: ScatterChartView = {
        let v = ScatterChartView()
        v.legend.enabled = true
        v.chartDescription.enabled = false
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

    init(days: [Date], counts: [Int], dextroCounts: [Int], bgCheckEntries: [BGCheckEntry], bgCheckDates: [Date], bgCheckDextroDates: [Date]) {
        self.allDays = days
        self.allCounts = counts
        self.allDextroCounts = dextroCounts
        self.allBGCheckDates = bgCheckDates
        self.allBGCheckDextroDates = bgCheckDextroDates
        self.allBGCheckEntries = bgCheckEntries
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBackgroundForCurrentMode()
        tableView.backgroundColor = .clear
        tableView.backgroundView = tableView.backgroundView
        tableView.isOpaque = false
        tableView.layer.backgroundColor = UIColor.clear.cgColor
        title = "Statistick"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BGStatsCell")

        // Välj en rimlig defaultperiod baserat på hur många dagar vi har
        let initialPeriod = defaultPeriod()
        selectedPeriod = initialPeriod
        if let idx = PeriodOption.allCases.firstIndex(of: initialPeriod) {
            periodControl.selectedSegmentIndex = idx
        }

        // Default: Antal
        selectedMode = .count
        if let idx2 = ChartMode.allCases.firstIndex(of: selectedMode) {
            modeControl.selectedSegmentIndex = idx2
        }

        setupChartHeader()
        applyPeriod(initialPeriod)
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

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    private let deltaFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "sv_SE")
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        nf.positivePrefix = "+"
        nf.negativePrefix = "-"
        return nf
    }()

    // MARK: - Table view

    private enum Row: Int, CaseIterable {
        case totalSticks
        case avgPerDay
        case daysWithSticks
        case avgPerStickDay
        case maxPerStickDay
        case longestNoStickStreak
        case dextroShare
        case meanCgm10mDelta
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "BGStatsCell")
        cell.selectionStyle = .none

        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        if #available(iOS 14.0, *) {
            var bg = UIBackgroundConfiguration.clear()
            bg.backgroundColor = .systemGray.withAlphaComponent(0.15)
            cell.backgroundConfiguration = bg
        }
        cell.textLabel?.backgroundColor = .clear
        cell.detailTextLabel?.backgroundColor = .clear

        let row = Row(rawValue: indexPath.row)!
        switch row {
        case .totalSticks:
            cell.textLabel?.text = "Totalt antal stick"
            cell.detailTextLabel?.text = "\(totalSticks) ggr"

        case .avgPerDay:
            cell.textLabel?.text = "Medel stick per dag"
            if totalDays > 0 {
                let avg = Double(totalSticks) / Double(totalDays)
                cell.detailTextLabel?.text = String(format: "%.1f ggr", avg)
            } else {
                cell.detailTextLabel?.text = "–"
            }

        case .daysWithSticks:
            cell.textLabel?.text = "Andel dagar med stick"
            cell.detailTextLabel?.text = "\(percentageString(daysWithSticks, totalDays))"

        case .avgPerStickDay:
            cell.textLabel?.text = "Medel stick per stick-dag"
            if daysWithSticks > 0 {
                let avg = Double(totalSticks) / Double(daysWithSticks)
                cell.detailTextLabel?.text = String(format: "%.1f ggr", avg)
            } else {
                cell.detailTextLabel?.text = "–"
            }

        case .maxPerStickDay:
            cell.textLabel?.text = "Högsta antal stick per stick-dag"
            cell.detailTextLabel?.text = "\(maxSticksPerDay) ggr"
        case .longestNoStickStreak:
            cell.textLabel?.text = "Längsta streak utan stick"
            let streak = longestStreakWithoutSticks() * 24
            cell.detailTextLabel?.text = "\(streak) h"
        case .dextroShare:
            cell.textLabel?.text = "Andel stick ⇢ 🍬"
            if totalSticks > 0 {
                cell.detailTextLabel?.text = percentageString(totalDextroSticks, totalSticks)
            } else {
                cell.detailTextLabel?.text = "–"
            }
        case .meanCgm10mDelta:
            cell.textLabel?.text = "CGM (+10m) medel Δ"
            if let mean = meanCgm10mDelta {
                let s = deltaFormatter.string(from: NSNumber(value: mean)) ?? String(format: "%+.1f", mean)
                cell.detailTextLabel?.text = "\(s) mmol/L"
            } else {
                cell.detailTextLabel?.text = "–"
            }
        }

        return cell
    }
}
