import UIKit

// MARK: - Enums för strukturen
enum AlarmSection: Hashable {
    case categorySelection
    case alarmKitSettings
    case globalSettings // Snooze all, mute all
    case specificAlarm(String) // T.ex. "Low Alert", "High Alert"
    case nightSettings
    case inactivitySettings
}

enum AlarmRow: Hashable {
    // Navigation/Kategorier
    case action(title: String, id: String)
    case segmentedPicker(title: String, selected: Int, options: [String], id: String)
    case segmentControl
    
    // Generella inställningar
    case snoozeAll(Date?)
    case muteAll(Date?)
    
    // Specifika Larm-rader (Generisk wrapper för att slippa göra en case för varje larm)
    case toggle(title: String, isOn: Bool, id: String)
    case valueStepper(title: String, value: Double, min: Double, max: Double, step: Double, unit: String?, id: String)
    case soundPicker(title: String, currentSound: String, id: String)
    case optionPicker(title: String, currentOption: String, options: [String], id: String)
    case timePicker(title: String, date: Date?, id: String)
    case dateValue(title: String, date: Date?, id: String)
}

// MARK: - Återanvändbara Celler

// 1. Switch Cell
class SettingSwitchCell: UITableViewCell {
    static let reuseIdentifier = "SettingSwitchCell"
    private let switchControl = UISwitch()
    var onToggle: ((Bool) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
    
        // 🔹 Halvtransparent grå bakgrund (som i andra vyer)
                let bgColor = UIColor.clear
                backgroundColor = bgColor
                contentView.backgroundColor = bgColor

        
        contentView.addSubview(switchControl)
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            switchControl.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        switchControl.addTarget(self, action: #selector(didToggle), for: .valueChanged)
    }
    
    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isOn: Bool, onToggle: @escaping (Bool) -> Void) {
        textLabel?.text = title
        switchControl.isOn = isOn
        self.onToggle = onToggle
    }

    @objc private func didToggle() {
        onToggle?(switchControl.isOn)
    }
}

// Glucose settings are persisted in mg/dL; controls operate in the selected unit.
struct AlarmStepperScale {
    let isGlucose: Bool
    let usesMmol: Bool
    let minimumValue: Double
    let maximumValue: Double
    let stepValue: Double
    private let storageFactor: Double

    init(id: String, units: String?, minimum: Double, maximum: Double, step: Double) {
        switch id {
        case "low_bg", "urgent_low_bg", "high_bg", "urgent_high_bg",
             "low_persistence_max", "fast_drop_delta", "fast_rise_delta",
             "fast_drop_below_bg", "fast_rise_above_bg", "temporary_bg",
             "not_looping_lower_limit", "not_looping_upper_limit",
             "missed_bolus_low_grams_bg":
            isGlucose = true
        default:
            isGlucose = false
        }
        usesMmol = isGlucose && units == "mmol/L"
        storageFactor = usesMmol ? 18.0182 : 1
        stepValue = isGlucose ? (usesMmol ? 0.1 : 1) : step
        // Keep selectable tenths inside the original mg/dL limits.
        minimumValue = usesMmol ? (minimum / storageFactor * 10).rounded(.up) / 10 : minimum
        maximumValue = usesMmol ? (maximum / storageFactor * 10).rounded(.down) / 10 : maximum
    }

    func normalizedDisplayValue(_ value: Double) -> Double {
        let rounded = isGlucose ? (usesMmol ? (value * 10).rounded() / 10 : value.rounded()) : value
        return Swift.min(maximumValue, Swift.max(minimumValue, rounded))
    }

    func displayValue(forStoredValue value: Double) -> Double {
        normalizedDisplayValue(value / storageFactor)
    }

    func storedValue(forDisplayValue value: Double) -> Double {
        normalizedDisplayValue(value) * storageFactor
    }
}

// 2. Stepper Cell (Moderniserad)
class SettingStepperCell: UITableViewCell {
    static let reuseIdentifier = "SettingStepperCell"
    private let stepper = UIStepper()
    private let valueLabel = UILabel()
    private var currentStep: Double = 1
    var onValueChanged: ((Double) -> Void)?
    
    private var currentUnit: String?
    private var currentTitle: String = ""
    private var valueScale: AlarmStepperScale?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
        
        // 🔹 Samma halvtransparenta grå bakgrund
                let bgColor = UIColor.clear
                backgroundColor = bgColor
                contentView.backgroundColor = bgColor
        
    }
    
    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        let stack = UIStackView(arrangedSubviews: [valueLabel, stepper])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.centerXAnchor)
        ])
        
        valueLabel.textColor = .secondaryLabel
        valueLabel.font = .preferredFont(forTextStyle: .body)
        stepper.addTarget(self, action: #selector(stepperDidChange), for: .valueChanged)
    }

    func configure(title: String, value: Double, min: Double, max: Double, step: Double, unit: String?, id: String, onValueChanged: @escaping (Double) -> Void) {
        textLabel?.text = title
        currentTitle = title
        currentUnit = unit
        let scale = AlarmStepperScale(
            id: id, units: UserDefaultsRepository.units.value,
            minimum: min, maximum: max, step: step
        )
        valueScale = scale
        currentStep = scale.stepValue

        // Reset the range first because cells can be reused for unrelated settings.
        stepper.minimumValue = 0
        stepper.maximumValue = scale.maximumValue
        stepper.minimumValue = scale.minimumValue
        stepper.stepValue = scale.stepValue
        stepper.value = scale.displayValue(forStoredValue: value)

        updateLabelText(for: stepper.value)
        self.onValueChanged = onValueChanged
    }

    @objc private func stepperDidChange() {
        guard let scale = valueScale else { return }
        stepper.value = scale.normalizedDisplayValue(stepper.value)
        updateLabelText(for: stepper.value)
        onValueChanged?(scale.storedValue(forDisplayValue: stepper.value))
    }

    private func updateLabelText(for value: Double) {
        let unit = currentUnit ?? ""
        if valueScale?.isGlucose == true {
            let format = valueScale?.usesMmol == true ? "%.1f%@" : "%.0f%@"
            valueLabel.text = String(format: format, value, unit)
        } else if unit == "%" || currentTitle.contains("Volume") {
            valueLabel.text = "\(Int(value.rounded()))%"
        } else if currentStep < 1 {
            valueLabel.text = String(format: "%.1f%@", value, unit)
        } else {
            valueLabel.text = "\(Int(value.rounded()))\(unit)"
        }
    }

}

// 3. Segment Cell (För toppmenyn)
class SegmentSelectionCell: UITableViewCell {
    static let reuseIdentifier = "SegmentSelectionCell"
    let segmentedControl = UISegmentedControl()
    var onSegmentChanged: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(segmentedControl)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        // Layout constraints...
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            segmentedControl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            segmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        segmentedControl.addTarget(self, action: #selector(changed), for: .valueChanged)
        selectionStyle = .none
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }
    
    @objc func changed() {
        onSegmentChanged?(segmentedControl.selectedSegmentIndex)
    }
}

/// A vertical layout keeps all four period choices readable with large text sizes.
final class AlarmPeriodCell: UITableViewCell {
    static let reuseIdentifier = "AlarmPeriodCell"
    private let titleLabel = UILabel()
    private let picker = UISegmentedControl()
    private var onChange: ((Int) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        let stack = UIStackView(arrangedSubviews: [titleLabel, picker])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        picker.addTarget(self, action: #selector(changed), for: .valueChanged)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, selected: Int, options: [String], onChange: @escaping (Int) -> Void) {
        titleLabel.text = title
        picker.accessibilityLabel = title
        picker.removeAllSegments()
        for (index, option) in options.enumerated() { picker.insertSegment(withTitle: option, at: index, animated: false) }
        picker.selectedSegmentIndex = selected
        self.onChange = onChange
    }

    @objc private func changed() { onChange?(picker.selectedSegmentIndex) }
}
