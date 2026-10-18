# Bakgrundsåterhämtning efter systemavslut

Automatiska värdtester kör produktionskoden med ersättningar för systemtjänster:

- `python3 tests/background-alarmkit-regressions.py`: långsam/blockerad notisstädning, kanalbyte, fel i båda kanalerna, delvis accepterad plan, avbruten schemaläggning, bevarade larm vid ny instans och sena svar efter stopp.
- `python3 tests/bluetooth-restoration.py`: väntande/ansluten periferienhet, delegate, återställd prenumeration, saknade services, Bluetooth-reset, filtrerad scanning och samma anslutningsägare vid upprepade poweredOn-händelser.
- `python3 tests/task-scheduler-recovery.py`: kallstart utan scen, återställning av tasks och utebliven förnyelse vid misslyckad återställning.

Dessa tester verifierar inte iOS faktiska radioväckning eller systemleverans av larm.

## Fysisk telefon

Använd Daniels iPhone 15 med befintligt sensorval. Bekräfta aktuell bundle ID/signering innan installation så att rätt LoopFollow-installation uppdateras och dess data behålls. Kör utan kvarhängande debugger under bakgrundsmätningen.

1. Starta appen. Kontrollera `App started; pid=...` och `Launch bootstrap completed; monitoring recovery requested`, följt av lyckad taskåterställning.
2. Lägg appen i bakgrunden och lås telefonen. Följ minst tre Dexcom-cykler (cirka 15 minuter). Kontrollera Bluetooth-ping och att datahämtning/alarmkontroll fortsätter.
3. Testa CoreBluetooth state restoration via en kontrollerad processavslutning i utvecklarmiljö. Att svepa bort appen är inte ett likvärdigt systemavslutstest. Avsluta debugsessionen innan nästa sensorkontakt. Kontrollera ny process, `BLE restoration: adopted selected peripheral, state=...`, taskåterställning och efterföljande ping utan manuell öppning.
4. Upprepa med väntande anslutning och, om möjligt, under den korta anslutna perioden. Ingen femsekunders-timer ska avbryta den väntande anslutningen; redan ansluten enhet ska återuppta discovery/prenumerationer.
5. Prova tillfälligt förlorad sensorkontakt/Bluetooth-reset och återkomst. Kontrollera att vald sensor är oförändrad och att ping återkommer.
6. Verifiera reservlarmens båda tidsgränser och att öppning av appen stoppar dem. Stopp av första larmet ska lämna andra eskaleringen kvar. Förnya en plan och kontrollera att gamla larm försvinner efter accepterad ersättning.
7. Spara loggar, exakta lokala tider, byggidentifierare och eventuell `.ips`-rapport. Dokumentera separat vad som verkligen testats och vad som återstår.

## Tolkning av fel

En ny process i sig förnyar inte reservlarmen. Förnyelse begärs först när övervakningens tasks har återställts. Systemanrop för notisstädning och AlarmKit-avbokning körs på separat kö. Vid misslyckat byte behålls befintligt skydd och eventuella accepterade delar av den nya planen. Avbrott kan därför lämna överlappande larm tills nästa lyckade uppdatering; detta prioriterar bevarat skydd framför tystnad.

`bluetoothRestore=false` i äldre loggar är inte ett tillförlitligt sätt att utesluta Bluetooth-återstart på iOS 26+, där launch-option-nyckeln är föråldrad. Använd centralens återställningscallback och process-ID för korrelation.
