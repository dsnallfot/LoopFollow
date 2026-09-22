import UIKit
import Charts

//
//  GlucoseView.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2025-11-22.

//

/// Table-style glucose log, similar look/feel to TreatmentsTableView.
final class GlucoseView: ThemedViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Glucose data (same source as MealAnalysisView)
    /// Aktiva värden för valt läge (driver tabell + stats).
    var bgEntries: [Reading] = []
    /// Retained for sensor-note outage bounds; no separate table mode.
    var nsOnlyDayEntries: [Reading] = []
    /// Dexcom+Nightscout-mergade värden för vald dag.
    var allValuesDayEntries: [Reading] = []

    var dataMode: GlucoseDataMode = .allValues

    // How many days back the manual backfill refresh should fetch (used by reload button)
    let backfillDays = 14
    // Initial Nightscout backfill window for NS-only cache used in GlucoseView
    let initialBackfillDays = 91
    // UserDefaults flag so we only run the large initial backfill once
    let initialBackfillFlagKey = "GlucoseViewInitialNSBackfillDone"

    // Selected day for table
    var selectedDate: Date = Date()

    // Throttle so we don’t fetch on every quick appear (e.g. during navigation)
    var lastNSOnly24hRefreshAt: Date?
    let nsOnly24hRefreshMinInterval: TimeInterval = 60 // seconds

    // UI
    let tableView = UITableView(frame: .zero, style: .plain)
    let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .compact
        dp.translatesAutoresizingMaskIntoConstraints = false
        dp.locale = Locale(identifier: "sv_SE")
        return dp
    }()

    let modeSegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Glukosvärden", "Sensorfel"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private var activityIndicator: UIActivityIndicatorView?

    // Toggle to show only missing rows
    var showOnlyMissingGlucose: Bool = false

    // Sensor error rows (90 days)
    var sensorErrorRows: [GlucoseRow] = []
    let sensorErrorLookbackDays: Int = 91
    private let sensorErrorCacheRowsKey = "GlucoseViewSensorErrorCacheRows"
    private let sensorErrorCacheLastRefreshKey = "GlucoseViewSensorErrorCacheLastRefresh"

    let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    let statsLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .secondaryLabel
        l.textAlignment = .right
        l.numberOfLines = 1
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.setContentCompressionResistancePriority(.required, for: .horizontal)
        return l
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Glukos"
        //view.backgroundColor = .systemBackground
        updateBackgroundForCurrentMode()

        // Open the combined glucose log by default
        dataMode = .allValues
        modeSegmentedControl.selectedSegmentIndex = 0

        setupNavigationBar()
        setupTableView()
        setupHeader()
        setupConstraints()

        // Date picker bounds roughly follow NS-only glucose cache retention
        let cal = Calendar.current
        if let oldest = cal.date(byAdding: .day,
                                 value: -GlucoseNSOnlyCache.retentionDays + 1,
                                 to: Date()) {
            datePicker.minimumDate = oldest
        }
        datePicker.maximumDate = Date()
        datePicker.date = selectedDate
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)

        // Debug: list cached NS-only glucose day files whenever entering GlucoseView
        //GlucoseNSOnlyCache.debugListSegments()
        //print("GlucoseNSOnlyCache dir:", GlucoseNSOnlyCache.dir.path)

        // Initial NS-only backfill (90 days) + initial load for today from NS cache
        Task {
            await self.ensureInitialBackfill()
            await MainActor.run {
                self.loadBG(for: self.selectedDate)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Task {
            // Always keep NS-only cache fresh for last 24h when opening the view
            await refreshNSOnlyCacheRecent(hours: 24)

            await MainActor.run {
                // Reload current day so labels/SAKNAS reasons are correct immediately
                self.loadBG(for: self.selectedDate)
            }
        }
    }

    // MARK: - Navigation bar
    var reloadButton: UIBarButtonItem?
    var reloadIndicator: UIActivityIndicatorView?
}
