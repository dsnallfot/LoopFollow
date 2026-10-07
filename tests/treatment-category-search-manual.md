# Kategorisökning – test på telefon

Sökningen körs när du trycker **Sök** på tangentbordet. Den söker i hela cacheperioden
(91 kalenderdagar enligt nuvarande inställning), oberoende av datumväljaren.
Segmentet begränsar träffarna; använd **Alla** för att söka över alla kategorier.
Inga historikförfrågningar till Nightscout görs av själva sökningen.

1. Öppna Behandlingar och sök `sensorbyte`, `pumpbyte`, `fett/protein` och `fpu`.
   Kontrollera att äldre träffar visas utan att först scrolla in deras dagar.
   Jämför första sökningens svarstid med efterföljande sökningar.
2. Sök `sensor`, `SENSORBYTE`, `måltid` och `maltid`. Delord, skiftläge och accenter
   ska fungera. `måltid`, `dextro` och `fett/protein` ska ge separata kategorier.
   Ett ord som bara finns i en anteckning eller matbeskrivning ska inte ge träff.
3. Växla mellan Alla, Auto, Manuell och Övriga under aktiv sökning. Träffantal och
   segmentnamn ska stämma. Vid noll träffar i ett begränsat segment visas tips om Alla.
4. Sök `basal` eller en annan kategori med fler än 100 träffar. Scrolla nedåt:
   fler träffar ska tillkomma i datumordning utan nätverksväntan eller hopp i listan.
5. Scrolla den vanliga listan till en äldre dag. Sök något och rensa med det lilla
   krysset i sökfältet. Datum, segment och scrollposition ska återställas.
   Ingen separat avbrytknapp ska visas bredvid sökfältet.
6. Sök och rensa direkt, eller byt snabbt sökord/segment. Ett gammalt söksvar får
   inte dyka upp efter rensning eller ersätta resultatet för den nyare sökningen.
7. Kontrollera detaljer för en gammal träff. Om du ändå behöver redigera eller
   radera en behandling, verifiera att träffen uppdateras/försvinner även på en dag
   som aldrig laddats i vanliga listan. Använd testdata för ren mutationstestning.
8. Sök måltider kring midnatt och kontrollera statusmarkören mot vanlig dagvisning.
   Glukosdata för följande dag ska användas när den finns i cachen.
9. Testa utan nätverk med befintlig cache. Träffarna ska fortfarande visas. Ett
   saknat/oläsbart cachedygn rapporteras i statusraden; noll träffar betyder endast
   noll träffar i tillgänglig cache, inte bevis på fullständig Nightscout-historik.
10. Låt en vanlig behandlingsuppdatering komma medan sökningen är öppen. Resultatet
    ska uppdateras och listan behålla sin position så långt innehållet tillåter.

Automatiserad kontroll: `python3 tests/treatment-category-search.py`.
