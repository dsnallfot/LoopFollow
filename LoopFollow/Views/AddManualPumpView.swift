import UIKit

protocol AddManualPumpDelegate: AnyObject {
    func didAddManualPumpChange(entry: PumpChangeHistoryEntry)
    func didUpdateManualPumpChange(entry: PumpChangeHistoryEntry, at index: Int)
}

class AddManualPumpViewController: ThemedViewController {

    weak var delegate: AddManualPumpDelegate?
    private let sitePicker = SiteSelectionButton()
    private var editingIndex: Int?
    private var editingOriginal: PumpChangeHistoryEntry?

    func configureForEditing(entry: PumpChangeHistoryEntry, index: Int) {
        editingIndex = index
        editingOriginal = entry
        if isViewLoaded {
            sitePicker.configure(site: entry.site)
            datePicker.date = Date(timeIntervalSince1970: entry.date)
            self.title = "Redigera pumpbyte"
            navigationItem.rightBarButtonItem?.title = "Uppdatera"
        }
    }

    private let datePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .dateAndTime
        picker.preferredDatePickerStyle = .wheels
        picker.maximumDate = Date()
        picker.locale = Locale(identifier: "sv_SE")
        return picker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Registrera pumpbyte"
        //view.backgroundColor = .systemBackground
        updateBackgroundForCurrentMode()
        setupUI()
        setupNavigationBar()

        if let existing = editingOriginal {
            sitePicker.configure(site: existing.site)
            datePicker.date = Date(timeIntervalSince1970: existing.date)
            self.title = "Redigera pumpbyte"
            navigationItem.rightBarButtonItem?.title = "Uppdatera"
        }
    }

    private func setupNavigationBar() {
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

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        var entry = editingOriginal ?? PumpChangeHistoryEntry(date: datePicker.date.timeIntervalSince1970)
        if entry.date != datePicker.date.timeIntervalSince1970 {
            entry.insulinSummary = nil
            if entry.siteIsManual != true {
                entry.site = nil
                entry.siteNoteID = nil
                entry.siteNoteDate = nil
            }
        }
        entry.date = datePicker.date.timeIntervalSince1970
        if sitePicker.wasEdited {
            entry.site = sitePicker.selectedSite
            entry.siteIsManual = true
            entry.siteNoteID = nil
            entry.siteNoteDate = nil
        }

        if let idx = editingIndex {
            delegate?.didUpdateManualPumpChange(entry: entry, at: idx)
        } else {
            delegate?.didAddManualPumpChange(entry: entry)
        }
        dismiss(animated: true)
    }

    private func setupUI() {
        view.addSubview(datePicker)
        view.addSubview(sitePicker)
        sitePicker.translatesAutoresizingMaskIntoConstraints = false
        datePicker.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            datePicker.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            datePicker.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            sitePicker.topAnchor.constraint(equalTo: datePicker.bottomAnchor, constant: 20),
            sitePicker.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sitePicker.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            sitePicker.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
}
