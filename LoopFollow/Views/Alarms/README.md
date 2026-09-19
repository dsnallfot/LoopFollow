# Alarms

Inställningsvyn för larm, översikten över aktiva larm och deras view model.

## Struktur

- `Active/`: `ActiveAlarmsViewController` med livscykel och layout, separata filer för radbyggande och tabellens visning/knappar.
- `Modern/`: `ModernAlarmViewController` med tillstånd och livscykel. Extensions hanterar kategorival, layout, datakälla, tabellrubriker, navigation, datumväljare och externa uppdateringar av snooze/mute.
- `Models/`: modeller för aktiva larm och protokollet `AlarmUIRefreshing`.
- `ViewModel/ModernAlarmViewModel.swift`: `AlarmViewModel` med kategorier, urval, sektioner och val av vilka rader som ska visas.
- `ViewModel/Rows/`: radbyggande för lågt/högt glukos, trend, Trio, hårdvara, behandlingsrelaterade larm samt allmänna/nattinställningar.
- `ViewModel/Updates/`: ändringar av av/på-värden, numeriska värden, ljud/alternativ och datum.

Klassnamn, rad-ID:n, lagringsnycklar, gränsvärden, texter och anropsordning är bevarade. Radbyggare som tidigare låg som lokala funktioner i `rows(for:)` är nu metoder i extensions med samma funktionskroppar. Tillstånd och UIKit-livscykel stannar i huvudklasserna. Medlemmar som används mellan filer har intern åtkomst; övriga privata medlemmar behåller sin åtkomstnivå.

Alla Swift-filer ingår i appens Sources. README visas i Xcode utan att byggas in som resurs. Övriga larmkomponenter utanför dessa tre ursprungsfiler ligger kvar på sina befintliga platser.
