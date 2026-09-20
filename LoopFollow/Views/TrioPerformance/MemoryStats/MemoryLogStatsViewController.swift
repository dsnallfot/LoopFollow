import UIKit
import Charts

/// Memory stats view with day, week and 30-day visualization.
final class MemoryLogStatsViewController: ThemedViewController, ChartViewDelegate {

    private enum Mode: Int {
        case day = 0
        case week = 1
        case thirtyDays = 2
    }

    private var mode: Mode = .day
    private var thirtyDayStart: Date?
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
        let s = UISegmentedControl(items: ["Dag", "Vecka", "30 dagar"])
        s.selectedSegmentIndex = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let dayChartView: CombinedChartView = {
        let v = CombinedChartView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.drawOrder = [CombinedChartView.DrawOrder.bar.rawValue, CombinedChartView.DrawOrder.scatter.rawValue]
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

    private let weekChartView = makeCandleChartView()
    private let thirtyDaysChartView = makeCandleChartView()

    private static func makeCandleChartView() -> CombinedChartView {
        let v = CombinedChartView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.drawOrder = [CombinedChartView.DrawOrder.candle.rawValue, CombinedChartView.DrawOrder.scatter.rawValue]
        v.legend.enabled = false
        v.chartDescription.enabled = false
        v.doubleTapToZoomEnabled = false
        v.pinchZoomEnabled = false
        v.scaleXEnabled = false
        v.scaleYEnabled = false
        v.highlightPerTapEnabled = true
        v.highlightPerDragEnabled = false
        return v
    }

    // Formatters
    private let dayXAxisFormatter = DayMemoryXAxisFormatter()
    private let weekXAxisFormatter = WeekMemoryXAxisFormatter()
    private let thirtyDaysXAxisFormatter = WeekMemoryXAxisFormatter()
    private let yAxisFormatter = MemoryYAxisValueFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Minnestatistik"
        updateBackgroundForCurrentMode()

        setupNavigationBar()
        setupHeader()
        setupCharts()
        setupConstraints()

        // Date picker bounds follow cache retention
        let cal = Calendar.current
        if let oldest = cal.date(byAdding: .day, value: -MemoryCache.retentionDays + 1, to: Date()) {
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
        view.addSubview(thirtyDaysChartView)
        view.addSubview(dayLegendLabel)
        updateLegendText(for: .day)

        dayChartView.delegate = self
        weekChartView.delegate = self
        thirtyDaysChartView.delegate = self

        configureYAxis(for: dayChartView.leftAxis, rightAxis: dayChartView.rightAxis)
        configureYAxis(for: weekChartView.leftAxis, rightAxis: weekChartView.rightAxis)

        configureDayXAxis()
        configureYAxis(for: thirtyDaysChartView.leftAxis, rightAxis: thirtyDaysChartView.rightAxis)
        configureCandleXAxis(for: weekChartView, dayCount: 7, formatter: weekXAxisFormatter)
        configureCandleXAxis(for: thirtyDaysChartView, dayCount: 30, formatter: thirtyDaysXAxisFormatter)

        // Initial visibility
        dayChartView.isHidden = false
        weekChartView.isHidden = true
        thirtyDaysChartView.isHidden = true

        // Background / grid aesthetics
        //dayChartView.backgroundColor = .clear
        //weekChartView.backgroundColor = .clear

        dayChartView.drawGridBackgroundEnabled = true
        dayChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)
        weekChartView.drawGridBackgroundEnabled = true
        weekChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)

        // Ensure content isn't clipped at edges, and give extra room for edge labels
        weekChartView.setExtraOffsets(left: 14, top: 0, right: 14, bottom: 0)
        thirtyDaysChartView.drawGridBackgroundEnabled = true
        thirtyDaysChartView.gridBackgroundColor = NSUIColor.systemBackground.withAlphaComponent(0.5)
        thirtyDaysChartView.setExtraOffsets(left: 14, top: 0, right: 14, bottom: 0)
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
            weekChartView.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -8),

            thirtyDaysChartView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 10),
            thirtyDaysChartView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            thirtyDaysChartView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            thirtyDaysChartView.heightAnchor.constraint(equalToConstant: 300),
            thirtyDaysChartView.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -8)
        ])
    }

    // MARK: - Axis configuration

    private func configureYAxis(for leftAxis: YAxis, rightAxis: YAxis) {
        rightAxis.enabled = false

        leftAxis.axisMinimum = 0
        leftAxis.axisMaximum = 1 // Empty/all-zero data fallback; updated for each dataset.
        leftAxis.granularityEnabled = false
        leftAxis.setLabelCount(6, force: true)
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

    private func configureCandleXAxis(for chart: CombinedChartView, dayCount: Int, formatter: WeekMemoryXAxisFormatter) {
        let x = chart.xAxis
        x.labelPosition = .bottom
        x.drawGridLinesEnabled = false
        x.drawAxisLineEnabled = true
        x.axisLineColor = UIColor.label.withAlphaComponent(1.0)
        x.axisLineWidth = 0.5
        x.labelTextColor = .secondaryLabel
        // Keep ticks on whole days, with five-day spacing for the 30-day chart.
        // Do not force label count across the padded range.
        x.granularityEnabled = true
        x.granularity = dayCount == 30 ? 5 : 1

        // Add half-step padding so the first and last candles are not clipped
        x.axisMinimum = -0.5
        x.axisMaximum = Double(dayCount) - 0.5

        // Hint desired count, but do not force.
        x.setLabelCount(dayCount == 30 ? 6 : 7, force: false)
        x.valueFormatter = formatter

        // Keep first/last labels visible (prevents clipping/vanishing at edges)
        x.avoidFirstLastClippingEnabled = false

        chart.leftAxis.spaceTop = 5
        chart.leftAxis.spaceBottom = 0
    }

    // MARK: - Actions

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func modeChanged(_ sender: UISegmentedControl) {
        guard let newMode = Mode(rawValue: sender.selectedSegmentIndex) else { return }
        if newMode == .thirtyDays {
            let cal = Calendar.current
            let defaultStart = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: Date())) ?? Date()
            applyMode(newMode, keepingDate: thirtyDayStart ?? defaultStart)
        } else {
            applyMode(newMode, keepingDate: selectedDate)
        }
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
        case .thirtyDays:
            selectedDate = cal.date(byAdding: .day, value: -30, to: selectedDate) ?? selectedDate
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
        case .thirtyDays:
            selectedDate = cal.date(byAdding: .day, value: 30, to: selectedDate) ?? selectedDate
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

        dayChartView.isHidden = newMode != .day
        weekChartView.isHidden = newMode != .week
        thirtyDaysChartView.isHidden = newMode != .thirtyDays
        dayLegendLabel.isHidden = false
        updateLegendText(for: newMode)
        selectedDate = newMode == .week ? startOfWeek(for: date) : Calendar.current.startOfDay(for: date)
        datePicker.date = selectedDate

        reload()
    }

    // MARK: - Data loading + chart building

    private func reload() {
        switch mode {
        case .day:
            Task { await buildDayChart(for: selectedDate) }
        case .week:
            Task { await buildCandleChart(startingAt: startOfWeek(for: selectedDate), chartMode: .week) }
        case .thirtyDays:
            selectedDate = Calendar.current.startOfDay(for: selectedDate)
            thirtyDayStart = selectedDate
            Task { await buildCandleChart(startingAt: selectedDate, chartMode: .thirtyDays) }
        }
    }

    private func buildDayChart(for date: Date) async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }
        let history = await memoryHistory(through: end)
        let samples = history.filter { $0.date >= start.timeIntervalSince1970 && $0.date < end.timeIntervalSince1970 }
        let restartMarkers = await restartMarkers(from: start, to: end, memoryHistory: history)

        // One bar per saved reading, positioned by local time on the same 00–24 axis.
        let entries = samples.sorted { $0.date < $1.date }.map { sample in
            let x = dayX(for: Date(timeIntervalSince1970: sample.date), calendar: cal)
            return BarChartDataEntry(x: x, y: sample.mib)
        }

        let set = BarChartDataSet(entries: entries, label: "Minnesanvändning (MiB)")
        set.colors = [.white]
        set.drawValuesEnabled = false
        set.highlightEnabled = true

        let barData = BarChartData(dataSet: set)
        barData.barWidth = 0.3
        let markerEntries = restartMarkers.map {
            ChartDataEntry(x: dayX(for: $0.date, calendar: cal), y: $0.mib)
        }
        let data = CombinedChartData()
        data.barData = barData
        data.scatterData = makeRestartScatterData(entries: markerEntries)

        await MainActor.run {
            guard self.mode == .day, Calendar.current.isDate(self.selectedDate, inSameDayAs: date) else { return }
            let maximumMiB = max(samples.map { $0.mib }.max() ?? 0, restartMarkers.map { $0.mib }.max() ?? 0)
            self.dayChartView.leftAxis.axisMaximum = maximumMiB > 0 ? maximumMiB * 1.08 : 1
            self.dayChartView.data = data
            self.dayChartView.notifyDataSetChanged()
        }
    }

    private func buildCandleChart(startingAt date: Date, chartMode: Mode) async {
        let cal = Calendar.current
        let dayCount = chartMode == .thirtyDays ? 30 : 7
        let chart = chartMode == .thirtyDays ? thirtyDaysChartView : weekChartView
        let formatter = chartMode == .thirtyDays ? thirtyDaysXAxisFormatter : weekXAxisFormatter
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: dayCount, to: start) else { return }

        // Use calendar days and an exclusive end, including fractional-second samples at midnight.
        let history = await memoryHistory(through: end)
        let samples = history.filter { $0.date >= start.timeIntervalSince1970 && $0.date < end.timeIntervalSince1970 }
        let restartMarkers = await restartMarkers(from: start, to: end, memoryHistory: history)

        // Build min/max per day
        var perDay: [[MemorySampleJSON]] = Array(repeating: [], count: dayCount)
        for s in samples {
            let d = Date(timeIntervalSince1970: s.date)
            let idx = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: d)).day ?? 0
            if idx >= 0 && idx < dayCount {
                perDay[idx].append(s)
            }
        }

        var candleEntries: [CandleChartDataEntry] = []
        guard mode == chartMode, cal.startOfDay(for: selectedDate) == start else { return }
        formatter.reset()

        for i in 0..<dayCount {
            let daySamples = perDay[i].sorted { $0.date < $1.date }
            let dayDate = cal.date(byAdding: .day, value: i, to: start) ?? start

            // ✅ Always set x-axis label (even if the day has no samples)
            formatter.setLabel(forIndex: i, date: dayDate)

            guard !daySamples.isEmpty else { continue }

            let mibs = daySamples.map { $0.mib }
            let hi = mibs.max() ?? 0
            let lo = mibs.min() ?? 0

            candleEntries.append(CandleChartDataEntry(x: Double(i), shadowH: hi, shadowL: lo, open: hi, close: lo))

        }

        let set = CandleChartDataSet(entries: candleEntries, label: "")
        set.drawValuesEnabled = false
        set.highlightEnabled = true
        set.setDrawHighlightIndicators(false)   // så du slipper crosshair-linjer
        set.shadowWidth = 1

        set.colors = [.white]
        set.decreasingColor = .white
        set.increasingColor = .white
        set.neutralColor = .white
        set.decreasingFilled = true
        set.increasingFilled = true
        set.shadowColorSameAsCandle = true
        set.formLineWidth = 0
        set.barSpace = 0.2

        let markerEntries = restartMarkers.compactMap { marker -> ChartDataEntry? in
            let day = cal.startOfDay(for: marker.date)
            let index = cal.dateComponents([.day], from: start, to: day).day ?? -1
            guard index >= 0 && index < dayCount else { return nil }
            return ChartDataEntry(x: Double(index), y: marker.mib)
        }
        let data = CombinedChartData()
        data.candleData = CandleChartData(dataSet: set)
        data.scatterData = makeRestartScatterData(entries: markerEntries)

        await MainActor.run {
            guard self.mode == chartMode, cal.startOfDay(for: self.selectedDate) == start else { return }
            let maximumMiB = max(samples.map { $0.mib }.max() ?? 0, restartMarkers.map { $0.mib }.max() ?? 0)
            chart.leftAxis.axisMaximum = maximumMiB > 0 ? maximumMiB * 1.08 : 1
            chart.data = data
            chart.notifyDataSetChanged()
        }
    }

    // MARK: - Helpers

    private struct RestartMarker {
        let date: Date
        let mib: Double
    }

    private func memoryHistory(through end: Date) async -> [MemorySampleJSON] {
        let calendar = Calendar.current
        let oldest = calendar.date(byAdding: .day, value: -MemoryCache.retentionDays + 1,
                                   to: calendar.startOfDay(for: Date())) ?? end
        guard oldest < end else { return [] }
        return await MemoryCache.loadWindow(from: oldest, to: end)
            .filter { $0.date < end.timeIntervalSince1970 }
            .sorted { $0.date < $1.date }
    }

    private func restartMarkers(from start: Date, to end: Date,
                                memoryHistory: [MemorySampleJSON]) async -> [RestartMarker] {
        guard !memoryHistory.isEmpty else { return [] }
        let (_, treatments) = await NightscoutCache.loadWindow(from: start, to: end)
        let restarts = treatments
            .filter { $0.eventType == "Note" && ($0.notes?.contains("Trio startades om") ?? false)
                     && $0.created_at >= start && $0.created_at < end }
            .sorted { $0.created_at < $1.created_at }

        var markers: [RestartMarker] = []
        var sampleIndex = 0
        for restart in restarts {
            let timestamp = restart.created_at.timeIntervalSince1970
            while sampleIndex < memoryHistory.count && memoryHistory[sampleIndex].date < timestamp {
                sampleIndex += 1
            }
            guard sampleIndex > 0 else { continue }
            markers.append(RestartMarker(date: restart.created_at, mib: memoryHistory[sampleIndex - 1].mib))
        }
        return markers
    }

    private func dayX(for date: Date, calendar: Calendar) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60 + (components.second ?? 0))
        return min(95.85, max(0.15, seconds / 900))
    }

    private func makeRestartScatterData(entries: [ChartDataEntry]) -> ScatterChartData {
        let set = ScatterChartDataSet(entries: entries, label: "Trio omstart")
        set.setScatterShape(.circle)
        set.scatterShapeSize = 10
        set.colors = [.systemPurple]
        set.drawValuesEnabled = false
        set.highlightEnabled = false
        return ScatterChartData(dataSet: set)
    }

    private func updateLegendText(for mode: Mode) {
        let text = mode == .day
            ? "Uppmätt minne (MiB)"
            : "Max/min minne per dag (MiB)"
        let legend = NSMutableAttributedString(string: "■ ", attributes: [.foregroundColor: UIColor.white])
        legend.append(NSAttributedString(string: text, attributes: [.foregroundColor: UIColor.secondaryLabel]))
        legend.append(NSAttributedString(string: "   ● ", attributes: [.foregroundColor: UIColor.systemPurple]))
        legend.append(NSAttributedString(string: "Trio startades om", attributes: [.foregroundColor: UIColor.secondaryLabel]))
        dayLegendLabel.attributedText = legend
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
        if chartView === weekChartView || chartView === thirtyDaysChartView {
            // Open the selected day from either multi-day chart.
            let dayCount = chartView === thirtyDaysChartView ? 30 : 7
            let idx = Int(round(entry.x))
            guard idx >= 0 && idx < dayCount else { return }

            let cal = Calendar.current
            let weekStart = chartView === thirtyDaysChartView ? selectedDate : startOfWeek(for: selectedDate)
            guard let dayDate = cal.date(byAdding: .day, value: idx, to: weekStart) else { return }

            // Switch to day mode and show that date
            applyMode(.day, keepingDate: dayDate)
            selectedDate = cal.startOfDay(for: dayDate)
            datePicker.date = selectedDate
            reload()

            // Clear highlight to avoid accidental re-selection
            chartView.highlightValues(nil)

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

private final class MemoryYAxisValueFormatter: AxisValueFormatter {
    func stringForValue(_ value: Double, axis: AxisBase?) -> String {
        let format = (axis?.axisMaximum ?? 0) < 5 ? "%.1f MiB" : "%.0f MiB"
        return String(format: format, value)
    }
}

private final class DayMemoryXAxisFormatter: AxisValueFormatter {
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

private final class WeekMemoryXAxisFormatter: AxisValueFormatter {

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
