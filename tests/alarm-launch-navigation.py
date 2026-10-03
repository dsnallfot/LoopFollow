#!/usr/bin/env python3
"""Exercise the actual alarm launch router without opening the app or firing alarms."""
from pathlib import Path
import os
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
scene = (repo / 'LoopFollow/Application/SceneDelegate.swift').read_text()
router = scene[scene.index('@MainActor enum AlarmLaunchNavigation'):]
start = scene.index('    func scene(_ scene: UIScene, continue userActivity: NSUserActivity)')
end = scene.index('    func sceneWillResignActive', start)
callbacks = scene[start:end]
swift = r'''
import Foundation
let NSUserActivityTypeLiveActivity = "NSUserActivityTypeLiveActivity"
class UIViewController { var dismissals = 0; func dismiss(animated: Bool) { dismissals += 1 } }
class SnoozeViewController: UIViewController {}
class UITabBarController: UIViewController {
    var viewControllers: [UIViewController]? = [UIViewController(), UIViewController(), SnoozeViewController()]
    var selectedIndex = 0
}
class UIWindow { var rootViewController: UIViewController?; var isKeyWindow = true }
class UIScene {
    enum State { case foregroundActive, background }
    var activationState = State.background
}
class UIWindowScene: UIScene { var windows: [UIWindow] = [] }
class UIApplication {
    enum State { case active, inactive, background }
    static let shared = UIApplication()
    var applicationState = State.inactive
    var connectedScenes: [UIScene] = []
}
struct Alarm { enum State { case scheduled, countdown, paused, alerting }; let state: State }
class AlarmManager {
    static let shared = AlarmManager()
    var stored: [Alarm] = []
    var fail = false
    var alarms: [Alarm] { get throws { if fail { throw NSError(domain: "test", code: 1) }; return stored } }
}
class LogManager {
    enum Category { case alarm }
    static let shared = LogManager()
    func log(category: Category, message: String, isDebug: Bool) {}
}
'''
swift += router + '\n@MainActor class TestSceneDelegate { var window: UIWindow?\n' + callbacks + '\n}\n'
swift += r'''
@main struct Tests {
    @MainActor static func main() {
        let tabs = UITabBarController()
        let window = UIWindow(); window.rootViewController = tabs
        let scene = UIWindowScene(); scene.windows = [window]
        let delegate = TestSceneDelegate(); delegate.window = window
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 0 && tabs.dismissals == 0) // Ordinary launch.
        delegate.scene(scene, continue: NSUserActivity(activityType: "unrelated"))
        precondition(tabs.selectedIndex == 0)
        delegate.scene(scene, continue: NSUserActivity(activityType: NSUserActivityTypeLiveActivity))
        precondition(tabs.selectedIndex == 2 && tabs.dismissals == 1)
        tabs.selectedIndex = 0 // Existing background handler restores Home.
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 0) // Request consumed; later normal opens stay Home.
        AlarmLaunchNavigation.requestSnooze() // Intent before a scene is connected.
        AlarmLaunchNavigation.showIfRequested(in: nil)
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 2)
        tabs.selectedIndex = 0
        scene.activationState = .foregroundActive
        UIApplication.shared.connectedScenes = [scene]
        AlarmLaunchNavigation.requestSnooze() // Intent when already active.
        precondition(tabs.selectedIndex == 2)
        // Cold-start activity can select the tab before sceneDidBecomeActive.
        tabs.selectedIndex = 0
        AlarmLaunchNavigation.requestSnooze(in: window)
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 2)
        precondition(tabs.dismissals == 4) // No duplicate navigation on activation.
        // A plain foreground callback now routes without any activity or intent.
        tabs.selectedIndex = 0
        AlarmManager.shared.stored = [.init(state: .alerting)]
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 2)
        // Future/snoozed alarms and an unreadable system state do not route.
        for state in [Alarm.State.scheduled, .countdown, .paused] {
            tabs.selectedIndex = 0
            AlarmManager.shared.stored = [.init(state: state)]
            delegate.sceneDidBecomeActive(scene)
            precondition(tabs.selectedIndex == 0)
        }
        AlarmManager.shared.fail = true
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 0)
        AlarmManager.shared.fail = false
        // Capture while inactive, before watchdog cleanup, and consume on activation.
        UIApplication.shared.connectedScenes = []
        AlarmManager.shared.stored = [.init(state: .alerting)]
        AlarmLaunchNavigation.captureRingingAlarm()
        AlarmManager.shared.stored = []
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 2)
        tabs.selectedIndex = 0
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 0) // No stale request after cleanup.
        // A background-only launch must not leave a navigation request.
        UIApplication.shared.applicationState = .background
        AlarmManager.shared.stored = [.init(state: .alerting)]
        AlarmLaunchNavigation.captureRingingAlarm()
        UIApplication.shared.applicationState = .inactive
        AlarmManager.shared.stored = []
        delegate.sceneDidBecomeActive(scene)
        precondition(tabs.selectedIndex == 0)
        print("Alarm launch navigation passed: ringing, scheduled, paused, cleanup, background launch, read failure,  explicit activity, unrelated activity, normal opens, cold start and deferred intents")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='alarm-navigation-') as directory:
    directory = Path(directory)
    source = directory / 'Tests.swift'
    source.write_text(swift)
    env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(directory / 'modules'))
    binary = directory / 'tests'
    subprocess.run(['swiftc', '-parse-as-library', '-swift-version', '5', str(source), '-o', str(binary)], check=True, env=env)
    subprocess.run([str(binary)], check=True)
