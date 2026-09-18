import UIKit

extension TreatmentsTableView {
    // MARK: - Date sync overlay
    func showDateSyncOverlay(message: String) {
        // Semi-transparent full-screen overlay
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.alpha = 0.0
        
        // Centered solid container
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        
        // SF Symbol icon
        let imageView = UIImageView(image: UIImage(systemName: "info.circle"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textAlignment = .center
        label.textColor = .label
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 40),
            imageView.widthAnchor.constraint(equalToConstant: 40),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 17),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -17),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
        
        overlay.addSubview(container)
        view.addSubview(overlay)
        
        let isModalRoot = navigationController?.viewControllers.first === self
        let containerTopInset: CGFloat = isModalRoot ? 77 : 120

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: overlay.topAnchor, constant: containerTopInset),
            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -12)
        ])
        view.layoutIfNeeded()
        
        // Light haptic feedback when the overlay appears
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        
        UIView.animate(withDuration: 0.25, animations: {
            overlay.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3,
                           delay: 1.4,
                           options: [.curveEaseInOut],
                           animations: {
                overlay.alpha = 0.0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
        })
    }
    
    // MARK: - Navigation Bar Setup
    
    func setupNavigationBar() {
        // Detect whether this controller is the *root* of its navigation stack.
        // When presented modally inside its own UINavigationController,
        // TreatmentsTableView will be the first (root) view controller.
        // When pushed from SettingsViewController, it will NOT be the root.
        let isModalRoot = navigationController?.viewControllers.first === self
        
        let klarButton = UIBarButtonItem(
            title: "Klar",
            style: .plain,
            target: self,
            action: #selector(doneButtonTapped)
        )
        let mealAnalysisButton = UIBarButtonItem(
            image: UIImage(systemName: "chart.bar.xaxis.ascending"),
            style: .plain,
            target: self,
            action: #selector(mealAnalysisButtonTapped)
        )
        
        // Right-side items:
        // - In modal (root) mode: show both Meal Analysis and Klar.
        // - When pushed from Settings: hide Klar, keep only Meal Analysis.
        if isModalRoot {
            navigationItem.rightBarButtonItems = [klarButton, mealAnalysisButton]
        } else {
            navigationItem.rightBarButtonItems = [mealAnalysisButton]
        }
        
        // Left-side refresh button (with tap + long press)
        let refreshButton = makeRefreshBarButtonItem()
        
        if isModalRoot {
            // In modal mode there is no back button, so just show the refresh button.
            navigationItem.leftBarButtonItem = refreshButton
        } else {
            // When pushed in a navigation stack, keep the default back button
            // and *supplement* it with the refresh button.
            navigationItem.leftItemsSupplementBackButton = true
            navigationItem.leftBarButtonItems = [refreshButton]
        }
    }

    /// Returns a UIBarButtonItem with a custom UIButton for refresh (tap + long press).
    func makeRefreshBarButtonItem() -> UIBarButtonItem {
        let button = UIButton(type: .system)

        // Use label color to match other toolbar icons
        button.tintColor = .label

        // Configure SF Symbol with semibold weight
        let config = UIImage.SymbolConfiguration(weight: .semibold)
        let image = UIImage(systemName: "arrow.clockwise", withConfiguration: config)
        button.setImage(image, for: .normal)

        button.sizeToFit()
        button.addTarget(self, action: #selector(refreshButtonTapped), for: .touchUpInside)

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(refreshButtonLongPressed(_:))
        )
        button.addGestureRecognizer(longPress)

        return UIBarButtonItem(customView: button)
    }
    
    @objc private func doneButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Setup Segmented Control
    
    func setupSegmentedControl() {
        let segments = ["Alla", "Auto", "Manuell", "Övriga"]
        segmentedControl = UISegmentedControl(items: segments)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        // Constraints added later via headerStack in setupConstraints()
    }
    
    @objc func filterChanged() {
        let previouslyVisibleDate = selectedDate

        tableView.reloadData()
        updateDuplicateIndicator()

        DispatchQueue.main.async {
            if let sectionIndex = self.filteredSectionIndex(for: previouslyVisibleDate),
               !self.filteredDaySections[sectionIndex].treatments.isEmpty {
                let indexPath = IndexPath(row: 0, section: sectionIndex)
                self.tableView.scrollToRow(at: indexPath, at: .top, animated: false)
                self.selectedDate = previouslyVisibleDate
                self.datePicker.setDate(previouslyVisibleDate, animated: false)
            } else {
                self.syncSelectedDateFromVisibleSection()
            }

            self.maybeLoadOlderDaysIfNeeded()
        }
    }
    
    // MARK: - Setup TableView
    
    func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        // Transparent table so ThemedViewController's gradient/background shows through
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.cellLayoutMarginsFollowReadableWidth = false
        view.addSubview(tableView)
        // Register the custom cell class so that cells are always .value1 style.
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: "TreatmentCell")
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    // MARK: - Setup Constraints
    
    func setupConstraints() {
        let safeArea = view.safeAreaLayoutGuide

        // --- Horizontal stack for date picker + segmented control ---
        let headerStack = UIStackView(arrangedSubviews: [datePicker, segmentedControl])
        headerStack.axis = .horizontal
        headerStack.spacing = 6
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        // Ensure the date picker shows its full content, let the segmented control shrink first
        datePicker.setContentHuggingPriority(.required, for: .horizontal)
        datePicker.setContentCompressionResistancePriority(.required, for: .horizontal)
        segmentedControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmentedControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Uniform compact heights (same as in MealAnalysisView)
        datePicker.heightAnchor.constraint(equalToConstant: 30).isActive = true
        segmentedControl.heightAnchor.constraint(equalToConstant: 30).isActive = true
        // Ensure the date text has room after we hid the calendar glyph
        datePicker.widthAnchor.constraint(lessThanOrEqualToConstant: 105).isActive = true

        NSLayoutConstraint.activate([
            // Pin headerStack at the top
            headerStack.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            headerStack.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 8),
            headerStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -8)
        ])

        // TableView below the headerStack
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
