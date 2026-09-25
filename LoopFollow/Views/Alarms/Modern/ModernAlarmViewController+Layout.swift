import UIKit
import Combine

extension ModernAlarmViewController {
    func setupTableView() {
        // 1. Skapa TableView med rätt stil
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.delegate = self
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear

        // 2. Registrera celler
        tableView.register(AlarmPeriodCell.self, forCellReuseIdentifier: AlarmPeriodCell.reuseIdentifier)
        tableView.register(SettingSwitchCell.self, forCellReuseIdentifier: SettingSwitchCell.reuseIdentifier)
        tableView.register(SettingStepperCell.self, forCellReuseIdentifier: SettingStepperCell.reuseIdentifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "DefaultCell")

        view.addSubview(tableView)

        // 3. Konfigurera Header Container
        // Vi sätter en temporär höjd, layoutIfNeeded kommer fixa resten
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 92))

        let stack = UIStackView(arrangedSubviews: [categorySegmentedControl, subCategorySegmentedControl])
        stack.axis = .vertical
        stack.spacing = 12 // Lite mer luft mellan segmenten ser modernare ut
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(stack)

        // 4. Constraints för StackView inuti containern
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -26)
        ])

        // 5. Viktigt: Tvinga containern att beräkna sin höjd baserat på stackviewns innehåll
        headerContainer.setNeedsLayout()
        headerContainer.layoutIfNeeded()

        // Beräkna den exakta storleken som behövs
        let targetSize = CGSize(width: view.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = headerContainer.systemLayoutSizeFitting(targetSize)
        headerContainer.frame.size.height = size.height

        // Sätt containern som header
        tableView.tableHeaderView = headerContainer
    }

}
