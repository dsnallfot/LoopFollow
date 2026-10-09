# Hälsologgning – kontroll på telefon

Öppna Trio fjärrstyrning → Hälsologgning. Knappen ska öppna formuläret i Loop Follow.

Använd en separat delad testlista för påminnelsekontrollen:

1. Tryck Hämta påminnelselistor, tillåt full åtkomst och välj testlistan på båda telefonerna. Listans lokala identifierare kan skilja mellan telefonerna.
2. Lägg i listan en äldre ”Byt Omnipod inom 8h”, en ”Byt Sensor inom 12h” och en orelaterad påminnelse. Lägg även en Omnipod-påminnelse i en annan lista.
3. Välj Poddbyte, datum, Medtrum och önskade timmar. Kontrollera rubrik och beräknad tid innan Utför. Bara den gamla pumpbytespåminnelsen i vald lista ska ersättas. Sensorpåminnelsen, den orelaterade posten och den andra listan ska vara kvar.
4. Kontrollera påminnelsens datum och avisering i Påminnelser. Efter iCloud-synk ska den också synas på den andra telefonen. Loop Follow kan inte välja mottagare eller styra iClouds synktid; listans delning och respektive telefons notisinställningar gäller.
5. Upprepa för Sensorbyte och kontrollera att pumpbytespåminnelsen behålls. Tiderna räknas som förflutna timmar, även över sommar-/vintertidsbyte.
6. Kontrollera att läsbehörighet utan skrivrättighet till listan, nekad appbehörighet och ett passerat påminnelsedatum hanteras utan att tidigare poster tas bort.

Mot en Nightscout-testinstans:

1. Välj Insulinbyte, välj ett tidigare datum och ange en valfri anteckning. Registrera. Kontrollera eventType `Insulin Change`, datum, `enteredBy` från vårdgivarnamnet och texten `Ny insulinampull (…)`.
2. Välj Notering. Testa Inställningar, HBA1C, Ketoner och Egen rubrik med brödtext. Kontrollera eventType `Note` och formatet `Rubrik (brödtext)`.
3. Nekad Påminnelser-behörighet ska inte blockera Nightscout-grenarna. Tom rubrik/brödtext ska blockera Notering. Knappen ska vara inaktiverad medan sparande pågår; fel ska behålla inmatningen.

Automatiserade kontroller: `python3 tests/health-logging.py` använder produktionens regler och tjänst med en simulerad EventKit-store och Nightscout-klient. Inga riktiga påminnelser eller behandlingar skapas av testerna.
