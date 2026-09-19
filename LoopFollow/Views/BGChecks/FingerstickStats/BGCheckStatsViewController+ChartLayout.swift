import UIKit
import Charts

extension BGCheckStatsViewController {
    // MARK: - Chart header

    func setupChartHeader() {
        let container = UIView()
        container.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 340)
        container.backgroundColor = .clear

        chartView.backgroundColor = .clear
        timeChartView.backgroundColor = .clear
        periodControl.backgroundColor = .clear
        modeControl.backgroundColor = .clear

        container.addSubview(periodControl)
        container.addSubview(modeControl)
        container.addSubview(chartView)
        container.addSubview(timeChartView)

        periodControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        chartView.translatesAutoresizingMaskIntoConstraints = false
        timeChartView.translatesAutoresizingMaskIntoConstraints = false

        // Default visibility
        chartView.isHidden = false
        timeChartView.isHidden = true

        NSLayoutConstraint.activate([
            periodControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            periodControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            periodControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            modeControl.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 8),
            modeControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            modeControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            chartView.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 12),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),

            timeChartView.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 12),
            timeChartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            timeChartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            timeChartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -0)
        ])

        tableView.tableHeaderView = container
    }

    func loadChartData() {
        guard selectedDays.count == selectedCounts.count, !selectedDays.isEmpty else {
            chartView.data = nil
            timeChartView.data = nil
            chartView.setNeedsDisplay()
            timeChartView.setNeedsDisplay()
            return
        }

        switch selectedMode {
        case .count:
            loadCountChartData()
        case .time:
            loadTimeChartData()
        }
    }
}
