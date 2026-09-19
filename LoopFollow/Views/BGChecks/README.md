# BGChecks

Logg och statistik för fingerstick (BG Check) och dextrobehandlingar.

## Struktur

- `Models/`: loggposter, CGM-punkter och loggens visningslägen.
- `Log/`: `BGCheckView` med tillstånd och livscykel. Extensions hanterar layout, datum-/lägesnavigering, cacheladdning, tabellrader och presentation av statistik.
- `FingerstickStats/`: `BGCheckStatsViewController`, periodval, filtrering, diagramlayout, antal-/tidsdiagram och statistikberäkningar.
- `LowTreatmentStats/`: `LowTreatmentsStatsViewController`, period-/dygnsfilter, diagramlayout, stapel-/jämförelse-/tidsdiagram och statistikberäkningar.
- `LowTreatmentStats/Charts/`: datumaxelformatering och markör för jämförelsediagrammet.

Huvudklasserna äger lagrat tillstånd, UIKit-komponenter, initialisering och livscykel. Statistikvyerna behåller även sina table view-overrides där. Logik som hör till samma klass ligger i namngivna extensions. Medlemmar som behöver användas mellan dessa filer har intern åtkomst; övriga privata medlemmar behåller sin åtkomstnivå.

Uppdelningen behåller befintliga klassnamn, anropsordning, beräkningar, tidsfönster, enhetskonverteringar och UI-beteenden. Fingerstick och dextro har avsiktligt kvar sina respektive regler och standardval.

Alla Swift-filer ingår i appens Sources i Xcode. Den här README-filen visas i projektet men byggs inte in som en resurs.
