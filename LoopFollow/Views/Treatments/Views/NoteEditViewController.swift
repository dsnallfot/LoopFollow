import UIKit

final class NoteEditViewController: ThemedViewController {

    private let initialNotes: String
    private let initialDate: Date

    var onSave: ((String, Date) -> Void)?
    var onCancel: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let notesTextView = UITextView()
    private let datePicker = UIDatePicker()

    init(initialNotes: String, initialDate: Date) {
        self.initialNotes = initialNotes
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
        updateBackgroundForCurrentMode()
    }

    private func setupNavigationBar() {
        title = "Redigera anteckning"

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
        notesTextView.translatesAutoresizingMaskIntoConstraints = false
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .leading

        let notesLabel = makeSectionLabel("Anteckning")
        let dateLabel = makeSectionLabel("Tidpunkt")

        notesTextView.font = .preferredFont(forTextStyle: .body)
        notesTextView.backgroundColor = .label.withAlphaComponent(0.12)
        notesTextView.layer.cornerRadius = 18
        notesTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        notesTextView.isScrollEnabled = true
        notesTextView.alwaysBounceVertical = true
        notesTextView.textContainer.lineBreakMode = .byWordWrapping
        notesTextView.textContainer.widthTracksTextView = true
        notesTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true

        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .compact
        datePicker.locale = Locale(identifier: "sv_SE")
        datePicker.minuteInterval = 1

        contentStack.addArrangedSubview(notesLabel)
        contentStack.addArrangedSubview(notesTextView)
        contentStack.addArrangedSubview(dateLabel)
        contentStack.addArrangedSubview(datePicker)
        notesTextView.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        datePicker.setContentHuggingPriority(.required, for: .horizontal)

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
        notesTextView.text = initialNotes
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
        let trimmedNotes = notesTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else { return }

        dismiss(animated: true) {
            self.onSave?(trimmedNotes, self.datePicker.date)
        }
    }
}

