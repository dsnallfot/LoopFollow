# Treatments

The treatment log keeps its existing `TreatmentsTableView` entry point and behavior.
The controller is split into extensions by responsibility; all extensions operate on
the same controller instance and state. No new service or view-model layer is introduced.

| File / folder | Responsibility |
| --- | --- |
| `TreatmentsTableView.swift` | Stored state, lifecycle and notification registration |
| `Models/Treatment.swift` | Nightscout treatment parsing and model |
| `Views/` | Table cell and the note / glucose editing screens |
| `+Layout` | Navigation bar, filter control, constraints and date-sync overlay |
| `+DaySections` | Day sections, filtering, pagination, date selection and scrolling |
| `+Loading` | Cache-backed loading and dynamic Nightscout requests |
| `+Refresh` | Refresh actions, backfill and duplicate indicator |
| `+Cache` | Local deletion / restoration and rolling-window cache updates |
| `+TableDataSource` | Table sections, headers and cell rendering |
| `+SwipeActions` | Swipe menus for deletion and editing |
| `+Details` | Row selection, detail alerts and deselection |
| `+Editing` | Presenting editors and saving edited treatments |
| `+RemoteDeletion` | Trio deletion commands, authentication and Shortcuts callbacks |
| `+MealAnalysis` | Event conversion and navigation to / from meal analysis |
| `Helpers/+Formatting` | Text previews, number formatting, event symbols and reason formatting |
| `Helpers/+Glucose` | Glucose lookup and meal-status calculation |

`+Name` above means `TreatmentsTableView+Name.swift`.

Swift's `private` access does not cross source-file boundaries, even for extensions
of the same type. State and methods shared by these extensions therefore use
module-internal access; helpers used in only one file remain private. Stored
properties stay in the main class because extensions cannot declare stored state.
The text-field padding helpers stay file-private beside the glucose editor.

Keep changes in the file responsible for that behavior. The original code,
including currently unused paths and commented-out alternatives, is retained so
this remains a structural refactor.
