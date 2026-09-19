import UIKit
import Charts

/// Enkel loggvy för fingerstick / BG Check, inspirerad av GlucoseView.
final class BGCheckView: ThemedViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Model

    var mode: Mode = .fingerstick

    var fingerstickEntries: [BGCheckEntry] = []
    var dextroEntries: [LowTreatmentEntry] = []

    // För Dextro-stats (samma som bgCheckDatesForStats/bgCheckMmolForStats i LowTreatmentsView)
    var dextroBGCheckDates: [Date] = []
    var dextroBGCheckMmol: [Double] = []

    // Backwards-compat så resten av filen kan fortsätta använda `entries` tills vi fasar om
    var entries: [BGCheckEntry] {
        get { fingerstickEntries }
        set { fingerstickEntries = newValue }
    }

    // MARK: - UI

    let tableView = UITableView(frame: .zero, style: .plain)

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    let valueFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "sv_SE")
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        return nf
    }()

    let deltaFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "sv_SE")
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        nf.positivePrefix = "+"
        nf.negativePrefix = "-"
        return nf
    }()

    let gramsFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "sv_SE")
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 0
        return nf
    }()

    let mmolFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "sv_SE")
        nf.minimumFractionDigits = 1
        nf.maximumFractionDigits = 1
        return nf
    }()

    var activityIndicator: UIActivityIndicatorView?
    var reloadButton: UIBarButtonItem?

    let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        if #available(iOS 13.4, *) {
            dp.preferredDatePickerStyle = .compact
        }
        dp.locale = Locale(identifier: "sv_SE")
        dp.date = Date()
        return dp
    }()

    let modeControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Fingerstick", "Dextro"])
        sc.selectedSegmentIndex = 0
        return sc
    }()

    let topStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.alignment = .center
        sv.spacing = 8
        return sv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Fingerstick"
        //view.backgroundColor = .systemBackground
        updateBackgroundForCurrentMode()

        setupNavigationBar()
        setupDatePicker()
        setupTableView()
        setupConstraints()

        loadBGChecks()
    }
}
