# Glucose

Glukoslogg och statistik för Dexcomvärden, Trio → Nightscout-uppladdningar och sensorfel.

## Struktur

- `Log/`: `GlucoseView` äger tillstånd, UIKit-komponenter och livscykel. Extensions hanterar layout, navigering, uppdatering/backfill, dataladdning, rader, filtrering, dagssammanfattning och Trio-beslutsdialogen.
- `Statistics/`: `GlucoseStatsViewController` med tillstånd, livscykel och table view-overrides. Separata filer hanterar laddning, dagsräkning, periodval, diagramlayout, glukosdiagram och statistikberäkningar.
- `SensorErrors/`: loggens sensorfelscache, Dexcom-noteringar och dialoger samt statistikvyns avbrottsberäkningar och sensorfelsdiagram. Filnamnens klassprefix visar vilken vy koden tillhör.
- `Models/`: respektive vys nästlade radmodeller, visningslägen och periodval.
- `Helpers/`: formatering av Trio-beslutstext.

Uppdelningen behåller klassnamn, beräkningar, datakällor, cache-nycklar, asynkrona anrop och UI-beteenden. Skillnaderna mellan Dexcom- och Trio-data, exempelvis tidsintervall för deduplicering, är bevarade. Befintliga hjälpare och kommentarer finns kvar.

Medlemmar som används av samma klass i flera filer har intern åtkomst. Övriga privata medlemmar behåller sin åtkomstnivå. Lagrat tillstånd och UIKit-overrides finns i huvudklasserna.

Alla Swift-filer ingår i appens Sources i Xcode. README visas i projektet utan att byggas in som resurs.
