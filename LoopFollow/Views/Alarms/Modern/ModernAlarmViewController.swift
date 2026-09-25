import UIKit
import Combine

class ModernAlarmViewController: ThemedViewController, UITableViewDelegate {

    // UI
    var tableView: UITableView!
    var dataSource: UITableViewDiffableDataSource<AlarmSection, AlarmRow>!

    // Logic
    let viewModel = AlarmViewModel()
    private var cancellables = Set<AnyCancellable>()

    // Knapp för att visa en snabböversikt över aktiva larm
    lazy var activeAlarmsButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "switch.2"),
            style: .plain,
            target: self,
            action: #selector(activeAlarmsButtonTapped)
        )
        return item
    }()

    lazy var alarmStatsButton: UIBarButtonItem = {
        let item = UIBarButtonItem(
        image: UIImage(systemName: "chart.bar.xaxis.ascending"),
        style: .plain,
        target: self,
        action: #selector(didTapAlarmStats)
        )
        return item
    }()

    // Top Filter Bar (Istället för segments i celler, snyggare i header)
    lazy var categorySegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Hög/Låg", "Trend", "Trio", "Teknik", "Övrigt"])
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        return sc
    }()

    lazy var subCategorySegmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: viewModel.alertBGOptions) // Initialt BG
        sc.selectedSegmentIndex = 0
        sc.addTarget(self, action: #selector(subCategoryChanged), for: .valueChanged)
        return sc
    }()

    func requestAlarmKitPermission() {
        if #available(iOS 26.0, *) {
            Task { await LoopFollowAlarmKit.shared.requestPermission() }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Alarm"
        //view.backgroundColor = .systemGroupedBackground
        updateBackgroundForCurrentMode()

        setupTableView()
        configureDataSource()

        // Lyssna på ändringar i ViewModel
        viewModel.$selectedCategoryIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applySnapshot()
            }
            .store(in: &cancellables)

        if #available(iOS 26.0, *) {
            NotificationCenter.default.publisher(for: LoopFollowAlarmKit.changed)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.viewModel.updateSnapshotData()
                    self.applySnapshot(animatingDifferences: false) { [weak self] in
                        self?.tableView.reloadData() // Authorization is displayed in the section footer.
                    }
                }.store(in: &cancellables)
        }

        // Initial load
        viewModel.updateSnapshotData()
        applySnapshot()
        configureDoneButtonIfNeeded()
    }
}
