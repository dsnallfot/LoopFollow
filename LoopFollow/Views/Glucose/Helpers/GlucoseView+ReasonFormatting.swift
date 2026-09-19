import UIKit
import Charts

extension GlucoseView {
    /// Formatterar reason-strängen ungefär som i MainView/Graphs för BG-popupen.
    func formatGraphReason(_ reason: String) -> String {
        var formatted = reason

        // 1. Hantera AF och SMB Ratio innan övriga ersättningar.
        let patternAFSMB = "AF:\\s([0-9]\\.[0-9]{1,2})(?:,\\sSMB Ratio:\\s([0-9]\\.[0-9]{1,2}))?;"
        if let regexAFSMB = try? NSRegularExpression(pattern: patternAFSMB, options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
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

        // 2. Byt alla kommatecken mot radbrytning + punktlista.
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

        // 4. Ersätt "TDD: <number> U" med kompakt variant.
        if let regexTDD = try? NSRegularExpression(pattern: "TDD:\\s(\\d+(?:\\.\\d{1,2})?)\\sU", options: []) {
            let range = NSRange(location: 0, length: formatted.utf16.count)
            formatted = regexTDD.stringByReplacingMatches(
                in: formatted,
                options: [],
                range: range,
                withTemplate: "TDD: $1E"
            )
        }

        // 5. HTML-encodeade < och >.
        formatted = formatted.replacingOccurrences(of: "&lt;", with: "<")
        formatted = formatted.replacingOccurrences(of: "&gt;", with: ">")

        return formatted
    }
}
