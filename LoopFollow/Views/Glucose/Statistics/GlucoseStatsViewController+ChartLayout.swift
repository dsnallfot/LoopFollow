import UIKit
import Charts

extension GlucoseStatsViewController {
    // MARK: - Chart header

    func setupChartHeader() {
        let container = UIView()
        container.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 350)
        container.backgroundColor = .clear

        container.addSubview(periodControl)
        container.addSubview(chartModeControl)
        container.addSubview(chartView)
        container.addSubview(sensorErrorChartView)

        periodControl.translatesAutoresizingMaskIntoConstraints = false
        chartModeControl.translatesAutoresizingMaskIntoConstraints = false
        chartView.translatesAutoresizingMaskIntoConstraints = false
        sensorErrorChartView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            periodControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            periodControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            periodControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            chartModeControl.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 8),
            chartModeControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            chartModeControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            chartView.topAnchor.constraint(equalTo: chartModeControl.bottomAnchor, constant: 12),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: 20),

            sensorErrorChartView.topAnchor.constraint(equalTo: chartModeControl.bottomAnchor, constant: 12),
            sensorErrorChartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            sensorErrorChartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            sensorErrorChartView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Initial visibility
        chartView.isHidden = (selectedChartMode == .sensorErrors)
        sensorErrorChartView.isHidden = (selectedChartMode != .sensorErrors)

        tableView.tableHeaderView = container
    }
}
