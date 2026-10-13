//
//  ViewControllerManager.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-27.

//

import Foundation
import UIKit

class ViewControllerManager {

    static let shared = ViewControllerManager()

    var alarmViewController: AlarmUIRefreshing?

    // The task actions currently live on MainViewController. Keep its entire storyboard
    // hierarchy alive even when CoreBluetooth launches us without a connected scene.
    // SceneDelegate adopts this same hierarchy later; never create a second task owner.
    private var monitoringRoot: UITabBarController?

    func monitoringRootController() -> UITabBarController? {
        dispatchPrecondition(condition: .onQueue(.main))
        if let monitoringRoot { return monitoringRoot }
        guard let root = UIStoryboard(name: "Main", bundle: nil)
            .instantiateInitialViewController() as? UITabBarController else {
            LogManager.shared.log(category: .taskScheduler, message: "Recovery failed: Main storyboard has no tab controller")
            return nil
        }
        monitoringRoot = root
        return root
    }

    func restoreMonitoringTasks(missing: Set<TaskID>) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard let root = monitoringRootController(),
              let main = root.viewControllers?.compactMap({ $0 as? MainViewController }).first else {
            LogManager.shared.log(category: .taskScheduler, message: "Recovery failed: MainViewController unavailable; retry on next wake")
            return
        }
        let wasLoaded = main.isViewLoaded
        main.loadViewIfNeeded()
        // viewDidLoad registers every task on first load. For a partial loss, repair only
        // missing tasks so existing deadlines and in-flight requests remain untouched.
        if wasLoaded { main.scheduleAllTasks(only: missing) }
    }

    private init() {
        alarmViewController = ModernAlarmViewController()
    }
}
