import UIKit
import Charts

extension GlucoseView {
    /// Visar sensorstatus / Dexcom-noteringar som förklaring till saknade värden.
    /// Letar efter en Nightscout-treatment av typen "Note".
    /// För sensor-miss: senaste Dexcom-Note efter senaste lyckade BG gäller tills nästa BG kommer in.
    /// För Trio-upload-miss: snäv lookup kring saknad timestamp (± toleranceSeconds).
    func showSensorStatusAlert(forMissingDate missingDate: Date,
                                       reason: MissingReason,
                                       onDismiss: @escaping () -> Void) {
        Task {
            // A Dexcom sensor "Note" can describe an outage spanning multiple missing 5‑min slots.
            // Therefore, for sensor-missing rows we treat the latest Dexcom Note *after the last successful BG*
            // as valid until the next BG arrives.
            let note: Treatment?
            if reason == .sensor {
                let bounds = self.sensorOutageBounds(around: missingDate)
                note = await self.fetchLatestDexcomNote(after: bounds.start, before: bounds.end)
            } else {
                // For Trio-upload misses, keep the narrow lookup around the missing timestamp.
                note = await self.fetchDexcomNoteTreatment(around: missingDate, toleranceSeconds: 60)
            }

            await MainActor.run {
                let timeFormatter = DateFormatter()
                timeFormatter.locale = Locale(identifier: "sv_SE")
                timeFormatter.dateFormat = "dd MMM HH:mm:ss"

                let titleTime: String
                let message: String

                if let note = note,
                   let fullNote = note.rawData["notes"] as? String {

                    // created_at/timestamp från noten används i rubriken
                    titleTime = timeFormatter.string(from: note.timestamp)

                    var msg = fullNote
                    if let enteredBy = note.rawData["enteredBy"] as? String, !enteredBy.isEmpty {
                        msg += "\nInlagt av: \(enteredBy)"
                    }
                    message = msg

                } else {
                    // Ingen Dexcom-notering hittades i spannet — fallback-texter.
                    titleTime = timeFormatter.string(from: missingDate)

                    switch reason {
                    case .sensor:
                        message =
                        """
                        Ingen Dexcom-notering hittades i anslutning till det saknade glukosvärdet.

                        Detta beror oftast på tappad bluetoothsignal mellan sensorn och den mottagande telefonen, eller att värdet inte kunde laddas upp till varesig Dexcom Share eller Nightscout (t.ex. server-/nätverksproblem).
                        """
                    case .trioUpload:
                        message =
                        """
                        Ingen Dexcom-notering hittades i anslutning till det saknade glukosvärdet.

                        Detta beror på att Trio → Nightscout-uppladdningen misslyckadades (t.ex. bluetooth-/nätverksproblem eller andra problem med Trio-appen).
                        """
                    }
                }

                let alert = UIAlertController(
                    title: "\(titleTime)\n\nSensorstatus",
                    message: message,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    onDismiss()
                })
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    func showExactDexcomNoteAlert(note: Treatment, durationMinutes: Int?, onDismiss: @escaping () -> Void) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "dd MMM HH:mm:ss"

        let titleTime = df.string(from: note.timestamp)
        let fullNote = (note.rawData["notes"] as? String) ?? "(Ingen text)"

        var msg = fullNote
        if let durationMinutes = durationMinutes {
            msg += "\n\nVaraktighet: \(durationMinutes) min"
        }
        if let enteredBy = note.rawData["enteredBy"] as? String, !enteredBy.isEmpty {
            msg += "\nInlagt av: \(enteredBy)"
        }

        let alert = UIAlertController(
            title: "\(titleTime)\n\nSensorfel",
            message: msg,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            onDismiss()
        })
        present(alert, animated: true)
    }
}
