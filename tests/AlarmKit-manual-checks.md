# AlarmKit på fysisk iPhone

Automatiserat: `python3 tests/alarmkit-regressions.py` kör produktionskodens periodval,
snooze-mappning och leveranshantering med en simulerad systemtjänst. Xcode-bygget
kontrollerar integrationen med den riktiga iOS-SDK:n. Ljud och systemets låsskärm
behöver verifieras på fysisk iPhone.

1. Öppna Alarm → AlarmKit inställningar. Kontrollera att AlarmKit är avstängt
   från början och att inga separata AlarmKit-tider visas. Dag/natt ska följa
   ”Nattid startar” och ”Dagtid startar” under Allmänna alarminställningar. Aktivera och ge behörighet.
   Återkalla sedan behörigheten i iOS och kontrollera footer, inställningslänk
   och att nästa larm levereras via det ordinarie flödet.
2. Aktivera AlarmKit för ett larm. Prova Alltid, Aldrig, Dag och Natt med
   tidsgränser strax före/efter nu. Kontrollera även omvänt tidsintervall och
   lika gränser (hela dygnet natt). Ordinarie gränsvärden/händelser gäller alltid.
3. Utlös larmet och lås telefonen. Kontrollera valt CAF-ljud, ljud under Fokus
   och tyst läge samt att ingen vanlig larmnotis eller lokal ljuduppspelning
   samtidigt skapas för samma utlösning. Nästa glukosvärde ska inte stoppa
   ett pågående systemlarm.
4. Kvittera med iOS stoppkontroll. På iOS 26.1+ bestämmer systemet dess text;
   vår stop-intent ska snooza. Kontrollera vanlig standardsnooze i SnoozeStatusView,
   både för ett minutlarm och ett timlarm (t.ex. IOB/sensorbyte).
   Förläng snoozen och verifiera att inget nytt larm kommer under pausen.
5. Sätt både ”Snooza alla larm till” och ”Tysta alla larm till”, var för sig,
   under ett ringande larm. Systemlarmet ska stoppas. När pausen löper ut får
   nästa ordinarie villkorskontroll utlösa ett nytt larm om villkoret kvarstår.
6. Låt ett systemlarm vara aktivt medan appen avslutas. Kvittera på låsskärmen
   och kontrollera snoozen efter omstart. Gamla kvitteringar ska inte påverka
   senare larm av samma typ. Systemets utgångstid räknas inte som kvittering.
7. Kontrollera en loggrad och en historikpost per leverans, med suffix
   ” AlarmKit”, samt AlarmStats typ-tabell och glukosgrafens larmmarkering.

Tillfälligt larm behåller sitt befintliga engångsbeteende och har ingen
standardsnoozetid. AlarmKit-inställningarna omfattar de 16 larmtyper som visas
under `.specificAlarm` i den moderna larmvyn; övriga notisflöden behålls.

## Inaktivitetslarm (BackgroundAlertManager)

- Kontrollera sektionen ”Larm om Loop Follow inaktiveras”, under ”Allmänna
  alarminställningar”. Standard är aktiverat, AlarmKit tillåtet för denna larmtyp,
  Alltid, 12/18 minuter. Global AlarmKit-behörighet gäller fortfarande.
- Ändra första larmet mellan 10–30 minuter i steg om 1 minut. Andra larmet
  ska tillåta första larmets aktuella tid upp till 60 minuter. Höj första tiden
  över den andra och kontrollera att andra tiden och dess nedre gräns följer med.
- Slå av ”Aktiverat”: både notiser och AlarmKit-larm ska avbokas. Slå av enbart
  ”Använd även AlarmKit”, eller välj Aldrig: vanliga notiser ska användas.
- Välj Dag respektive Natt. Perioden beräknas för respektive larms tidpunkt,
  med de globala ”Nattid startar”/”Dagtid startar”-tiderna. Placera dag/natt-gränsen mellan larmtiderna
  och kontrollera att ett går som AlarmKit och det andra som vanlig notis.
- Med bakgrundsuppdatering aktiverad: låt appen vara suspenderad utan nya
  livstecken. Kontrollera larm vid valda tider med rätt minutantal i larmtexten.
  Ingen gammal sexminutersvarning ska finnas kvar.
- Stoppa endast första systemlarmet: det andra ska finnas kvar om appen
  fortfarande är inaktiv. Välj ”Öppna LoopFollow”: båda ska avbokas när appen
  kommer i förgrunden. Nya livstecken i bakgrunden flyttar båda tidsgränserna.
- Utan iOS-behörighet används vanliga notiser. Förväntade långa Bluetooth-
  intervall ska fortfarande filtrera bort för tidiga varningar. Avstängd
  bakgrundsuppdatering ska avboka båda leveranskanalerna.

Automatiserade bakgrundstester: `python3 tests/background-alarmkit-regressions.py`.
