# Meal Analysis

`MealAnalysisView` remains the UIKit entry point, with the same initializer,
delegates and `carryOverUndeliveredBasals` option. The controller is split into
extensions that share the original instance and state.

| Location | Responsibility |
| --- | --- |
| `MealAnalysisView.swift` | Stored state, initialization, lifecycle and startup order |
| `Models/` | Event/glucose models and navigation delegate protocols |
| `TimeWindow/` | Initial window, picker setup and duration/start/end changes |
| `Navigation/` | Toolbar, day/week navigation and EnteredBy integration |
| `Layout/` | View hierarchy, range bars, row builders, font helper and date-sync overlay |
| `Analysis/` | Insulin/carbohydrate totals, scheduled basal integration and glucose summaries |
| `Data/` | Live glucose requests, glucose merging/gap filling and cache integration |
| `Charts/` | Chart setup, axis formatting, selection popup and rendering |

`viewDidLoad` calls extracted setup methods in the original order. Stored UIKit
controls remain on the controller, and the existing layout, selectors, date rules,
calculation formulas, network/cache behavior and callback order are preserved.
Existing comments and unused paths remain.

Members shared across files use module-internal access because Swift's `private`
access does not cross source-file boundaries. Helpers used in only one file stay
private. No additional controller, observation system or service layer is introduced.

All Swift files are registered once in the LoopFollow app target. This README is
visible in Xcode as documentation and is not bundled into the app.
