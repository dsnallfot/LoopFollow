# Remote command / Nightscout reminder

## Automated checks

Run from the repository root (macOS):

```sh
swiftc -module-cache-path /tmp/remote-receipt-module-cache \
  LoopFollow/Remote/TRC/TRCCommandType.swift \
  LoopFollow/Remote/PushMessage.swift \
  LoopFollow/Remote/RemoteCommandReceiptTracker.swift \
  tests/remote-command-receipts.swift -o /tmp/remote-receipts
/tmp/remote-receipts
```

## UI checks with fixtures / a non-treatment test setup

- Inspect `RemoteCommandPendingBanner_Previews`: normal and expired states, light/dark mode,
  narrow screen and large text. Preview data does not send a push or contact Nightscout.
- Show an outstanding command and navigate through TrioRemoteControlView, ManualGlucoseView,
  ComboView and its editor sheet, TempTargetView, MealView, BolusView and OverrideView.
  The red banner should stay above the form/list; send/activate/cancel-command controls are disabled while input fields and Avfärda remain usable.
- Inject matching treatment fixtures: the warning disappears on a fresh Nightscout fetch.
  For a meal/bolus/combo, every requested part must be observed. Parts may arrive separately.
- Inject a fingerstick while a combo is outstanding: the combo warning must remain.
- At 0:29 no dismiss button; at 0:30 it appears without navigation or a network response.
  Dismissing one old warning does not dismiss newer warnings or cancel/resend any command.
- Reopening a view keeps the warning. Terminating/relaunching the app clears it (in-memory by design).

## Matching boundaries

This is an observational reminder, not a protocol acknowledgement. It uses only fresh successful,
uncapped treatment responses from the existing Nightscout downloader. Cached data is not a receipt.
New sends are blocked while any command is pending, including confirmations opened before the warning.
No extra network polling, automatic retries or Trio changes are introduced.
Treatment downloading must be enabled for automatic clearing.

Matching uses type, timestamp, requested quantities and sender/notes where Trio supplies them.
Glucose and temporary targets lack the remote sender in Trio's uploads; their time/value and Trio
origin are used. There is no globally unique command ID in these treatments, so indistinguishable
concurrent registrations cannot be reliably attributed. This feature assumes coordinated senders.

Each outstanding command captures the already observed treatments to exclude preexisting records,
including backdated entries. An individual treatment/component is used at most once per session.
Cancellation requires a previously observed active run to reappear with a shortened duration ending
near the command time. Without that baseline, the warning stays for manual dismissal.
Deletion commands retain the selected Nightscout row (or a unique already observed matching row).
They clear only when a successful, uncapped network snapshot covering that row's date no longer
contains it. Local optimistic deletion, cache reads, failed fetches, malformed responses and fetches
started before the send cannot clear it. A replacement row at the same treatment time also keeps
it pending. With no known target or no complete fetch covering its date, manual dismissal remains available.
Strict matches may leave a warning if a pump rounds a bolus or Nightscout transforms treatment data.

Tracking begins immediately before the HTTP task starts, covering the time before APNs responds.
An explicit HTTP rejection removes only that send. Transport errors keep the warning because the
request might already have reached APNs. Dismissal never means a treatment failed or was cancelled.

## Treatment deletion override

- With a pending send, swipe a meal or fingerstick and select Trio & Nightscout.
  After the destination alert closes, expect Remote kommando pågår with a red Skicka ändå and Avbryt.
- Avbryt must leave the row and pending commands unchanged, with no send.
- Skicka ändå must dismiss the warned-about commands even before 30 seconds, then run the
  normal remote deletion flow. A failed send still restores the locally removed row.
- With no pending command, no additional warning is shown. Endast Nightscout is unchanged.
- Run `python3 tests/remote-deletion-confirmation.py` for the production helper's decision tests.

## Deletion receipts

Compile `tests/remote-deletion-receipts.swift` with the same production files as the receipt tests.
It covers meals and fingersticks, full/partial/wrong-window snapshots, changed/replaced IDs,
unknown or ambiguous targets, and preservation of pending registrations.

With test data, delete a meal/fingerstick via Trio & Nightscout. The optimistic local row removal
must leave the warning in place. A fresh server response still containing the row must also leave
it in place; once the row disappears from a full response covering that date, the warning and send
block should clear. Test an older selected day too, using a fresh day fetch rather than cached rows.

## Trio history limit

- Swipe a meal/fingerstick younger than 23 h 55 min: the existing Trio & Nightscout choice remains.
- At 23 h 55 min or older: only the normal Nightscout deletion confirmation is shown,
  including "OBS! Detta raderar INTE något i Trio". Cancelling must leave the row intact.
- Check both TRC and SMS meal deletion. Age is evaluated when tapping the swipe action,
  so a row left on screen does not retain an outdated Trio option.
- Verify older bolus/other treatments still use the same Nightscout-only flow.
