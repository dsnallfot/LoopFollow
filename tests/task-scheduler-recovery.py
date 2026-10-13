#!/usr/bin/env python3
"""Execute the production scheduler and controller owner with fake UIKit/data tasks.
No network, real alarms, device settings, or installed apps are touched.
"""
from pathlib import Path
import os
import plistlib
import xml.etree.ElementTree as ET
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
# The retained owner requires the real storyboard hierarchy and explicit scene setup.
# Check the resources too, since host-side UIKit fakes cannot load an iOS storyboard.
info = plistlib.loads((repo / 'LoopFollow/Info.plist').read_bytes())
assert 'UIMainStoryboardFile' not in info
for configs in info['UIApplicationSceneManifest']['UISceneConfigurations'].values():
    assert all('UISceneStoryboardFile' not in config for config in configs)
board = ET.parse(repo / 'LoopFollow/Application/Base.lproj/Main.storyboard').getroot()
root = board.find(".//tabBarController[@id='" + board.attrib['initialViewController'] + "']")
assert root is not None
children = [link.attrib['destination'] for link in root.findall("./connections/segue[@relationship='viewControllers']")]
assert board.find(".//viewController[@id='" + children[0] + "']").attrib['customClass'] == 'MainViewController'
assert board.find(".//viewController[@id='" + children[2] + "']").attrib['customClass'] == 'SnoozeViewController'
scheduler = (repo / 'LoopFollow/Task/TaskScheduler.swift').read_text()
owner = (repo / 'LoopFollow/Controllers/ViewControllerManager.swift').read_text().replace('import UIKit\n', '')
stubs = r'''
import Foundation
protocol AlarmUIRefreshing {}
class ModernAlarmViewController: AlarmUIRefreshing {}
class UIViewController {
    var isViewLoaded = false
    func loadViewIfNeeded() { isViewLoaded = true }
}
class UITabBarController: UIViewController {
    var viewControllers: [UIViewController]? = [MainViewController()]
}
class UIStoryboard {
    static var creations = 0
    init(name: String, bundle: Bundle?) {}
    func instantiateInitialViewController() -> UIViewController? {
        Self.creations += 1
        return UITabBarController()
    }
}
class MainViewController: UIViewController {
    static var loads = 0
    static var registrations = 0
    static var fail = false
    static var ranAlarm = 0
    override func loadViewIfNeeded() {
        guard !isViewLoaded else { return }
        super.loadViewIfNeeded()
        Self.loads += 1
        scheduleAllTasks()
    }
    func scheduleAllTasks(only ids: Set<TaskID> = Set(TaskID.allCases)) {
        guard !Self.fail else { return }
        for id in ids {
            Self.registrations += 1
            TaskScheduler.shared.scheduleTask(id: id, nextRun: Date().addingTimeInterval(3600)) {
                if id == .alarmCheck { Self.ranAlarm += 1 }
                TaskScheduler.shared.rescheduleTask(id: id, to: Date().addingTimeInterval(3600))
            }
        }
    }
}
class LogManager {
    enum Category { case taskScheduler }
    static let shared = LogManager()
    func log(category: Category, message: String, isDebug: Bool = false, isTempDebug: Bool = false) {}
}
@MainActor class BackgroundAlertManager {
    static let shared = BackgroundAlertManager()
    var renewals = 0
    func startBackgroundAlert() { renewals += 1 }
    func scheduleBackgroundAlert() { renewals += 1 }
}
extension TaskScheduler {
    func snapshot() async -> [TaskID: Date] {
        await withCheckedContinuation { c in
            queue.async { c.resume(returning: self.tasks.mapValues(\.nextRun)) }
        }
    }
    func removeForTest(_ ids: Set<TaskID>) async {
        await withCheckedContinuation { c in
            queue.async {
                self.currentTimer?.cancel(); self.currentTimer = nil
                for id in ids { self.tasks.removeValue(forKey: id) }
                c.resume()
            }
        }
    }
}
@main struct RecoveryTests {
    @MainActor static func settle() async {
        try! await Task.sleep(nanoseconds: 150_000_000)
    }
    @MainActor static func main() async {
        let scheduler = TaskScheduler.shared
        let owner = ViewControllerManager.shared
        // Cold background launch: no scene and no pre-existing view/controller.
        for _ in 0..<40 { scheduler.checkTasksNow() }
        await settle()
        let initial = await scheduler.snapshot()
        precondition(initial.count == TaskID.allCases.count)
        precondition(UIStoryboard.creations == 1 && MainViewController.loads == 1)
        precondition(MainViewController.registrations == TaskID.allCases.count)
        // A later scene must adopt the same retained hierarchy and task owner.
        let root = owner.monitoringRootController()!
        precondition(root === owner.monitoringRootController()!)
        precondition(MainViewController.loads == 1)
        for _ in 0..<20 { scheduler.checkTasksNow() }
        await settle()
        let unchanged = await scheduler.snapshot()
        precondition(unchanged == initial, "Healthy wakes changed task deadlines")
        // Repair a missing alarm task without disturbing an in-flight fetch or its action.
        scheduler.rescheduleTask(id: .fetchBG, to: .distantFuture)
        await settle()
        await scheduler.removeForTest([.alarmCheck])
        scheduler.checkTasksNow()
        await settle()
        let repaired = await scheduler.snapshot()
        precondition(repaired.count == TaskID.allCases.count)
        precondition(repaired[.fetchBG] == .distantFuture)
        precondition(repaired[.profile] == initial[.profile])
        precondition(MainViewController.registrations == TaskID.allCases.count + 1)
        // Execute the recovered alarm action through the real scheduler.
        scheduler.rescheduleTask(id: .fetchBG, to: Date().addingTimeInterval(3600))
        scheduler.rescheduleTask(id: .alarmCheck, to: Date().addingTimeInterval(-1))
        await settle()
        precondition(MainViewController.ranAlarm == 1)
        // Failed recovery neither renews the watchdog nor enters a hot retry loop.
        await scheduler.removeForTest(Set(TaskID.allCases))
        await settle()
        MainViewController.fail = true
        let watchdogBefore = BackgroundAlertManager.shared.renewals
        for _ in 0..<40 { scheduler.checkTasksNow() }
        await settle()
        let failed = await scheduler.snapshot()
        precondition(failed.isEmpty)
        precondition(BackgroundAlertManager.shared.renewals == watchdogBefore)
        // The next heartbeat retries and recovers using the same retained owner.
        MainViewController.fail = false
        scheduler.checkTasksNow()
        await settle()
        let retried = await scheduler.snapshot()
        precondition(retried.count == TaskID.allCases.count)
        precondition(BackgroundAlertManager.shared.renewals > watchdogBefore)
        precondition(UIStoryboard.creations == 1 && MainViewController.loads == 1)
        print("PASS: cold launch, concurrent wakes, retained scene owner, partial recovery, alarm execution, failed recovery/watchdog, retry")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='lf-recovery-') as tmp:
    source = Path(tmp) / 'RecoveryTests.swift'
    source.write_text(scheduler + '\n' + owner + '\n' + stubs)
    executable = Path(tmp) / 'tests'
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(Path(tmp) / 'modules'))
    subprocess.run(['swiftc', '-swift-version', '5', '-parse-as-library', str(source), '-o', str(executable)], check=True, env=env)
    subprocess.run([str(executable)], check=True, env=env)
