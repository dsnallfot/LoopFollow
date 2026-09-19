import UIKit
import Charts

extension GlucoseView {
    func setupNavigationBar() {
        // När GlucoseView är root i sin navigation stack (egen UINavigationController)
        // så är vi i modalt läge. När vi är pushade från SettingsVC är vi inte root.
        let isModalRoot = navigationController?.viewControllers.first === self

        let reloadImage = UIImage(systemName: "arrow.clockwise")
        let reloadButtonView = UIButton(type: .system)
        reloadButtonView.setImage(reloadImage, for: .normal)
        reloadButtonView.tintColor = .label
        reloadButtonView.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)
        reloadButtonView.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        reloadButtonView.accessibilityLabel = "Uppdatera glukos"

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(refreshButtonLongPressed(_:)))
        reloadButtonView.addGestureRecognizer(longPress)

        let reload = UIBarButtonItem(customView: reloadButtonView)
        self.reloadButton = reload

        if isModalRoot {
            // Modalt: bara reload + filter på vänster sida
            navigationItem.leftBarButtonItems = [reload]
        } else {
            // Pushat från Settings: behåll back-knappen och supplementera med reload + filter
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.leftBarButtonItems = [reload]
        }

        // Optional close button to mirror other modal logs
        let done = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(doneTapped)
        )

        let info = UIBarButtonItem(
            image: UIImage(systemName: "chart.bar.xaxis.ascending"),
            style: .plain,
            target: self,
            action: #selector(showGlucoseStats)
        )
        info.tintColor = .label

        let filter = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(toggleMissingOnly)
        )
        filter.tintColor = .label

        if isModalRoot {
            // Modalt: visa både Klar och statistik
            navigationItem.rightBarButtonItems = [done, info, filter]
        } else {
            // Pushat: ingen Klar-knapp, bara statistik
            navigationItem.rightBarButtonItems = [info, filter]
        }
    }

    // MARK: - Header
    func setupHeader() {
        // Top horizontal row: date picker + spacer + stats label
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [datePicker, spacer, statsLabel])
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .center

        // Full header: top row + segmented control stacked vertically
        let headerStack = UIStackView(arrangedSubviews: [topRow, modeSegmentedControl])
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.alignment = .fill
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.tag = 999 // so we can find it in constraints
        view.addSubview(headerStack)

        datePicker.setContentHuggingPriority(.required, for: .horizontal)
        datePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        datePicker.heightAnchor.constraint(equalToConstant: 30).isActive = true
        datePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 105).isActive = true

        statsLabel.text = "CGM –" // placeholder until data loads
        statsLabel.heightAnchor.constraint(equalToConstant: 30).isActive = true

        modeSegmentedControl.addTarget(self, action: #selector(modeChanged(_:)), for: .valueChanged)
    }

    // MARK: - Table
    func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: "GlucoseCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.isOpaque = false
    }

    func setupConstraints() {
        let safe = view.safeAreaLayoutGuide
        guard let headerStack = view.subviews.first(where: { $0.tag == 999 }) else { return }

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 8),
            headerStack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
