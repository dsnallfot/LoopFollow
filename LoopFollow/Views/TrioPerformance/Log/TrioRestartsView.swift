import UIKit

/// Enkel loggvy för att fånga noteringar innehållande "Trio startades om" , inspirerad av BGCheckView.
final class TrioRestartsView: ThemedViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - Model

    private var entries: [RestartEntry] = []

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)

    private var selectedDate = Date()
    private var needsDateFocus = true
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    func selectDate(_ date: Date) {
        selectedDate = date
        needsDateFocus = true
        if isViewLoaded { focusSelectedDateIfNeeded() }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Apply themed background (gradient in dark mode)
        updateBackgroundForCurrentMode()
        title = "Trio omstartslogg"

        setupTableView()
        setupConstraints()

        loadRestarts()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        focusSelectedDateIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        focusSelectedDateIfNeeded()
    }

    private func focusSelectedDateIfNeeded() {
        guard needsDateFocus, view.window != nil, tableView.bounds.height > 0,
              let index = RestartEntry.nearestIndex(to: selectedDate, in: entries) else { return }
        needsDateFocus = false
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: false)
    }

    func showRestartStats() {
        let calendar = Calendar.current
        let now = Date()
        let daysBack = min(NightscoutCache.retentionDays, 90)

        guard let startDay = calendar.date(byAdding: .day, value: -(daysBack - 1), to: calendar.startOfDay(for: now)) else {
            return
        }

        var days: [Date] = []
        var counts: [Int] = []
        days.reserveCapacity(daysBack)
        counts.reserveCapacity(daysBack)

        for offset in 0..<daysBack {
            if let day = calendar.date(byAdding: .day, value: offset, to: startDay) {
                days.append(day)
                counts.append(0)
            }
        }

        var indexByDay: [Date: Int] = [:]
        for (idx, day) in days.enumerated() {
            indexByDay[calendar.startOfDay(for: day)] = idx
        }

        for entry in entries {
            if entry.date < startDay || entry.date > now { continue }
            let dayStart = calendar.startOfDay(for: entry.date)
            if let idx = indexByDay[dayStart] {
                counts[idx] += 1
            }
        }

        let restartDates = entries.map { $0.date }

        let statsVC = TrioRestartsStatsViewController(days: days, counts: counts, restartDates: restartDates)
        let nav = UINavigationController(rootViewController: statsVC)

        // Ensure the modal container doesn't paint an opaque gray background.
        nav.modalPresentationStyle = .formSheet
        nav.view.backgroundColor = .clear
        nav.view.isOpaque = false
        nav.view.layer.backgroundColor = UIColor.clear.cgColor

        // Transparent navigation bar so the gradient shows behind it too.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance

        // Match current interface style
        nav.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle

        present(nav, animated: true)
    }

    // MARK: - Setup table

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RestartCell")
        tableView.rowHeight = 50
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(refreshTapped), for: .valueChanged)
        tableView.refreshControl = refresh
        // Themed background: let gradient show through
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.isOpaque = false
    }

    private func setupConstraints() {
        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safe.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: safe.bottomAnchor)
        ])
    }

    // MARK: - Loading from cache

    @objc private func refreshTapped() {
        loadRestarts()
    }

    /// Hämtar alla `Note`-treatments från cachen vars notes innehåller "Trio startades om".
    private func loadRestarts() {
        tableView.backgroundView = activityIndicator
        activityIndicator.startAnimating()

        Task {
            let now = Date()
            let cal = Calendar.current

            let start = cal.date(
                byAdding: .day,
                value: -NightscoutCache.retentionDays,
                to: cal.startOfDay(for: now)
            ) ?? now.addingTimeInterval(-91 * 24 * 60 * 60)

            let (_, treatments) = await NightscoutCache.loadWindow(from: start, to: now)

            let restartNotes: [RestartEntry] = treatments.compactMap { t -> RestartEntry? in
                guard t.eventType == "Note" else { return nil }

                guard let note = t.notes, note.contains("Trio startades om") else { return nil }

                let date = t.created_at
                return RestartEntry(date: date, note: note)
            }
            .sorted { $0.date > $1.date }

            await MainActor.run {
                self.entries = restartNotes
                self.tableView.reloadData()
                self.tableView.refreshControl?.endRefreshing()
                self.activityIndicator.stopAnimating()
                self.tableView.backgroundView = nil
                self.focusSelectedDateIfNeeded()
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return max(entries.count, 1)
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RestartCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "RestartCell")
        cell.textLabel?.numberOfLines = 1
        // Transparent cell so the themed gradient shows through
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        if #available(iOS 14.0, *) {
            cell.backgroundConfiguration = nil
        }
        cell.textLabel?.backgroundColor = .clear
        cell.detailTextLabel?.backgroundColor = .clear

        guard !entries.isEmpty else {
            cell.textLabel?.text = "Inga omstarter i historiken"
            cell.textLabel?.font = .systemFont(ofSize: 17)
            cell.imageView?.image = nil
            cell.accessoryView = nil
            cell.selectionStyle = .none
            return cell
        }

        let entry = entries[indexPath.row]

        // Leading text = note (kompakt, en rad)
        let note = entry.note
        let compact = note.replacingOccurrences(of: "\n", with: " ")
        cell.textLabel?.text = "\(compact)"
        cell.textLabel?.font = .systemFont(ofSize: 16)

        // SF-symbol i imageView (leading) – restart
        cell.imageView?.image = UIImage(systemName: "arrow.triangle.2.circlepath")
        cell.imageView?.tintColor = .systemPurple

        // Right-aligned full date + time
        let rightLabel = UILabel()
        rightLabel.text = DateFormatter.localizedString(from: entry.date, dateStyle: .short, timeStyle: .short)
        rightLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)//.systemFont(ofSize: 14)
        rightLabel.textColor = .secondaryLabel
        rightLabel.textAlignment = .right
        rightLabel.sizeToFit()
        cell.accessoryView = rightLabel

        cell.selectionStyle = .default
        cell.accessoryType = .none
        // Match Treatments-style selection highlight (subtle overlay over the gradient)
        cell.selectionStyle = .default
        let selected = UIView()
        selected.backgroundColor = UIColor.label.withAlphaComponent(0.2)
        selected.layer.cornerRadius = 10
        selected.layer.masksToBounds = true
        cell.selectedBackgroundView = selected
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !entries.isEmpty else { return }
        let entry = entries[indexPath.row]
        let startDate = entry.date
        let endDate = entry.date + 60 * 180


        // Hitta MainViewController via root UITabBarController för att få events,
        // men presentera modalen härifrån så vi kommer tillbaka hit när den stängs.

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first(where: { $0.isKeyWindow }),
            let tabBar = window.rootViewController as? UITabBarController,
            let tabViewControllers = tabBar.viewControllers
        else {
            return
        }

        var mainVC: MainViewController?

        for vc in tabViewControllers {
            if let nav = vc as? UINavigationController {

                if let candidate = nav.viewControllers.first(where: { $0 is MainViewController }) as? MainViewController {
                    mainVC = candidate
                    break
                }
            } else if let candidate = vc as? MainViewController {
                mainVC = candidate
                break
            }
        }

        guard let mainVC else {
            return
        }

        // Bygg events via MainViewController, men presentera modalen härifrån.
        let events = mainVC.buildEventsForMealAnalysis()

        let analysisVC = MealAnalysisView(
            events: events,
            initialStart: startDate,
            initialEnd: endDate,
            modalWithTimestamp: true,
            modalTitleString: "Analys omstart",
            preSelectedSegment: 2
        )
        let nav = UINavigationController(rootViewController: analysisVC)
        nav.modalPresentationStyle = .formSheet

        nav.view.backgroundColor = .clear
        nav.view.isOpaque = false
        nav.view.layer.backgroundColor = UIColor.clear.cgColor

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance

        nav.overrideUserInterfaceStyle = self.traitCollection.userInterfaceStyle

        self.present(nav, animated: true) { [weak self] in
            self?.tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

