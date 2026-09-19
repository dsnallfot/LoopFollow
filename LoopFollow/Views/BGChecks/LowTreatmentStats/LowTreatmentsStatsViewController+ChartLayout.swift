import UIKit
import Charts

extension LowTreatmentsStatsViewController {
    // MARK: - Chart header

    func setupChartHeader() {
        let container = UIView()
        container.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 340)
        container.backgroundColor = .clear

        container.addSubview(periodControl)
        container.addSubview(modeControl)
        container.addSubview(timeFilterControl)
        container.addSubview(chartView)
        container.addSubview(scatterChartView)
        container.addSubview(timeChartView)

        periodControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.translatesAutoresizingMaskIntoConstraints = false
        timeFilterControl.translatesAutoresizingMaskIntoConstraints = false
        chartView.translatesAutoresizingMaskIntoConstraints = false
        scatterChartView.translatesAutoresizingMaskIntoConstraints = false
        timeChartView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            periodControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            periodControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            periodControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            modeControl.topAnchor.constraint(equalTo: periodControl.bottomAnchor, constant: 8),
            modeControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            modeControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            timeFilterControl.topAnchor.constraint(equalTo: modeControl.bottomAnchor, constant: 8),
            timeFilterControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            timeFilterControl.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            chartView.topAnchor.constraint(equalTo: timeFilterControl.bottomAnchor, constant: 12),
            chartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            chartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            chartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),

            scatterChartView.topAnchor.constraint(equalTo: timeFilterControl.bottomAnchor, constant: 12),
            scatterChartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scatterChartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scatterChartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -0),

            timeChartView.topAnchor.constraint(equalTo: timeFilterControl.bottomAnchor, constant: 12),
            timeChartView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            timeChartView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            timeChartView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -0),
        ])

        // Utgångsläge: bar-chart visas, line-chart göms
        chartView.isHidden = !(selectedMode == .count || selectedMode == .grams)
        scatterChartView.isHidden = (selectedMode != .lowAndBg)
        timeChartView.isHidden = (selectedMode != .time)

        tableView.tableHeaderView = container
    }
}
