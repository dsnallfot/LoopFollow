import Foundation

extension DailyStatsViewModel {
    /// Skapa CSV-sträng (separat från export så du kan testa i logg om du vill).
    func makeCSVString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        func fmt(_ value: Double?, decimals: Int = 2) -> String {
            guard let value = value else { return "" }
            let formatted = String(format: "%.\(decimals)f", value)
            // Byt punkt mot komma för svensk Excel
            return formatted.replacingOccurrences(of: ".", with: ",")
        }
        
        var lines: [String] = []
        lines.append("Datum;KH tot (g);Insulin tot (E);Medel BS;Låg %;TIT 3.9-7.8;Std. Dev;Basal (teoretisk)")
        
        for row in rowsWithSufficientGlucose.sorted(by: { $0.date < $1.date }) {
            let dateStr = dateFormatter.string(from: row.date)
            
            // Skala procent 0–100 → 0–1 så Excel kan använda cellformat Procent
            let lowFraction = row.lowPercent.map { $0 / 100.0 }
            let tightFraction = row.tightRangePercent.map { $0 / 100.0 }
            
            let line = [
                dateStr,
                fmt(row.totalCarbs, decimals: 0),
                fmt(row.insulinTDD),
                fmt(row.meanGlucoseMmol, decimals: 2),
                fmt(lowFraction),                 // nu 0–1
                fmt(tightFraction),               // nu 0–1
                fmt(row.stdDevMmol, decimals: 2),
                fmt(row.profileBasal)
            ].joined(separator: ";")              // semikolonseparerat
            lines.append(line)
        }

        return lines.joined(separator: "\n")
    }

    /// Skriv CSV till Documents och returnera URL för delning.
    func writeCSVToDisk() -> URL? {
        let csvString = makeCSVString()
        guard let data = csvString.data(using: .utf8) else { return nil }

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        let exportURL = documentsURL.appendingPathComponent("DailyStats_\(today).csv")

        do {
            try data.write(to: exportURL, options: .atomic)
            return exportURL
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Misslyckades skriva CSV: \(error.localizedDescription)"
            }
            return nil
        }
    }
}
