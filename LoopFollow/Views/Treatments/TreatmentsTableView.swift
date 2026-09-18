import UIKit

/// A view controller that downloads and displays all treatments in a table view,
/// with a segmented control above the table to filter the results.
class TreatmentsTableView: ThemedViewController, UITableViewDataSource, UITableViewDelegate, TwilioRequestable, MealAnalysisViewDelegate {

    // Shared state is internal so the extensions in this folder can access it.
    // Keep helpers private when they are only used within their own file.
    // MARK: - State

    let tableView = UITableView()
    /// Flattened cache of all loaded treatments (kept mostly for existing logic)
    var treatments: [Treatment] = []
    var pendingShortcutDeletion: Treatment?

    struct TreatmentDaySection {
        let date: Date
        var treatments: [Treatment]
    }

    var daySections: [TreatmentDaySection] = []
    var isLoadingOlderDays = false
    var oldestLoadedDay: Date?
    let initialLoadedDayCount = 3
    
    /// Simple BG point model (in mmol/L) for this view's date window
    struct BGPoint {
        let date: Date
        let mmol: Double
    }

    /// Glucose points loaded for the current date window
    var bgPoints: [BGPoint] = []
    var bgPointsByDay: [Date: [BGPoint]] = [:]
    
    /// Tracks whether we've already auto-scrolled to the latest non-future
    /// treatment for "today" in the current session, to avoid fighting the user.
    var hasAutoScrolledToTodayLatest = false
    
    /// Picker for selecting a calendar date (“Valt datum”)
    let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "sv_SE")
        picker.translatesAutoresizingMaskIntoConstraints = false
        return picker
    }()
    /// Currently selected calendar date
    var selectedDate: Date = Date()
    // Segmented control to filter treatments.
    var segmentedControl: UISegmentedControl!
    
    // Define event type arrays for filtering.
    let autoTypes = ["Temp Basal", "SMB"]
    //private let mealTypes = ["Carb Correction", "Kolhydrater", "Dextro", "Måltid"]
    let manualTypes = ["Carb Correction", "Kolhydrater", "Dextro", "Måltid", "Bolus", "Correction Bolus", "Meal Bolus", "Insulinpenna", "Exercise", "BG Check"]
    
    // Activity indicator property for refresh progress
    var activityIndicator: UIActivityIndicatorView?
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Shift table content down to make room for the date picker
        self.title = "Behandlingar"
        //view.backgroundColor = .systemBackground
        updateBackgroundForCurrentMode()
        setupNavigationBar()
        setupSegmentedControl()
        setupTableView()
        // Add “Valt datum” picker
        view.addSubview(datePicker)
        datePicker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
        // Restrict selectable range to cached window
        let cal = Calendar.current
        if let oldest = cal.date(byAdding: .day,
                                  value: -NightscoutCache.retentionDays + 1,
                                  to: Date()) {
            datePicker.minimumDate = oldest
        }
        let maxSelectableDate = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        datePicker.maximumDate = maxSelectableDate
        datePicker.date = selectedDate
        setupConstraints()
        
        // Initial load for today (from cache if available, else fallback fetch)
        loadInitialDaySections(anchoredAt: selectedDate)

        // Listen for cache updates so we can refresh the table when new
        // treatments for the selected day have been written to NightscoutCache.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTreatmentsCacheUpdated(_:)),
            name: NSNotification.Name("TreatmentsCacheUpdated"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGlobalTreatmentsUpdated(_:)),
            name: .treatmentsUpdated,
            object: nil
        )
        
        // Register observers for shortcut callback notifications
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutSuccess), name: NSNotification.Name("ShortcutSuccess"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutError), name: NSNotification.Name("ShortcutError"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutCancel), name: NSNotification.Name("ShortcutCancel"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleShortcutPasscode), name: NSNotification.Name("ShortcutPasscode"), object: nil)

        // Ask MainViewController to perform a lightweight, treatments-only
        // refresh for the currently selected calendar day. It will fetch
        // treatments from Nightscout and update NightscoutCache, which in
        // turn triggers a "TreatmentsCacheUpdated" notification.
        //let cal = Calendar.current

        // IMPORTANT:
        // If the selected date is today, do NOT trigger a day-based cache refresh here.
        // A day-based refresh (midnight→midnight) can overwrite the rolling-window
        // treatments cache and cause MainViewController to temporarily lose pre-midnight
        // treatments in the chart until the next scheduled treatments task repopulates.
        if !cal.isDate(selectedDate, inSameDayAs: Date()) {
            let dayStart = cal.startOfDay(for: selectedDate)
            NotificationCenter.default.post(
                name: NSNotification.Name("RefreshTreatmentsCacheForDay"),
                object: nil,
                userInfo: ["day": dayStart]
            )
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Task {
            await NightscoutUtils.retryPendingUploads()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
}
