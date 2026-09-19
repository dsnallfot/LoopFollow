import UIKit
import Combine

//
//  ActiveAlarmsViewController.swift
//  LoopFollow
//
//  Created by Daniel Snällfot on 2026-02-06.
//

// MARK: - ActiveAlarmsViewController

final class ActiveAlarmsViewController: ThemedViewController, UITableViewDataSource, UITableViewDelegate {

    /// Called when the view controller is dismissed, so the caller can refresh its UI
    var onDismiss: (() -> Void)?

    var tableView: UITableView!
    var rowsBySection: [[ActiveAlarmRow]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Aktiva alarm"
        updateBackgroundForCurrentMode()
        configureDoneButton()
        buildRows()
        setupTableView()
    }

    private func configureDoneButton() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Klar",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
    }

    @objc private func doneTapped() {
        // Inform caller so it can refresh its UI (e.g. ModernAlarmViewController)
        onDismiss?()
        dismiss(animated: true, completion: nil)
    }

    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ActiveAlarmCell")
        view.addSubview(tableView)
    }
}
