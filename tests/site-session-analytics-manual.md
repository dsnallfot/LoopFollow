# Site/session history checks

Run `python3 tests/site-session-analytics.py` for the Foundation model/worker tests.

On a device or already running simulator:

1. Open Pumpar/ Sensorer after syncing a change plus a slightly later `Note` with
   `Pumpsite: Lår (Höger)` / `Sensorsite: Överarm (Vänster)`. Confirm Site appears on
   the correct row and is retained after restart. A note exactly at the next change
   belongs to the new session; an unmatched earlier note remains only in the note log.
2. Swipe left → Redigera, select another Site, save and reopen. Automatic sync must
   not replace the manual site, including explicit “Ingen site”. Edit a sensor while
   the history search is filtered and verify the intended row is changed.
3. Change only the site and verify existing sensor error details/usage timestamp are
   retained. Change a session date and check that affected numeric summaries refresh.
4. Export and import both histories, including an older JSON without new fields.
   Existing site/summary data must survive an old export; new fields must round-trip.
5. In Sitebyten, Pumpar shows four rows for session hours and TDD; Sensorer shows days
   and error minutes/day. Selecting a body region changes the last two rows. Alla
   hides this additional section. Missing data/site selection displays “–”.
6. TDD uses the statistics cache's basal pulse simulation plus bolus/SMB over the
   exact half-open pump interval. Closed sessions persist totals and boundaries;
   opening the view recalculates the ongoing pump to now, without persisting it as
   complete. Compare an interval crossing midnight and one with a dose exactly at
   the next pump change.
7. Verify a missing cache day or stale/missing basal does not produce a zero TDD.
   For sensor error averages, unknown outage duration or missing session coverage
   must not produce zero minutes. A covered session with no errors should show zero.
8. Change/delete a source dose or site note and resync. Confirm the matching cached
   TDD/site changes. Summaries with unchanged source reuse the stored result.
9. Mean session duration includes completed sessions only. Daily totals are weighted
   by elapsed seconds (86400-second normalization), not calendar-day count. The
   ongoing pump contributes a preliminary TDD when covered. Sensor error rates use
   completed sessions with structured, verified durations; legacy text alone is not
   treated as numerical data. The footer states sample counts and data limitations.

Manual site edits affect local history, not Nightscout notes. Previously calculated
closed summaries remain available when their raw source ages out of retention;
changed boundaries invalidate them. Historical sessions that have already lost
source data cannot be backfilled by this local-only refresh.
