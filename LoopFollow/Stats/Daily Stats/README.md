# Daily Stats

`DailyStatsView` remains the screen's entry point. It observes the same
`DailyStatsViewModel` and owns the existing sheet, report, summary and chart state.
Subview bindings update that state; no additional view model or observation system
has been introduced.

| Location | Responsibility |
| --- | --- |
| `DailyStatsView.swift` | Screen composition, presentation state and sheets |
| `DailyStatsView+Toolbar.swift` | Toolbar, initial loading and CSV sharing action |
| `Views/` | Daily table and cells, averages, target summary, database details, weekday filters and share sheet |
| `Charts/` | Chart selection, carbs/TDD bars, real insulin ratio and TITR/TIR chart, markers and axis formatters |
| `Models/` | Daily rows, read-only presentation inputs and the existing data-service placeholder |
| `ViewModel/` | Observable state, filtering, summaries, daily calculations and CSV export |
| `Reports/` | Loop Follow report presentation and Nightscout web reports |
| `Clippy/` | Target history, history statistics and their chart configuration |

The table, summary, averages and chart sections are separate SwiftUI view types.
They receive explicit values, bindings and callbacks. Presentation inputs copy
values from the existing model; thresholds, filtering and statistics calculations
remain in the view model.

Extensions share the same owning instance. Members needed across files use
module-internal access because Swift's `private` access does not cross file
boundaries. File-local helpers remain private. Existing unused code and commented
alternatives are retained as part of this structural refactor.

All files, including this README, are referenced by the Xcode project. Swift files
are compiled by the existing LoopFollow app target; the README is documentation only.
