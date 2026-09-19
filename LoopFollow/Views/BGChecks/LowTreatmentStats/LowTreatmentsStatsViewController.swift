import UIKit
import Charts

// Den mesta koden nedan konsoliderad med BGCheckView 2026-01-27 - att städa upp vid tillfälle

// MARK: - Statistikvy

final class LowTreatmentsStatsViewController: ThemedTableViewController {

    // Full data set (upp till t.ex. 90 dagar)
    let allDays: [Date]
    let allCounts: [Int]
    let allGramsPerDay: [Double]

    // Underliggande enskilda behandlingar
    let allTreatmentDates: [Date]
    let allTreatmentGrams: [Double]
    let allTreatmentHasBGCheck: [Bool]

    // Underliggande BG Check-data (globala för cachefönstret)
    let allBGCheckDates: [Date]
    let allBGCheckMmol: [Double]

    // Aktuell vy (styrd av period/antal-gram)
    var selectedDays: [Date] = []
    var selectedCounts: [Int] = []
    var selectedGramsPerDay: [Double] = []

    var selectedTreatmentDates: [Date] = []
    var selectedTreatmentGrams: [Double] = []
    var selectedTreatmentHasBGCheck: [Bool] = []

    var selectedBGCheckDates: [Date] = []
    var selectedBGCheckMmol: [Double] = []

    var selectedPeriod: PeriodOption = .d14
    var selectedMode: ModeOption = .count
    var selectedTimeFilter: TimeFilterOption = .allTime

    lazy var periodControl: UISegmentedControl = {
        let items = PeriodOption.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = PeriodOption.allCases.firstIndex(of: selectedPeriod) ?? (items.count - 1)
        sc.addTarget(self, action: #selector(periodChanged(_:)), for: .valueChanged)
        return sc
    }()

    lazy var modeControl: UISegmentedControl = {
        let items = ModeOption.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = ModeOption.allCases.firstIndex(of: selectedMode) ?? 0
        sc.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        return sc
    }()

    lazy var timeFilterControl: UISegmentedControl = {
        let items = TimeFilterOption.allCases.map { $0.title }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = TimeFilterOption.allCases.firstIndex(of: selectedTimeFilter) ?? 0
        sc.addTarget(self, action: #selector(timeFilterChanged(_:)), for: .valueChanged)
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

    let scatterChartView: ScatterChartView = {
        let v = ScatterChartView()
        v.chartDescription.enabled = false
        v.legend.enabled = true
        v.minOffset = 8
        v.pinchZoomEnabled = false
        v.doubleTapToZoomEnabled = true
        v.scaleXEnabled = true
        v.scaleYEnabled = false
        v.dragEnabled = true
        v.highlightPerTapEnabled = true
        v.highlightPerDragEnabled = false
        v.drawMarkers = true
        v.rightAxis.enabled = true
        return v
    }()

    // Scatterplot: Dextro-behandlingar per datum (x) och tid på dygnet (y)
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

    init(
        days: [Date],
        counts: [Int],
        gramsPerDay: [Double],
        treatmentDates: [Date],
        treatmentGrams: [Double],
        treatmentHasBGCheck: [Bool],
        bgCheckDates: [Date],
        bgCheckMmol: [Double]
    ) {
        self.allDays = days
        self.allCounts = counts
        self.allGramsPerDay = gramsPerDay
        self.allTreatmentDates = treatmentDates
        self.allTreatmentGrams = treatmentGrams
        self.allTreatmentHasBGCheck = treatmentHasBGCheck
        self.allBGCheckDates = bgCheckDates
        self.allBGCheckMmol = bgCheckMmol
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
        title = "Dextrostatistik"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LowStatsCell")

        let initialPeriod = defaultPeriod()
        selectedPeriod = initialPeriod
        if let idx = PeriodOption.allCases.firstIndex(of: initialPeriod) {
            periodControl.selectedSegmentIndex = idx
        }
        // Time filter default
        if let filterIdx = TimeFilterOption.allCases.firstIndex(of: selectedTimeFilter) {
            timeFilterControl.selectedSegmentIndex = filterIdx
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

    // MARK: - Table view

private enum Row: Int, CaseIterable {
    case totalTreatments
    case avgTreatmentsPerDay
    case daysWithTreatmentsShare
    case oneDextroShare
    case twoDextroShare
    case threePlusDextroShare
    case nightTreatmentsCount
    case nightTreatmentsShare
    case longestNoTreatmentStreak
    case dextroWithFingerstickShare
}

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Row.allCases.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "LowStatsCell")
        cell.selectionStyle = .none

        // Transparent cell so the themed gradient shows
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        if #available(iOS 14.0, *) {
            var bg = UIBackgroundConfiguration.clear()
            bg.backgroundColor = .systemGray.withAlphaComponent(0.15)
            cell.backgroundConfiguration = bg
        }

        let row = Row(rawValue: indexPath.row)!
        switch row {
        case .totalTreatments:
            cell.textLabel?.text = "Dextrobehandlingar totalt"
            cell.detailTextLabel?.text = "\(totalTreatments) st"

        case .avgTreatmentsPerDay:
            cell.textLabel?.text = "Medel behandlingar per dag"
            if totalDays > 0 {
                let avg = Double(totalTreatments) / Double(totalDays)
                cell.detailTextLabel?.text = String(format: "%.1f st", avg)
            } else {
                cell.detailTextLabel?.text = "–"
            }

        case .daysWithTreatmentsShare:
            cell.textLabel?.text = "Andel dagar med dextro"
            cell.detailTextLabel?.text = percentageString(daysWithTreatments, totalDays)

        case .oneDextroShare:
            cell.textLabel?.text = "Behandling med 1 dextro"
            cell.detailTextLabel?.text = percentageString(oneDextroCount, totalTreatments)

        case .twoDextroShare:
            cell.textLabel?.text = "Behandling med 2 dextro"
            cell.detailTextLabel?.text = percentageString(twoDextroCount, totalTreatments)

        case .threePlusDextroShare:
            cell.textLabel?.text = "Behandling med 3+ dextro"
            cell.detailTextLabel?.text = percentageString(threePlusDextroCount, totalTreatments)

        case .nightTreatmentsCount:
            cell.textLabel?.text = "Dextrobehandlingar natt (22–06)"
            cell.detailTextLabel?.text = "\(nightTreatmentCount) st"

        case .nightTreatmentsShare:
            cell.textLabel?.text = "Andel natt av total (22–06)"
            cell.detailTextLabel?.text = percentageString(nightTreatmentCount, totalTreatments)

        case .longestNoTreatmentStreak:
            cell.textLabel?.text = "Längsta streak utan dextro"
            let hours = longestStreakWithoutTreatmentHours()
            cell.detailTextLabel?.text = "\(hours) h"

        case .dextroWithFingerstickShare:
            cell.textLabel?.text = "Andel dextro med fingerstick"
            cell.detailTextLabel?.text = percentageString(dextroWithFingerstickCount, totalTreatments)
        }

        return cell
    }
}
