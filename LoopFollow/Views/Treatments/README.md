# Treatments

The treatment log keeps its existing `TreatmentsTableView` entry point and behavior.
The controller is split into extensions by responsibility; all extensions operate on
the same controller instance and state. Category search uses a background store with
an in-memory index of cached treatments; it never fetches Nightscout history.

| File / folder | Responsibility |
| --- | --- |
| `TreatmentsTableView.swift` | Stored state, lifecycle and notification registration |
| `Models/Treatment.swift` | Nightscout treatment parsing and model |
| `Models/TreatmentSearchIndex.swift` | Shared categories, aliases, index and background search/page preparation |
| `+Search` | Submitted category search, result pagination, cache updates and scroll restoration |
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

Keep changes in the file responsible for that behavior. Search has a separate section snapshot from normal day browsing. Its page size is
100 rows. Search callbacks are generation-checked so clearing or replacing a query
cannot restore stale results. `NightscoutCache.writeDay` invalidates the index only
when treatments change; SGV-only writes do not rebuild it. First search decodes only
treatments, with glucose loaded later for meal rows in each displayed page.

The search covers `NightscoutCache.retentionDays` local calendar days, including
today, regardless of the date picker. It follows the existing segment rules and
reports missing/unreadable files, but cannot establish whether a cached day contains
complete remote history. Search aliases are category names, not note/food contents.
