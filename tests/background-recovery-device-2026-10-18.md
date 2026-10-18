# Fysisk verifiering 2026-10-18

Enhet: Daniels iPhone 15. Befintlig installation uppdaterades med samma bundle-ID
`com.RMSRR5SURS.LoopFollow`, version 27.0/build 1, signerad med befintligt utvecklingsteam.
Ingen avinstallation eller återställning av appdata. Signerad Xcode Debug-byggning lyckades.
Testet använde arbetskopians ändringar för bakgrundslarm och Bluetooth-återställning.

Alla tider nedan är Europe/Stockholm (UTC+02:00).

| Tid | Observation |
| --- | --- |
| 10:54:18 | Uppdaterad app startad via devicectl, PID 38183. Launch bootstrap färdig och samtliga 12 tasks återställda samma sekund. |
| 10:54:18 | `BLE restoration: adopted selected peripheral, state=1` — väntande anslutning. |
| Före 10:54:39 | Användaren låste telefonen. CoreDevice bekräftade `passcodeRequired: true`. |
| 10:54:39 | Bluetooth-heartbeat via `didDisconnectPeripheral`. |
| Cirka 10:55:26 | Kontrollerad SIGKILL av endast PID 38183 via devicectl. Efterföljande processlista bekräftade att LoopFollow inte körde. |
| 10:59:23 | Automatisk bakgrundsstart, ny PID 38202. Ingen manuell launch efter SIGKILL och ingen debugger ansluten. |
| 10:59:23 | Launch bootstrap färdig; 12 tasks återställda. `BLE restoration: adopted selected peripheral, state=2` — redan ansluten enhet. |
| 10:59:34 | Första heartbeat i den automatiskt återstartade processen. |
| 10:59 | Nightscout-cachefiler fick nya modifieringstider efter återstarten. Detta visar fortsatt cachearbete, inte en separat kontroll av varje hämtat värdes aktualitet. |
| 11:04:20 | PID 38202 fortfarande kvar. |
| 11:04:35 | Nästa Bluetooth-heartbeat. Telefonen fortsatt låst vid slutkontrollen. |

## Reservlarm

De sparade preferenserna innehöll två ägda reservnotis-ID:n efter processavslutningen.
Efter automatisk återstart fanns två nya ID:n, vilket visar att appens plan hade
förnyats. Inga ägda AlarmKit-ID:n fanns i dessa ögonblick; den aktiva planen använde
vanliga notiser. Detta är verifiering av sparad plan/ägarskap, inte direkt inspektion
av systemets notiskö eller verifiering av ljudleverans.

## Resultat och begränsningar

Verifierat på fysisk telefon: väntande och redan ansluten BLE-restoration,
automatisk återstart efter kontrollerat processavslut, återställning av samtliga
tasks och fortsatt heartbeat i följande sensorcykel. Appen lämnades körande i
bakgrunden, utan debugger eller kvarvarande testprocess.

Inte återskapat: nattens SpringBoard/minnesstörning eller verkligt blockerad
systemnotistjänst på telefonen. Långsam tjänst, fel i båda larmkanalerna,
delvis accepterade planer och avbruten schemaläggning täcks av värdtesterna.
AlarmKit-ljud, reservnotisernas faktiska leverans och längre nattdrift är inte
verifierade av detta fysiska test. SIGKILL-testet är inte identiskt med jetsam,
watchdog-avslut eller att användaren sveper bort appen.

Råloggar lästes till lokala temporära filer; inga fullständiga hälso-/nätverksloggar
läggs in i projektet med denna rapport.
