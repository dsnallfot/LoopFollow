import UIKit

/// Shared navigation and date selection for the Trio performance logs.
final class TrioPerformanceViewController: ThemedViewController {
    private enum Mode: Int {
        case battery, memory, restarts
    }

    private var mode: Mode = .battery
    private var selectedDate = Date()
    private let batteryLog = BatteryLogViewController()
    private let memoryLog = MemoryLogViewController()
    private let restartLog = TrioRestartsView()
    private var activeLog: UIViewController?
    private let contentView = UIView()

    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale = Locale(identifier: "sv_SE")
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.accessibilityLabel = "Datum för loggen"
        return picker
    }()

    private let modeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Batteri", "Minne", "Omstarter"])
        control.selectedSegmentIndex = Mode.battery.rawValue
        control.translatesAutoresizingMaskIntoConstraints = false
        control.accessibilityLabel = "Loggtyp"
        return control
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBackgroundForCurrentMode()
        setupLayout()
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        showSelectedLog()
    }

    private func setupLayout() {
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [datePicker, spacer, modeControl])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)
        view.addSubview(contentView)

        datePicker.setContentHuggingPriority(.required, for: .horizontal)
        datePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        modeControl.setContentHuggingPriority(.required, for: .horizontal)
        modeControl.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),
            datePicker.heightAnchor.constraint(equalToConstant: 30),
            datePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 105),
            modeControl.heightAnchor.constraint(equalToConstant: 30),
            contentView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            contentView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func showSelectedLog() {
        updateDateBounds()
        let child: UIViewController
        switch mode {
        case .battery:
            title = "Trio batterilogg"
            child = batteryLog
        case .memory:
            title = "Trio minneslogg"
            child = memoryLog
        case .restarts:
            title = "Trio omstartslogg"
            child = restartLog
        }
        if activeLog !== child {
            activeLog?.willMove(toParent: nil)
            activeLog?.view.removeFromSuperview()
            activeLog?.removeFromParent()
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                child.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                child.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
            child.didMove(toParent: self)
            activeLog = child
        }
        updateNavigationBar()
    }

    private func updateDateBounds() {
        let calendar = Calendar.current
        let now = Date()
        let retention: Int
        switch mode {
        case .battery: retention = BatteryCache.retentionDays
        case .memory: retention = MemoryCache.retentionDays
        case .restarts: retention = NightscoutCache.retentionDays
        }
        // Restart history includes the entire oldest day retained by NightscoutCache.
        let oldestOffset = mode == .restarts ? -retention : -retention + 1
        let oldest = calendar.date(byAdding: .day, value: oldestOffset, to: calendar.startOfDay(for: now)) ?? now
        selectedDate = min(max(selectedDate, oldest), now)
        datePicker.minimumDate = oldest
        datePicker.maximumDate = now
        datePicker.date = selectedDate
        selectDateInActiveLog()
    }

    private func updateNavigationBar() {
        let stats = UIBarButtonItem(image: UIImage(systemName: "chart.bar.xaxis.ascending"),
                                    style: .plain, target: self, action: #selector(showStats))
        stats.tintColor = .label
        var buttons = [stats]
        switch mode {
        case .battery:
            stats.accessibilityLabel = "Batteristatistik"
            buttons.append(batteryLog.filterButton)
        case .memory:
            stats.accessibilityLabel = "Minnesstatistik"
            buttons.append(memoryLog.filterButton)
        case .restarts:
            stats.accessibilityLabel = "Omstartsstatistik"
        }
        if navigationController?.viewControllers.first === self {
            buttons.insert(UIBarButtonItem(title: "Klar", style: .plain, target: self,
                                           action: #selector(doneTapped)), at: 0)
        }
        navigationItem.rightBarButtonItems = buttons
    }

    @objc private func modeChanged() {
        guard let selectedMode = Mode(rawValue: modeControl.selectedSegmentIndex) else { return }
        mode = selectedMode
        showSelectedLog()
    }

    @objc private func dateChanged() {
        selectedDate = datePicker.date
        selectDateInActiveLog()
    }

    private func selectDateInActiveLog() {
        datePicker.accessibilityLabel = mode == .restarts ? "Hoppa till datum i omstartsloggen" : "Datum för loggen"
        switch mode {
        case .battery: batteryLog.selectDate(selectedDate)
        case .memory: memoryLog.selectDate(selectedDate)
        case .restarts: restartLog.selectDate(selectedDate)
        }
    }

    @objc private func showStats() {
        switch mode {
        case .battery: batteryLog.showStats()
        case .memory: memoryLog.showStats()
        case .restarts: restartLog.showRestartStats()
        }
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
