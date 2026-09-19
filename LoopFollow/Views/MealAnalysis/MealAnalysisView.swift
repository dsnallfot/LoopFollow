//
//  MealAnalysisView.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2025-04-22.

//

import HealthKit
import UIKit
import Charts

class MealAnalysisView: ThemedViewController, ChartViewDelegate {
    
    weak var delegate: MealAnalysisViewDelegate?
    
    // Flagga för om användaren varit inne i EnteredByView under denna session
    var hasVisitedEnteredBy = false

    // MARK: - BG Bar Width Constraints
    var belowWidthConstraint: NSLayoutConstraint?
    var inWidthConstraint: NSLayoutConstraint?
    var aboveWidthConstraint: NSLayoutConstraint?

    // MARK: - BG Bar Properties
    // Promoted from viewDidLoad to file-private properties for access in updateBGLabels()
    let belowBar = UILabel()
    let inBar = UILabel()
    let aboveBar = UILabel()
    let inRangeRow = UIStackView()

    // All fetched events handed in by the presenting VC
    var events: [Event]          // will be augmented with cached entries
    let treatments: [Treatment]?  // original Nightscout treatments (for enteredBy analysis)
    /// Optional initial start time provided by the caller
    let initialStartOverride: Date?
    let initialEndOverride: Date?
    let modalWithTimestamp: Bool
    let modalTitleString: String
    let showsDoneButton: Bool
    let preSelectedSegment: Int?

    init(
        events: [Event],
        treatments: [Treatment]? = nil,
        initialStart: Date? = nil,
        initialEnd: Date? = nil,
        modalWithTimestamp: Bool = true,
        modalTitleString: String = "",
        showsDoneButton: Bool = true,
        preSelectedSegment: Int? = 0
    ) {
        self.events = events
        self.treatments = treatments
        self.initialStartOverride = initialStart
        self.initialEndOverride = initialEnd
        self.modalWithTimestamp = modalWithTimestamp
        self.modalTitleString = modalTitleString
        self.showsDoneButton = showsDoneButton
        self.preSelectedSegment = preSelectedSegment

        let now = Date()
        let calendar = Calendar.current

        // Grundläggande, säkert initialt tidsfönster så att endTime > startTime
        if let start = initialStart, let end = initialEnd {
            self.startTime = start
            self.endTime = end
        } else if let start = initialStart {
            self.startTime = start
            // defaulta till 3h-fönster framåt eller till nu, vilket som kommer först
            let candidateEnd = calendar.date(byAdding: .hour, value: 3, to: start) ?? start
            self.endTime = min(candidateEnd, now)
        } else if let end = initialEnd {
            let clampedEnd = min(end, now)
            self.endTime = clampedEnd
            // defaulta till 3h bakåt från end
            let candidateStart = calendar.date(byAdding: .hour, value: -3, to: clampedEnd) ?? clampedEnd
            self.startTime = candidateStart
        } else {
            // Ingen override: rullande 3h-fönster fram till nu
            self.endTime = now
            self.startTime = calendar.date(byAdding: .hour, value: -3, to: now) ?? now
        }

        // För-initiera lastDurationTitle med defaultsegmentets titel ("3h")
        // Denna kommer sedan att överskrivas i viewDidLoad när vi sätter rätt segment
        self.lastDurationTitle = "3h"

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI components & state

    // New start‑time picker
    let startPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "sv_SE")
        picker.translatesAutoresizingMaskIntoConstraints = false
        // Compact height
        picker.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return picker
    }()
    
    let endPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "sv_SE")
        picker.translatesAutoresizingMaskIntoConstraints = false
        // Compact height
        picker.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return picker
    }()

    let startTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "Starttid"
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let endTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "Sluttid"
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let durationControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["1h", "2h", "3h", "6h", "12h", "24h", "Dag", "Ⓢ", "☆"])
        control.selectedSegmentIndex = 2   // 3 h default
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    var lastDurationTitle: String?
    
    var freeSegmentIndex: Int {
        return durationControl.numberOfSegments - 1   // sista = "☆"
    }

    var endTime: Date = Date()
    var startTime: Date = Calendar.current.date(byAdding: .hour, value: -3, to: Date())!

    // MARK: - Insulin values
    var insulinTotal     = 0.0      // delivered insulin (SMB+Bolus+TempBasal)
    var bolusTotal       = 0.0
    var smbTotal         = 0.0
    var basalTotal       = 0.0      // delivered temp basal
    var profileBasalTotal = 0.0     // scheduled basal to subtract
    var carbsTotal       = 0.0
    var fpuTotal       = 0.0

    // Value labels (placeholders for now)
    let insulinTotalValueLabel = MealAnalysisView.makeValueLabel(bold: true)
    let bolusValueLabel        = MealAnalysisView.makeValueLabel()
    let smbValueLabel          = MealAnalysisView.makeValueLabel()
    let basalValueLabel        = MealAnalysisView.makeValueLabel()
    let profileBasalValueLabel = MealAnalysisView.makeValueLabel()
    let carbsValueLabel: UILabel = {
        let label = MealAnalysisView.makeValueLabel(bold: true)
        label.text = "0 g"
        return label
    }()
    let fpuValueLabel: UILabel = {
        let label = MealAnalysisView.makeValueLabel()
        label.text = "0 g"
        label.textColor = .secondaryLabel
        return label
    }()
    // Statistics value labels
    let realCRValueLabel          = MealAnalysisView.makeValueLabel(bold: false)
    let manualBolusValueLabel     = MealAnalysisView.makeValueLabel()
    let smbTempValueLabel         = MealAnalysisView.makeValueLabel()
    let changeBGTitleLabel        = UILabel()
    let changeBGValueLabel        = MealAnalysisView.makeValueLabel()
    private let inRangeValueLabel         = MealAnalysisView.makeValueLabel()
    let manualVsAutomatedLabel    = MealAnalysisView.makeValueLabel()
    var inRange: Double = 0.0

    // MARK: - Glucose data
    var bgEntries: [BGEntry] = []
    // BG chart (CombinedChartView for lines and scatter)
    let bgChartView = CombinedChartView()

    /// When `true`, any undelivered insulin (< 0.05 U) at the end of a Temp‑Basal segment
    /// is carried over to the next segment.
    /// When `false`, each segment starts its own accumulator (default behaviour).
    var carryOverUndeliveredBasals: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configureInitialWindow()
        //view.backgroundColor = .systemBackground
        updateBackgroundForCurrentMode()

        configureTimePickers()
        setupRangeBars()
        setupAnalysisLayout()
        normalizeInitialDuration()

        updateTotals()
        fetchBGData()
        // — Pull additional days from NightscoutCache (if any) —
        loadCachedData()

        setupNavigationBar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Skicka tillbaka när vi faktiskt lämnar vyn:
        //  • pop i navstack (Settings → Treatments → MealAnalysis)
        //  • modal dismiss (MainVC → Treatments(modal) → MealAnalysis(modal))
        let isGoingAway = isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true
        guard isGoingAway else { return }
        
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startTime)
        
        delegate?.mealAnalysisView(self,
                                   didReturnWithStartDate: startDay,
                                   didVisitEnteredBy: hasVisitedEnteredBy)
    }

}
