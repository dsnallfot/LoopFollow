import UIKit

final class BGCheckEditViewController: ThemedViewController {

    private let initialGlucose: Double
    private let initialDate: Date

    var onSave: ((Double, Date) -> Void)?
    var onCancel: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let glucoseTextField = UITextField()
    private let datePicker = UIDatePicker()

    init(initialGlucose: Double, initialDate: Date) {
        self.initialGlucose = initialGlucose
        self.initialDate = initialDate
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupNavigationBar()
        setupLayout()
        populateValues()
    }

    private func setupView() {
        view.backgroundColor = .systemBackground
    }

    private func setupNavigationBar() {
        title = "Redigera fingerstick"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Avbryt",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Spara",
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        glucoseTextField.translatesAutoresizingMaskIntoConstraints = false
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .leading

        let glucoseLabel = makeSectionLabel("Blodsocker (mmol/L)")
        let dateLabel = makeSectionLabel("Tidpunkt")

        glucoseTextField.font = .preferredFont(forTextStyle: .body)
        glucoseTextField.backgroundColor = .label.withAlphaComponent(0.12)
        glucoseTextField.layer.cornerRadius = 12
        glucoseTextField.borderStyle = .none
        glucoseTextField.keyboardType = .decimalPad
        glucoseTextField.clearButtonMode = .whileEditing
        glucoseTextField.setLeftPaddingPoints(12)
        glucoseTextField.setRightPaddingPoints(12)
        glucoseTextField.heightAnchor.constraint(equalToConstant: 52).isActive = true

        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.locale = Locale(identifier: "sv_SE")
        datePicker.minuteInterval = 1
        datePicker.setContentHuggingPriority(.required, for: .horizontal)

        let glucoseFieldContainer = UIView()
        glucoseFieldContainer.translatesAutoresizingMaskIntoConstraints = false

        glucoseFieldContainer.addSubview(glucoseTextField)

        NSLayoutConstraint.activate([
            glucoseTextField.topAnchor.constraint(equalTo: glucoseFieldContainer.topAnchor),
            glucoseTextField.leadingAnchor.constraint(equalTo: glucoseFieldContainer.leadingAnchor),
            glucoseTextField.trailingAnchor.constraint(equalTo: glucoseFieldContainer.trailingAnchor),
            glucoseTextField.bottomAnchor.constraint(equalTo: glucoseFieldContainer.bottomAnchor)
        ])

        contentStack.addArrangedSubview(glucoseLabel)
        contentStack.addArrangedSubview(glucoseFieldContainer)
        contentStack.addArrangedSubview(dateLabel)
        contentStack.addArrangedSubview(datePicker)

        glucoseFieldContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func populateValues() {
        glucoseTextField.text = String(format: "%.1f", initialGlucose)
        datePicker.date = initialDate
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        return label
    }

    @objc private func cancelTapped() {
        dismiss(animated: true) {
            self.onCancel?()
        }
    }

    @objc private func saveTapped() {
        let trimmedText = glucoseTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalized = trimmedText.replacingOccurrences(of: ",", with: ".")
        guard let glucose = Double(normalized), glucose > 0 else { return }

        dismiss(animated: true) {
            self.onSave?(glucose, self.datePicker.date)
        }
    }
}

fileprivate extension UITextField {

    func setLeftPaddingPoints(_ amount: CGFloat) {

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))

        leftView = paddingView

        leftViewMode = .always

    }

    func setRightPaddingPoints(_ amount: CGFloat) {

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))

        rightView = paddingView

        rightViewMode = .always

    }

}
