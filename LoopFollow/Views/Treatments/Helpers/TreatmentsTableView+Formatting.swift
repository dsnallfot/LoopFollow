import UIKit

extension TreatmentsTableView {
    func previewOverrideText(for text: String) -> String {
        if text.count > 19 {
            return String(text.prefix(19)) + "…"
        } else {
            return text
        }
    }
    
    func previewCarbsText(for text: String) -> String {
        if text.count > 6 {
            return String(text.prefix(6)) + "…"
        } else {
            return text
        }
    }
    
    func previewNoteText(for text: String) -> String {
        if text.count > 28 {
            return String(text.prefix(28)) + "…"
        } else {
            return text
        }
    }
    
    func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    // Helper to determine symbol name and color for a given event type.
    func symbolForEventType(_ eventType: String, foodType: String? = nil, fullNote: String? = nil) -> (name: String, color: UIColor) {
        // Identifiera Dextro via foodType som innehåller 🍬
        let isDextro = (foodType ?? "").contains("🍬")
        
        if eventType == "Carb Correction" {
            // Dextro / lågbehandling som registrerats som Carb Correction men har 🍬 i foodType
            if isDextro {
                return ("circle.fill", .white)
            }
            // Om foodType är tomt → Fett & Protein (brun), annars vanlig Kh (orange)
            if let food = foodType, !food.isEmpty {
                return ("circle.fill", .systemOrange.withAlphaComponent(0.8))
            } else {
                return ("circle.fill", .brown.withAlphaComponent(0.4))
            }
        }
        
        switch eventType {
        case "Temp Basal":
            return ("circle.fill", .systemBlue.withAlphaComponent(0.2))
        case "Bolus", "Correction Bolus", "Meal Bolus", "Insulinpenna":
            return ("circle.fill", .systemBlue.withAlphaComponent(0.8))
        case "SMB":
            return ("bolt.circle.fill", .systemBlue.withAlphaComponent(0.8))
        case "Dextro":
            // Dextro / lågbehandling – egen färg
            return ("circle.fill", .white)
        case "Kolhydrater", "Måltid":
            // Om foodType råkar innehålla 🍬 här också, använd samma Dextro-färg.
            if isDextro {
                return ("circle.fill", .white)
            } else {
                return ("circle.fill", .systemOrange.withAlphaComponent(0.8))
            }
        case "BG Check":
            return ("circle.fill", .systemRed.withAlphaComponent(1.0))
        case "Exercise":
            return ("circle.fill", .systemPurple.withAlphaComponent(0.7))
        case "Note", "Announcement":
            // Use the full note text from rawData to determine the symbol.
            if let noteText = fullNote, noteText.contains("Justerad") || noteText.contains("ändrades") {
                return ("gearshape.circle.fill", .label.withAlphaComponent(0.5))
            } else if let noteText = fullNote, noteText.contains("PumpSuspend") {
                return ("pause.circle.fill", .systemTeal.withAlphaComponent(0.75))
            } else if let noteText = fullNote, noteText.contains("PumpResume") {
                return ("play.circle.fill", .systemTeal.withAlphaComponent(0.75))
            } else if let noteText = fullNote, noteText.contains("⚠️") {
                return ("exclamationmark.triangle.fill", .systemYellow.withAlphaComponent(0.85))
            } else if let noteText = fullNote, noteText.contains("⛔️") {
                return ("exclamationmark.triangle.fill", .systemRed.withAlphaComponent(0.85))
            } else if let noteText = fullNote, noteText.contains("Meta Quest spel startades") || noteText.contains("Träning startades") {
                return ("play.circle.fill", .systemGreen.withAlphaComponent(0.75))
            } else if let noteText = fullNote, noteText.contains("Meta Quest spel avslutades") || noteText.contains("Träning avslutades") {
                return ("stop.circle.fill", .systemGreen.withAlphaComponent(0.75))
            } else if let noteText = fullNote, noteText.contains("Trio startades om") {
                return ("repeat.circle.fill", .label.withAlphaComponent(0.5))
            } else {
                return ("circle.fill", .label.withAlphaComponent(0.5))
            }
        case "Site Change", "Insulin Change", "Sensor Start", "Sensor Change", "Sensorbyte", "Sensorstart":
            return ("repeat.circle.fill", .systemTeal.withAlphaComponent(0.75))
        default:
            return ("circle.fill", .label.withAlphaComponent(0.5))
        }
    }
    
    func formatReason(_ reason: String) -> String {
        var formatted = reason
        
        // Step 1: Handle AF and SMB Ratio before other replacements.
        // Regex pattern to match: "AF: <number> (optionally, , SMB Ratio: <number>) ;"
        let patternAFSMB = "AF:\\s([0-9]\\.[0-9]{1,2})(?:,\\sSMB Ratio:\\s([0-9]\\.[0-9]{1,2}))?;"
        if let regexAFSMB = try? NSRegularExpression(pattern: patternAFSMB, options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            // Enumerate matches in reverse order to avoid index shifts.
            let matches = regexAFSMB.matches(in: formatted, options: [], range: range)
            for match in matches.reversed() {
                let fullRange = match.range(at: 0)
                let afValue = (formatted as NSString).substring(with: match.range(at: 1))
                var replacement = "AF: \(afValue)\n"
                if match.numberOfRanges > 2, match.range(at: 2).location != NSNotFound {
                    let smbValue = (formatted as NSString).substring(with: match.range(at: 2))
                    if !smbValue.isEmpty {
                        replacement += "• SMB Ratio: \(smbValue)\n"
                    }
                }
                replacement += "\n👉  OREF SLUTSATS:\n•"
                formatted = (formatted as NSString).replacingCharacters(in: fullRange, with: replacement)
            }
        }
        
        // Step 2: Replace all commas with a line break bullet.
        formatted = formatted.replacingOccurrences(of: ",", with: "\n•")
        
        // 3. Mer specifika ersättningar.

        // Endast "BG: 5.5" som INTE har en bokstav direkt före "B"
        if let regexBG55 = try? NSRegularExpression(pattern: "(?<![A-Za-z])BG: 5\\.5", options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            formatted = regexBG55.stringByReplacingMatches(
                in: formatted,
                options: [],
                range: range,
                withTemplate: "Glukos: 5.5 🦄"
            )
        }

        // Endast "BG:" som INTE har en bokstav direkt före "B"
        if let regexBG = try? NSRegularExpression(pattern: "(?<![A-Za-z])BG:", options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            formatted = regexBG.stringByReplacingMatches(
                in: formatted,
                options: [],
                range: range,
                withTemplate: "Glukos:"
            )
        }
        formatted = formatted.replacingOccurrences(of: "SMB INAKTIVERADE!", with: "SMB Inaktiverade 🚫")
        formatted = formatted.replacingOccurrences(of: "Mikrobolus:", with: "🔹 Mikrobolus:")
        formatted = formatted.replacingOccurrences(of: ". ;", with: "\n• ")
        formatted = formatted.replacingOccurrences(of: "E. ", with: "E\n")
        formatted = formatted.replacingOccurrences(of: "U. ", with: "E\n")
        formatted = formatted.replacingOccurrences(of: "E/h. ", with: "E/h\n")
        formatted = formatted.replacingOccurrences(of: "temp.", with: "temp.\n")
        formatted = formatted.replacingOccurrences(of: ". ", with: "")
        formatted = formatted.replacingOccurrences(of: "; ", with: "\n• ")
        
        // Replace TDD: <number> U with bold TDD (using regex)
        if let regexTDD = try? NSRegularExpression(pattern: "TDD:\\s(\\d+(?:\\.\\d{1,2})?)\\sU", options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            formatted = regexTDD.stringByReplacingMatches(in: formatted, options: [], range: range, withTemplate: "TDD: $1E")
        }
        
        // New step: Replace HTML encoded less-than and greater-than signs
        formatted = formatted.replacingOccurrences(of: "&lt;", with: "<")
        formatted = formatted.replacingOccurrences(of: "&gt;", with: ">")
        
        return formatted
    }
}
