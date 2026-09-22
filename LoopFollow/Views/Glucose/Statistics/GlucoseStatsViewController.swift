import UIKit
import Charts

// MARK: - Glucose Stats (All values vs Trio→NS)

final class GlucoseStatsViewController: ThemedTableViewController {

    // Match LowTreatmentsStatsViewController: insetGrouped gives the rounded light-gray cards
    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Full 90d dataset (oldest → newest)
    var allDays: [Date] = []
    var allCountsAllValues: [Int] = []
    var allCountsNSOnly: [Int] = []
    var unicornsByDay: [Date: Int] = [:]

    // Raw SGV data for full window (used for extreme-value stats)
    var allSGVJSON: [SGVJSON] = []


    // Current selection
    var selectedDays: [Date] = []
    var selectedCountsAllValues: [Int] = []
    var selectedCountsNSOnly: [Int] = []

    // Sensor error outages (computed for the full window, then filtered by selected period)
    var allSensorErrorOutages: [SensorErrorOutage] = []
    var selectedSensorErrorOutages: [SensorErrorOutage] = []

    var selectedChartMode: ChartMode = .glucoseValues

    lazy var chartModeControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Glukosvärden", "Sensorfel"])
        sc.selectedSegmentIndex = selectedChartMode.rawValue
        sc.addTarget(self, action: #selector(chartModeChanged(_:)), for: .valueChanged)
        return sc
    }()

    var selectedPeriod: PeriodOption = .d7

    lazy var periodControl: UISegmentedControl = {
        let items = PeriodOption.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = PeriodOption.allCases.firstIndex(of: selectedPeriod) ?? 2
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
        v.maxVisibleCount = 1_000_000
        return v
    }()

    // Scatterplot: Sensorfel per datum (x) och tid på dygnet (y)
    let sensorErrorChartView: ScatterChartView = {
        let v = ScatterChartView()
        v.chartDescription.enabled = false
        v.legend.enabled = false
        v.minOffset = 8
        v.pinchZoomEnabled = false
        v.doubleTapToZoomEnabled = true
        v.scaleXEnabled = true
        v.scaleYEnabled = false
        v.dragEnabled = true
        v.highlightPerTapEnabled = false
        v.highlightPerDragEnabled = false
        v.drawMarkers = false
        v.maxVisibleCount = 1_000_000
        v.rightAxis.enabled = false
        return v
    }()

    let dfAxis: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "dd/MM"
        return df
    }()

    private let dfISO: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBackgroundForCurrentMode()
        tableView.backgroundColor = .clear
        tableView.backgroundView = tableView.backgroundView
        tableView.isOpaque = false
        tableView.layer.backgroundColor = UIColor.clear.cgColor
        title = "Glukosstatistik"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "GlucoseStatsCell")

        setupChartHeader()
        loadDataAndApplyInitialPeriod()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let header = tableView.tableHeaderView {
            let targetSize = CGSize(width: tableView.bounds.width, height: 370)
            if header.frame.size != targetSize {
                header.frame.size = targetSize
                tableView.tableHeaderView = header
            }
        }
    }
    // MARK: - Stats table

    private enum Row: Int, CaseIterable {
        case avgAllPct
        case avgMissedAllPerDay
        case avgTrioPct
        case avgMissedTrioPerDay
        case avgMinutesWithoutAll
        case bestAllDay
        case worstAllDay
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            // Dexcom inkl backfill
            return 6
        case 1:
            // Trio uppladdningar realtid
            return 5
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Alla glukosvärden (inkl backfill)"
        case 1:
            return "Uppladdningar i realtid"
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 1 else { return nil }
        return "Mer än 1 minuts fördröjning räknas som försenat. Värden utan uppladdningstid räknas som realtid."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "GlucoseStatsCell")
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

        let expectedPerDay = expectedCountsForSelectedDays()
        let totalExpected = Double(expectedPerDay.reduce(0, +))
        let totalAll = Double(selectedCountsAllValues.reduce(0, +))
        let totalNS  = Double(selectedCountsNSOnly.reduce(0, +))
        let avgAllPct = totalExpected > 0 ? (totalAll / totalExpected * 100.0) : 0
        let avgNSPct  = totalExpected > 0 ? (totalNS / totalExpected * 100.0) : 0
        let missedAllPerDay = zip(selectedCountsAllValues, expectedPerDay)
            .map { Double(max(0, $1 - $0)) }
        let missedNSPerDay = zip(selectedCountsNSOnly, expectedPerDay)
            .map { Double(max(0, $1 - $0)) }
        let avgMissAll = avg(missedAllPerDay)
        let avgMissNS  = avg(missedNSPerDay)
        let avgMinutesNoAll = avgMissNS * 5.0
        // Best/worst day for "All values"
        var bestPct: Double = 0
        var bestDate: Date?
        var worstPct: Double = 101
        var worstDate: Date?
        for (i, day) in selectedDays.enumerated() {
            let expected = Double(expectedPerDay[i])
            guard expected > 0 else { continue }
            let pct = Double(selectedCountsNSOnly[i]) / expected * 100.0
            if pct > bestPct {
                bestPct = pct
                bestDate = day
            }
            if pct < worstPct {
                worstPct = pct
                worstDate = day
            }
        }

        switch indexPath.section {
        case 0:
            // Dexcom inkl backfill
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Medel glukosvärden"
                cell.detailTextLabel?.text = percentString(avgAllPct)

            case 1:
                cell.textLabel?.text = "Medel saknade värden/dag"
                cell.detailTextLabel?.text = "\(countString(avgMissAll)) st"

            case 2:
                cell.textLabel?.text = "Antal sensorfel"
                cell.detailTextLabel?.text = "\(selectedSensorErrorOutages.count) st"

            case 3:
                cell.textLabel?.text = "Tid med sensorfel"
                let totalMin = selectedSensorErrorOutages.reduce(0) { $0 + $1.durationMinutes }
                let h = totalMin / 60
                let m = totalMin % 60
                if h > 0 {
                    cell.detailTextLabel?.text = "\(h) h \(m) min"
                } else {
                    cell.detailTextLabel?.text = "\(m) min"
                }

            case 4:
                cell.textLabel?.text = "Värden under LÅG tröskel (2.2)"
                let extremes = countExtremeValuesForSelectedPeriod()
                cell.detailTextLabel?.text = "\(extremes.low) st"

            case 5:
                cell.textLabel?.text = "Värden över HÖG tröskel (22.2)"
                let extremes = countExtremeValuesForSelectedPeriod()
                cell.detailTextLabel?.text = "\(extremes.high) st"

            default:
                break
            }

        case 1:
            // Trio uppladdningar realtid
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Medel lyckade/dag"
                cell.detailTextLabel?.text = percentString(avgNSPct)

            case 1:
                cell.textLabel?.text = "Medel missar/dag"
                cell.detailTextLabel?.text = "\(countString(avgMissNS)) st"

            case 2:
                cell.textLabel?.text = "Medel tid/dag utan värden"
                cell.detailTextLabel?.text = "\(countString(avgMinutesNoAll)) min"

            case 3:
                cell.textLabel?.text = "Bästa dag"
                if let d = bestDate {
                    cell.detailTextLabel?.text = "\(percentString(bestPct)) • \(dfISO.string(from: d))"
                } else {
                    cell.detailTextLabel?.text = "–"
                }

            case 4:
                cell.textLabel?.text = "Sämsta dag"
                if let d = worstDate {
                    cell.detailTextLabel?.text = "\(percentString(worstPct)) • \(dfISO.string(from: d))"
                } else {
                    cell.detailTextLabel?.text = "–"
                }

            default:
                break
            }

        default:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView,
                            willDisplayHeaderView view: UIView,
                            forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            header.textLabel?.textColor = .secondaryLabel
        }
    }
}
