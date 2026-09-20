import UIKit
import Charts

final class BatteryLogStatsViewController: ThemedViewController, ChartViewDelegate {

    private enum Mode: Int {
        case day = 0
        case week = 1
    }

    private var mode: Mode = .day
    var selectedDate: Date = Date()

    private let headerStack = UIStackView()

    private let dayLegendLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = UIFont.preferredFont(forTextStyle: .caption1)
        l.textColor = .secondaryLabel
        l.isHidden = false
        return l
    }()

    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .compact
        dp.translatesAutoresizingMaskIntoConstraints = false
        dp.locale = Locale(identifier: "sv_SE")
        return dp
    }()

    private let modeSegment: UISegmentedControl = {
        let s = UISegmentedControl(items: ["Dag", "Vecka"])
        s.selectedSegmentIndex = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let dayChartView: BarChartView = {
        let v = BarChartView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.legend.enabled = false
        v.chartDescription.enabled = false
        v.doubleTapToZoomEnabled = false
        v.pinchZoomEnabled = false
        v.scaleXEnabled = false
        v.scaleYEnabled = false
        v.highlightPerTapEnabled = true
        v.highlightPerDragEnabled = false
        return v
    }()

    private let weekChartView: CandleStickChartView = {
        let v = CandleStickChartView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.legend.enabled = false
        v.chartDescription.enabled = false
        v.doubleTapToZoomEnabled = false
        v.pinchZoomEnabled = false
        v.scaleXEnabled = false
        v.scaleYEnabled = false
        v.highlightPerTapEnabled = true
        v.highlightPerDragEnabled = false
        return v
    }()

    // Formatters
    private let dayXAxisFormatter = DayBatteryXAxisFormatter()
    private let weekXAxisFormatter = WeekBatteryXAxisFormatter()
    private let yAxisFormatter = BatteryYAxisValueFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Batteristatistik"
        updateBackgroundForCurrentMode()

        setupNavigationBar()
        setupHeader()
        setupCharts()
        setupConstraints()

        // Date picker bounds follow cache retention
        let cal = Calendar.current
        if let oldest = cal.date(byAdding: .day, value: -BatteryCache.retentionDays + 1, to: Date()) {
            datePicker.minimumDate = oldest
        }
        datePicker.maximumDate = Date()
        datePicker.date = selectedDate

        modeSegment.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)

        applyMode(.day, keepingDate: selectedDate)
    }

    // MARK: - UI setup

    private func setupNavigationBar() {
        let done = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(dismissSelf)
        )

        let prev = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(previousTapped)
        )

        let next = UIBarButtonItem(
            image: UIImage(systemName: "chevron.right"),
            style: .plain,
            target: self,
            action: #selector(nextTapped)
        )

        navigationItem.rightBarButtonItems = [done, next, prev]
        //navigationItem.leftBarButtonItems = [prev, next]
    }

    private func setupHeader() {
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.distribution = .fill
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(headerStack)
        headerStack.addArrangedSubview(datePicker)
        headerStack.addArrangedSubview(UIView())
        headerStack.addArrangedSubview(modeSegment)

        // Keep compact sizing similar to other screens
        datePicker.setContentHuggingPriority(.required, for: .horizontal)
        datePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        modeSegment.setContentHuggingPriority(.required, for: .horizontal)
        modeSegment.setContentCompressionResistancePriority(.required, for: .horizontal)

        datePicker.heightAnchor.constraint(equalToConstant: 30).isActive = true
        datePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 130).isActive = true
    }

    private func setupCharts() {
        view.addSubview(dayChartView)
        view.addSubview(weekChartView)
        view.addSubview(dayLegendLabel)
        updateLegendText(for: .day)

        dayChartView.delegate = self
        weekChartView.delegate = self

        configureYAxis(for: dayChartView.leftAxis, rightAxis: dayChartView.rightAxis)
        configureYAxis(for: weekChartView.leftAxis, rightAxis: weekChartView.rightAxis)

        configureDayXAxis()
        configureWeekXAxis()

        // Initial visibility
        dayChartView.isHidden = false
        weekChartView.isHidden = true

        // Background / grid aesthetics
        //dayChartView.backgroundColor = .clear
        //weekChartView.backgroundColor = .clear
        
        dayChartView.drawGridBackgroundEnabled = true
        dayChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)
        weekChartView.drawGridBackgroundEnabled = true
        weekChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // Ensure content isn't clipped at edges, and give extra room for edge labels
        weekChartView.setExtraOffsets(left: 14, top: 0, right: 14, bottom: 0)
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            headerStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),

            dayChartView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10),
            dayChartView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            dayChartView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            dayChartView.heightAnchor.constraint(equalToConstant: 300),
            dayLegendLabel.topAnchor.constraint(equalTo: dayChartView.bottomAnchor, constant: 8),
            dayLegendLabel.leadingAnchor.constraint(equalTo: dayChartView.leadingAnchor, constant: 15),
            dayLegendLabel.trailingAnchor.constraint(equalTo: dayChartView.trailingAnchor),
            dayLegendLabel.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -8),

            weekChartView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10),
            weekChartView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),//, constant: 8),
            weekChartView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            weekChartView.heightAnchor.constraint(equalToConstant: 300),
            weekChartView.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Axis configuration

    private func configureYAxis(for leftAxis: YAxis, rightAxis: YAxis) {
        rightAxis.enabled = false

        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = 100

        // Grid every 10%
        leftAxis.granularityEnabled = true
        leftAxis.granularity = 10

        // Force ticks across the full range (0..100) so 50% reliably appears
        leftAxis.setLabelCount(11, force: true)
        leftAxis.valueFormatter = yAxisFormatter
        leftAxis.drawLabelsEnabled = true

        leftAxis.drawGridLinesEnabled = true
        leftAxis.gridLineDashLengths = [2, 2]
        leftAxis.gridColor = UIColor.label.withAlphaComponent(0.5)

        leftAxis.drawAxisLineEnabled = true
        leftAxis.axisLineColor = UIColor.label.withAlphaComponent(1.0)
        leftAxis.axisLineWidth = 0.5
        leftAxis.labelTextColor = .secondaryLabel
    }

    private func configureDayXAxis() {
        let x = dayChartView.xAxis
        x.labelPosition = .bottom
        x.drawGridLinesEnabled = false
        x.drawAxisLineEnabled = true
        x.axisLineColor = UIColor.label.withAlphaComponent(1.0)
        x.axisLineWidth = 0.5
        x.labelTextColor = .secondaryLabel
        x.granularity = 1
        x.axisMinimum = 0
        x.axisMaximum = 96
        x.setLabelCount(9, force: true)
        x.valueFormatter = dayXAxisFormatter

        dayChartView.leftAxis.spaceTop = 5
        dayChartView.leftAxis.spaceBottom = 0
    }

    private func configureWeekXAxis() {
        let x = weekChartView.xAxis
        x.labelPosition = .bottom
        x.drawGridLinesEnabled = false
        x.drawAxisLineEnabled = true
        x.axisLineColor = UIColor.label.withAlphaComponent(1.0)
        x.axisLineWidth = 0.5
        x.labelTextColor = .secondaryLabel
        // We want ticks at integer day indices (0...6). When using padded min/max (-0.5..6.5),
        // do NOT force label count; forced labels are evenly distributed across the padded range
        // (step = 7/6) and would produce non-integer values that get rounded by the formatter.
        x.granularityEnabled = true
        x.granularity = 1

        // Add half-step padding so day 0 and day 6 candles are not clipped
        x.axisMinimum = -0.5
        x.axisMaximum = 6.5

        // Hint desired count, but do not force.
        x.setLabelCount(7, force: false)
        x.valueFormatter = weekXAxisFormatter

        // Keep first/last labels visible (prevents clipping/vanishing at edges)
        x.avoidFirstLastClippingEnabled = false

        weekChartView.leftAxis.spaceTop = 5
        weekChartView.leftAxis.spaceBottom = 0
    }

    // MARK: - Actions

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        let newMode: Mode = sender.selectedSegmentIndex == 0 ? .day : .week
        applyMode(newMode, keepingDate: selectedDate)
    }

    @objc private func dateChanged(_ sender: UIDatePicker) {
        selectedDate = sender.date
        if mode == .week {
            // Snap to start-of-week so week navigation behaves consistently
            selectedDate = startOfWeek(for: selectedDate)
            datePicker.date = selectedDate
        }
        reload()
    }

    @objc private func previousTapped() {
        let cal = Calendar.current
        switch mode {
        case .day:
            selectedDate = cal.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = cal.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
            selectedDate = startOfWeek(for: selectedDate)
        }
        datePicker.date = selectedDate
        reload()
    }

    @objc private func nextTapped() {
        let cal = Calendar.current
        let today = Date()
        switch mode {
        case .day:
            selectedDate = cal.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = cal.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
            selectedDate = startOfWeek(for: selectedDate)
        }

        // Prevent navigating into the future
        if selectedDate > today {
            selectedDate = today
            if mode == .week { selectedDate = startOfWeek(for: selectedDate) }
        }

        datePicker.date = selectedDate
        reload()
    }

    // MARK: - Mode

    private func applyMode(_ newMode: Mode, keepingDate date: Date) {
        mode = newMode
        modeSegment.selectedSegmentIndex = newMode.rawValue

        switch newMode {
        case .day:
            dayChartView.isHidden = false
            weekChartView.isHidden = true
            dayLegendLabel.isHidden = false
            updateLegendText(for: .day)
            selectedDate = date
            datePicker.date = selectedDate

        case .week:
            dayChartView.isHidden = true
            weekChartView.isHidden = false
            dayLegendLabel.isHidden = false   // 👈 fortfarande synlig
            updateLegendText(for: .week)
            selectedDate = startOfWeek(for: date)
            datePicker.date = selectedDate
        }

        reload()
    }

    // MARK: - Data loading + chart building

    private func reload() {
        switch mode {
        case .day:
            Task { await buildDayChart(for: selectedDate) }
        case .week:
            Task { await buildWeekChart(startingAt: startOfWeek(for: selectedDate)) }
        }
    }

    private func buildDayChart(for date: Date) async {
        let samples = await BatteryCache.loadDay(date)

        // Sort ascending by time
        let sorted = samples.sorted { $0.date < $1.date }

        // Pick the FIRST sample per 15-minute bucket (local time)
        // Bucket index: 0..95 (each is 15 minutes)
        var firstByQuarter: [Int: BatterySampleJSON] = [:]
        let cal = Calendar.current
        for s in sorted {
            let d = Date(timeIntervalSince1970: s.date)
            let hour = cal.component(.hour, from: d)
            let minute = cal.component(.minute, from: d)
            let quarter = hour * 4 + (minute / 15)
            if quarter >= 0 && quarter < 96, firstByQuarter[quarter] == nil {
                firstByQuarter[quarter] = s
            }
        }

        var entries: [BarChartDataEntry] = []
        var colors: [UIColor] = []

        for q in 0..<96 {
            if let s = firstByQuarter[q] {
                entries.append(BarChartDataEntry(x: Double(q), y: s.percent))
                colors.append(colorForBattery(percent: s.percent, isCharging: s.isCharging))
            } else {
                // No data for this 15-min bucket -> invisible bar (gap)
                entries.append(BarChartDataEntry(x: Double(q), y: 0))
                colors.append(UIColor.clear)
            }
        }

        let set = BarChartDataSet(entries: entries, label: "")
        set.colors = colors
        set.drawValuesEnabled = false
        set.highlightEnabled = true

        let data = BarChartData(dataSet: set)
        data.barWidth = 0.9

        await MainActor.run {
            self.dayChartView.data = data
            self.dayChartView.notifyDataSetChanged()
        }
    }

    private func buildWeekChart(startingAt weekStart: Date) async {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let start = cal.startOfDay(for: weekStart)
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start

        // Load all samples in the week window (inclusive).
        let endOfLastDay = cal.date(byAdding: .day, value: 1, to: end)!.addingTimeInterval(-1)
        let samples = await BatteryCache.loadWindow(from: start, to: endOfLastDay)

        // Build min/max per day
        var perDay: [[BatterySampleJSON]] = Array(repeating: [], count: 7)
        for s in samples {
            let d = Date(timeIntervalSince1970: s.date)
            let idx = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: d)).day ?? 0
            if idx >= 0 && idx < 7 {
                perDay[idx].append(s)
            }
        }

        var candleEntries: [CandleChartDataEntry] = []
        var candleColors: [NSUIColor] = []
        weekXAxisFormatter.reset()

        for i in 0..<7 {
            let daySamples = perDay[i].sorted { $0.date < $1.date }
            let dayDate = cal.date(byAdding: .day, value: i, to: start) ?? start

            // ✅ Always set x-axis label (even if the day has no samples)
            weekXAxisFormatter.setLabel(forIndex: i, date: dayDate)

            if daySamples.isEmpty {
                candleEntries.append(CandleChartDataEntry(x: Double(i), shadowH: 0, shadowL: 0, open: 0, close: 0))
                // Ingen data för denna dag – håll färgen neutral och diskret
                candleColors.append(NSUIColor.clear)
                continue
            }

            let percents = daySamples.map { $0.percent }
            let hi = percents.max() ?? 0
            let lo = percents.min() ?? 0

            candleEntries.append(CandleChartDataEntry(x: Double(i), shadowH: hi, shadowL: lo, open: hi, close: lo))

            // Färgkoda per dag baserat på lägsta batterinivån (samma logik som dagsgrafen)
            let color = colorForBattery(percent: lo, isCharging: false)
            candleColors.append(color)
        }

        let set = CandleChartDataSet(entries: candleEntries, label: "")
        set.drawValuesEnabled = false
        set.highlightEnabled = true
        set.setDrawHighlightIndicators(false)   // så du slipper crosshair-linjer
        set.shadowWidth = 1

        // Färgkoda varje dag baserat på lägsta batterinivå. Tomma dagar blir transparenta.
        set.colors = candleColors
        set.shadowColorSameAsCandle = true
        set.formLineWidth = 0
        set.barSpace = 0.2

        let data = CandleChartData(dataSet: set)

        await MainActor.run {
            self.weekChartView.data = data
            self.weekChartView.notifyDataSetChanged()
        }
    }

    // MARK: - Helpers

    private func updateLegendText(for mode: Mode) {
        switch mode {

        case .day:
            let a = NSMutableAttributedString(string: "Batteristatus:   ")

            func add(_ title: String, color: UIColor) {
                a.append(NSAttributedString(
                    string: "■ ",
                    attributes: [.foregroundColor: color]
                ))
                a.append(NSAttributedString(
                    string: title,
                    attributes: [.foregroundColor: UIColor.secondaryLabel]
                ))
            }

            add("Laddar  ", color: .systemBlue.withAlphaComponent(0.8))
            add("Bra  ", color: .systemGreen.withAlphaComponent(0.8))
            add("Låg  ", color: .systemOrange.withAlphaComponent(0.8))
            add("Akut låg", color: .systemRed.withAlphaComponent(0.8))

            dayLegendLabel.attributedText = a

        case .week:
            let a = NSMutableAttributedString()
            a.append(NSAttributedString(
                string: "■ ",
                attributes: [.foregroundColor: UIColor.systemGreen]
            ))
            a.append(NSAttributedString(
                string: "Max/min batteriprocent per dag",
                attributes: [.foregroundColor: UIColor.secondaryLabel]
            ))

            dayLegendLabel.attributedText = a
        }
    }

    private func colorForBattery(percent: Double, isCharging: Bool) -> UIColor {
        if isCharging { return .systemBlue.withAlphaComponent(0.8) }
        if percent >= 50 { return .systemGreen.withAlphaComponent(0.8) }
        if percent >= 20 { return .systemOrange.withAlphaComponent(0.8) }
        return .systemRed
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        // Use user's locale/calendar settings
        if let interval = cal.dateInterval(of: .weekOfYear, for: date) {
            return cal.startOfDay(for: interval.start)
        }
        return cal.startOfDay(for: date)
    }
    
    // MARK: - ChartViewDelegate (tap-to-navigate)

    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        if chartView === weekChartView {
            // Week -> Day: x is 0..6 for the day index in the selected week
            let idx = Int(round(entry.x))
            guard idx >= 0 && idx < 7 else { return }

            let cal = Calendar.current
            let weekStart = startOfWeek(for: selectedDate)
            guard let dayDate = cal.date(byAdding: .day, value: idx, to: weekStart) else { return }

            // Switch to day mode and show that date
            applyMode(.day, keepingDate: dayDate)
            selectedDate = cal.startOfDay(for: dayDate)
            datePicker.date = selectedDate
            reload()

            // Clear highlight to avoid accidental re-selection
            weekChartView.highlightValues(nil)

        } else if chartView === dayChartView {
            // Day -> Week: any bar tap opens the week containing the current selected day (Monday start)
            let cal = Calendar.current
            let weekStart = startOfWeek(for: selectedDate)

            applyMode(.week, keepingDate: weekStart)
            selectedDate = cal.startOfDay(for: weekStart)
            datePicker.date = selectedDate
            reload()

            dayChartView.highlightValues(nil)
        }
    }
    
    func chartValueNothingSelected(_ chartView: ChartViewBase) {
        // No-op
    }
}

// MARK: - Axis formatters

private final class BatteryYAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let v = Int(round(value))
        if v == 0 || v == 10 || v == 20 || v == 30 || v == 40 || v == 50 || v == 60 || v == 70 || v == 80 || v == 90 || v == 100 {
            return "\(v) %"
        }
        return ""
    }
}

private final class DayBatteryXAxisFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let i = Int(round(value))
        switch i {
        case 0: return "00"
        case 12: return "03"
        case 24: return "06"
        case 36: return "09"
        case 48: return "12"
        case 60: return "15"
        case 72: return "18"
        case 84: return "21"
        case 96: return "24"
        default: return ""
        }
    }
}

private final class WeekBatteryXAxisFormatter: AxisValueFormatter {

    private var labels: [Int: String] = [:]
    private let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "dd/MM"
        return f
    }()

    func setLabel(forIndex idx: Int, date: Date) {
        labels[idx] = df.string(from: date)
    }

    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let i = Int(round(value))
        return labels[i] ?? ""
    }
    
    func reset() {
        labels.removeAll()
    }
}
