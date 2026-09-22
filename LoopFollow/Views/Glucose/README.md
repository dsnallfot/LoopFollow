# Glucose

Glukoslogg och statistik för alla glukosvärden, uppladdningar i realtid och sensorfel.

`trioSentAt` följer med från Nightscout till cachen. Mer än 60 sekunder mellan avläsning och uppladdning räknas som försenat; exakt 60 sekunder och äldre värden utan tidsstämpel räknas som realtid. Försenade värden visas med blå bakgrund och uppladdningstiden inom parentes och inkluderas i loggens filter. Ingen separat förseningsflagga sparas på disk.

Båda statistikserierna utgår från alla glukosvärden med befintlig deduplicering. Realtidsserien utesluter försenade värden. Nightscout-cachen används även för att komplettera uppladdningstider på Dexcom-värden. Sensorfelsgrafen och dess beräkningar behålls.

## Struktur

- `Log/`: `GlucoseView` äger tillstånd, UIKit-komponenter och livscykel. Extensions hanterar layout, navigering, uppdatering/backfill, dataladdning, rader, filtrering, dagssammanfattning och Trio-beslutsdialogen.
- `Statistics/`: `GlucoseStatsViewController` med tillstånd, livscykel och table view-overrides. Separata filer hanterar laddning, dagsräkning, periodval, diagramlayout, glukosdiagram och statistikberäkningar.
- `SensorErrors/`: loggens sensorfelscache, Dexcom-noteringar och dialoger samt statistikvyns avbrottsberäkningar och sensorfelsdiagram. Filnamnens klassprefix visar vilken vy koden tillhör.
- `Models/`: respektive vys nästlade radmodeller, visningslägen och periodval.
- `Helpers/`: formatering av Trio-beslutstext.

Cache-nycklar och historiska cachefiler behålls; `trioSentAt` är optional för bakåtkompatibilitet.

Medlemmar som används av samma klass i flera filer har intern åtkomst. Övriga privata medlemmar behåller sin åtkomstnivå. Lagrat tillstånd och UIKit-overrides finns i huvudklasserna.

Alla Swift-filer ingår i appens Sources i Xcode. README visas i projektet utan att byggas in som resurs.
