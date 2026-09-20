//
//  MemoryLogView.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2026-09-11.
//  Copyright © 2026 Jon Fawcett. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Memory Log

/// Simple day-filtered memory log table.
final class MemoryLogViewController: ThemedViewController, UITableViewDataSource, UITableViewDelegate {

    private var entries: [MemoryEntry] = []
    private var selectedDate: Date = Date()

    // Toggle to show only missing rows
    private var showOnlyMissingMemory: Bool = false

    /// Row model for the table (memory + missing slots)
    private enum MemoryRow {
        case memory(MemoryEntry)
        case missing(Date)

        var date: Date {
            switch self {
            case .memory(let e): return e.date
            case .missing(let d): return d
            }
        }

        var isMissing: Bool {
            if case .missing = self { return true }
            return false
        }
    }

    private let tableView = UITableView(frame: .zero, style: .plain)

    lazy var filterButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain, target: self, action: #selector(toggleMissingOnly)
        )
        button.tintColor = .label
        button.accessibilityLabel = "Visa endast saknade minnesvärden"
        return button
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    // Build per-day rows, inserting missing 5‑min slots when gaps exceed ~6 minutes.
    private var dayRowsIncludingMissing: [MemoryRow] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }

        let dayEntriesAsc = entries
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }

        guard !dayEntriesAsc.isEmpty else { return [] }

        var rows: [MemoryRow] = []
        rows.reserveCapacity(dayEntriesAsc.count)

        for idx in 0..<dayEntriesAsc.count {
            let current = dayEntriesAsc[idx]
            rows.append(.memory(current))

            if idx < dayEntriesAsc.count - 1 {
                let next = dayEntriesAsc[idx + 1]
                let gap = next.date.timeIntervalSince(current.date)

                // Threshold: if more than 6 min, we consider at least one missing 5‑min slot
                if gap > 360 {
                    let missingCount = Int(floor((gap - 360) / 300)) + 1
                    if missingCount > 0 {
                        for i in 1...missingCount {
                            let missingDate = current.date.addingTimeInterval(Double(i) * 300)
                            if missingDate < next.date {
                                rows.append(.missing(missingDate))
                            }
                        }
                    }
                }
            }
        }

        // Tail-gap: insert missing slots after last actual value.
        let now = Date()
        if let lastActual = dayEntriesAsc.last {
            if cal.isDate(selectedDate, inSameDayAs: now) {
                // Today → fill to "now"
                let gapToNow = now.timeIntervalSince(lastActual.date)
                if gapToNow > 360 {
                    let missingCount = Int(floor((gapToNow - 360) / 300)) + 1
                    if missingCount > 0 {
                        for i in 1...missingCount {
                            let missingDate = lastActual.date.addingTimeInterval(Double(i) * 300)
                            if missingDate <= now {
                                rows.append(.missing(missingDate))
                            }
                        }
                    }
                }
            } else {
                // Historic day → fill to end-of-day (24:00)
                let gapToEnd = end.timeIntervalSince(lastActual.date)
                if gapToEnd > 360 {
                    let missingCount = Int(floor((gapToEnd - 360) / 300)) + 1
                    if missingCount > 0 {
                        for i in 1...missingCount {
                            let missingDate = lastActual.date.addingTimeInterval(Double(i) * 300)
                            if missingDate < end {
                                rows.append(.missing(missingDate))
                            }
                        }
                    }
                }
            }
        }

        // Table wants newest first
        return rows.sorted { $0.date > $1.date }
    }

    private var filteredRows: [MemoryRow] {
        let rows = dayRowsIncludingMissing
        if showOnlyMissingMemory {
            let missing = rows.filter { $0.isMissing }
            if missing.isEmpty {
                // Insert a synthetic placeholder missing row at noon
                let cal = Calendar.current
                let start = cal.startOfDay(for: selectedDate)
                let placeholderDate = cal.date(byAdding: .hour, value: 12, to: start) ?? start
                return [.missing(placeholderDate)]
            }
            return missing
        }
        return rows
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Trio minneslogg"
        updateBackgroundForCurrentMode()

        setupTableView()
        setupConstraints()
        loadDay(selectedDate)
    }

    @objc private func toggleMissingOnly() {
        showOnlyMissingMemory.toggle()

        let name = showOnlyMissingMemory
            ? "line.3.horizontal.decrease.circle.fill"
            : "line.3.horizontal.decrease.circle"
        filterButton.image = UIImage(systemName: name)
        filterButton.tintColor = showOnlyMissingMemory ? .systemBlue : .label
        filterButton.accessibilityLabel = showOnlyMissingMemory
            ? "Visa alla minnesvärden" : "Visa endast saknade minnesvärden"

        tableView.reloadData()
    }

    func showStats() {
        let statsVC = MemoryLogStatsViewController()
        statsVC.selectedDate = selectedDate
        let nav = UINavigationController(rootViewController: statsVC)

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
        present(nav, animated: true)
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: "MemoryCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableFooterView = UIView()
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
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func selectDate(_ date: Date) {
        guard !Calendar.current.isDate(selectedDate, inSameDayAs: date) else { return }
        selectedDate = date
        guard isViewLoaded else { return }
        entries = []
        tableView.reloadData()
        loadDay(date)
    }

    private func loadDay(_ date: Date) {
        Task {
            let samples = await MemoryCache.loadDay(date)
            let mapped: [MemoryEntry] = samples.map {
                MemoryEntry(date: Date(timeIntervalSince1970: $0.date), mib: $0.mib)
            }

            await MainActor.run {
                guard Calendar.current.isDate(self.selectedDate, inSameDayAs: date) else { return }
                // Newest first
                self.entries = mapped.sorted { $0.date > $1.date }
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // When no memory data exists at all, keep a single placeholder row.
        if entries.isEmpty {
            return 1
        }
        return max(filteredRows.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "MemoryCell", for: indexPath) as? Value1TableViewCell else {
            return UITableViewCell(style: .value1, reuseIdentifier: "MemoryCell")
        }

        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.font = .systemFont(ofSize: 17)

        // No raw data at all
        if entries.isEmpty {
            cell.textLabel?.text = "Inga minnesdata"
            cell.detailTextLabel?.text = ""
            return cell
        }

        let rows = filteredRows
        if rows.isEmpty {
            cell.textLabel?.text = "Inga minnesdata"
            cell.detailTextLabel?.text = ""
            return cell
        }

        let row = rows[indexPath.row]

        switch row {
        case .memory(let e):
            let timeStr = timeFormatter.string(from: e.date)
            cell.textLabel?.text = String(format: "%.0f MiB", e.mib)
            cell.detailTextLabel?.text = timeStr
            cell.detailTextLabel?.font = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .regular)
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear

        case .missing(let date):
            // Detect placeholder: no actual missing rows and showOnlyMissingMemory = true
            let isPlaceholder = showOnlyMissingMemory && dayRowsIncludingMissing.filter { $0.isMissing }.isEmpty
            if isPlaceholder {
                cell.textLabel?.text = "Inga saknade värden denna dag ✅"
                cell.detailTextLabel?.text = ""
                cell.textLabel?.font = .systemFont(ofSize: 17)
                let tint = UIColor.systemGreen.withAlphaComponent(0.12)
                cell.backgroundColor = tint
                cell.contentView.backgroundColor = tint
            } else {
                cell.textLabel?.text = "[Minnesvärde saknas]"
                cell.detailTextLabel?.text = timeFormatter.string(from: date)
                let tint = UIColor.systemRed.withAlphaComponent(0.15)
                cell.backgroundColor = tint
                cell.contentView.backgroundColor = tint
                cell.textLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            }
        }

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

