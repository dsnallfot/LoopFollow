import UIKit
import Charts

extension BGCheckView {
    // MARK: - Nav bar

    func setupNavigationBar() {
        // Samma logik som Behandlingslogg / Dextrologg
        let isModalRoot = navigationController?.viewControllers.first === self

        // Reload-knapp (samma look & feel som GlucoseView)
        let reload = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(refreshTapped)
        )
        self.reloadButton = reload

        // Klar-knapp när vi är modala
        let done = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(doneTapped)
        )

        let statsBtn = UIBarButtonItem(
            image: UIImage(systemName: "chart.bar.xaxis.ascending"),
            style: .plain,
            target: self,
            action: #selector(showBGCheckStats)
        )

        if isModalRoot {
            // MODAL: stats + Klar, reload till vänster
            navigationItem.rightBarButtonItems = [statsBtn, done]
            navigationItem.leftBarButtonItem = reload
        } else {
            // PUSH: bara stats till höger, back-pil + reload till vänster
            navigationItem.rightBarButtonItems = [statsBtn]
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.leftBarButtonItems = [reload]
        }
    }

    func setupDatePicker() {
        topStack.translatesAutoresizingMaskIntoConstraints = false
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        modeControl.translatesAutoresizingMaskIntoConstraints = false

        // Arranged subviews: exakt som i TreatMentsTableView (datePicker + segmentedControl)
        topStack.axis = .horizontal
        topStack.spacing = 6
        topStack.alignment = .center
        topStack.addArrangedSubview(datePicker)
        topStack.addArrangedSubview(modeControl)

        view.addSubview(topStack)

        // Samma hugging/compression-trick som i TreatMentsTableView
        datePicker.setContentHuggingPriority(.required, for: .horizontal)
        datePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        modeControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        modeControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Uniform compact heights
        datePicker.heightAnchor.constraint(equalToConstant: 30).isActive = true
        modeControl.heightAnchor.constraint(equalToConstant: 30).isActive = true
        // Ge datumtexten plats (samma som kommentaren i TreatMentsTableView)
        datePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 105).isActive = true

        datePicker.addTarget(self, action: #selector(datePickerChanged(_:)), for: .valueChanged)
        modeControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)

        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            topStack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            topStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            topStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8)
        ])
    }

    // MARK: - Setup table

    func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Don't register: we want to create with .subtitle style below
        tableView.rowHeight = 50
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()

        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.isOpaque = false
    }

    func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
