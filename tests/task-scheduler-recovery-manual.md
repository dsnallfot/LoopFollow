# Silent relaunch regression checks

Run `python3 tests/task-scheduler-recovery.py` for executable coordinator regressions.
Build the iOS app as well: the host test replaces UIKit and task bodies with fakes.

Use a test installation and test Nightscout data. Do not rely on the test device for
live glucose alerts during this procedure.

1. Cold foreground launch: all tabs and graphs work, data arrives, alarms can trigger.
2. On a physical development/test iPhone, enable Settings > Developer > Fast App
   Termination (if available). Launch the app normally, establish the selected BLE
   heartbeat connection, then background it and lock the phone without swiping it away.
   This developer option terminates backgrounded apps to help test restoration.
   Wait for the peripheral's next actual Bluetooth event; do not manually reopen the
   app before checking for background activity. Disable Fast App Termination after
   the test; it changes background behavior for other apps too.
   If the option is unavailable, observe a system-initiated termination instead.
   Ordinary suspension keeps the process in memory and does not exercise cold recovery.
   A simulator cannot validate this Bluetooth wake path.
3. Verify logs show `App started; ... bluetoothRestore=true`, `Recovering missing
   tasks`, then `Task recovery succeeded: 12 tasks registered`, without opening UI.
   The recovery messages can race with scene creation on a foreground launch, where
   viewDidLoad may have already registered tasks; they are not required in that case.
4. Verify fresh glucose and a test alarm while the phone remains locked. More than
   merely the recovery-success message is required: that message proves registration,
   not network success or actual alarm delivery.
5. Open the app. Verify `UI scene attached to shared monitoring controller`, preserved
   fresh readings/snooze state, functioning tabs, and no duplicate test alarm.
6. Repeat background/foreground and several BLE heartbeats. Recovery should not recur
   during healthy operation. Existing snoozes and task deadlines must remain intact.
7. With background alerts enabled, stop BLE heartbeats and verify the configured
   inactivity alerts still fire. Confirm silent-audio background refresh still works.

The automated tests additionally inject partial task loss and recovery failure:
existing task deadlines/in-flight state survive, a failed recovery does not renew
background alerts, and the next wake retries successfully. This patch handles missing
registrations after relaunch; it does not claim to detect every hung network request
or a blocked main thread. iOS must grant execution time for any recovery to run.

Apple references:
- [TN3115: Bluetooth State Restoration app relaunch rules](https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules)
- [Apple DTS: Fast App Termination for testing Bluetooth restoration](https://developer.apple.com/forums/thread/840468)

For the current CoreBluetooth implementation, swiping away the app is not a valid
simulation of system termination. Apple's iOS 26+ AccessorySetupKit exception does
not apply to this app's current accessory setup.
