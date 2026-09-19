# Profile Schedules

`ProfileSchedulesView` and `ProfileSchedulesViewModel` remain the public entry
points for this feature. The screen keeps the existing observation ownership,
selected mode, sheet state, alerts and import/export presentation.

| Location | Responsibility |
| --- | --- |
| `ProfileSchedulesView.swift` | Screen composition, mode selection and presentation |
| `ProfileSchedulesView+Toolbar.swift` | Mode-specific toolbar actions |
| `Schedules/` | Schedule table, section headers and conversion to chart points |
| `HealthData/` | Health-data history, profile rows, statistics and CSV document/import/export |
| `HealthData/Editor/` | Entry editor, bound input fields, Walsh comparison display, calculations, autofill and saving |
| `SickDays/` | Sick-day list, entry form and calendar |
| `Training/` | Session list, entry form, statistics and bar chart |
| `Navigation/` | Meal-analysis presentation and the settings-log bridge |
| `Models/` | Schedule/training entries, selection enums, log search, profile identity/notification and schedule display data |
| `Persistence/` | Existing profile-image storage and last-changed date storage |
| `ViewModel/` | Observable state, loading, schedule calculations, sick days, training sessions and change history |

The schedule content, sick-day list and health-data form sections are dedicated
SwiftUI views with explicit values, bindings and callbacks. `ProfileScheduleData`
is a read-only snapshot of the existing model's displayed values. Calculation
formulas, thresholds, date handling, network requests, storage keys and notification
names are preserved.

Extensions operate on the same owning instance. Members used across files are
module-internal because Swift's `private` access does not cross source-file
boundaries; helpers used in only one file stay private. State remains in its
original owning view or model. Existing comments and unused paths are retained.

All Swift files are registered once in the LoopFollow app target. This README is
visible in Xcode as documentation and is not bundled into the app.
