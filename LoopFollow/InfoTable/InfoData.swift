//
//  InfoData.swift
//  LoopFollow
//
//  Created by Jonas Björkert on 2024-07-11.

//

import UIKit

class InfoData {
    var name: String
    var symbol: InfoStatusSymbol?
    var value: String

    init(name: String, value: String = "", symbol: InfoStatusSymbol? = nil) {
        self.name = name
        self.value = value
        self.symbol = symbol
    }

    func applyValue(to label: UILabel?) {
        guard let label else { return }
        label.attributedText = nil
        label.text = value
        label.accessibilityLabel = value
        guard let symbol else { return }
        label.accessibilityLabel = "\(value), \(symbol.accessibilityDescription)"
        let font = label.font ?? UIFont.preferredFont(forTextStyle: .body)
        let configuration = UIImage.SymbolConfiguration(font: font)
        guard let image = UIImage(systemName: symbol.systemName, withConfiguration: configuration) else {
            label.text = "\(value) \(symbol.emoji)"
            return
        }
        let attachment = NSTextAttachment()
        attachment.image = image.withTintColor(symbol.color.resolvedColor(with: label.traitCollection), renderingMode: .alwaysOriginal)
        attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2,
                                   width: image.size.width, height: image.size.height)
        let attributed = NSMutableAttributedString(string: value.isEmpty ? "" : value + " ")
        attributed.append(NSAttributedString(attachment: attachment))
        label.attributedText = attributed
    }
}

/// A status indicator independent of its text and the table row's text color.
enum InfoStatusSymbol: String, CaseIterable {
    case red = "🔴", yellow = "🟡", green = "🟢", purple = "🟣", orange = "🟠", blue = "🔵"
    case warning = "⚠", success = "✅", prohibited = "🚫", stop = "⛔", sos = "🆘"
    case inactive = "⚫", unavailable = "❌", goalReached = "⭐"
    case clock = "⏱", increase = "🔺", decrease = "🔻", charging = "⚡"

    var emoji: String { rawValue }

    var systemName: String {
        switch self {
        case .red, .yellow, .green, .purple, .orange, .blue, .inactive: return "circle.fill"
        case .warning, .prohibited, .stop: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        case .goalReached: return "star.fill"
        case .unavailable: return "xmark.circle.fill"
        case .sos: return "sos.circle.fill"
        case .clock: return "clock.fill"
        case .increase: return "arrow.up"
        case .decrease: return "arrow.down"
        case .charging: return "bolt.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .red, .prohibited, .stop, .sos, .decrease, .unavailable: return .systemRed
        case .yellow, .charging, .goalReached: return .systemYellow
        case .green, .success: return .systemGreen
        case .purple: return .systemPurple
        case .orange, .warning: return .systemOrange
        case .blue, .increase: return .systemBlue
        case .inactive: return .secondaryLabel
        case .clock: return .lightGray
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .red: return "Röd status"
        case .yellow: return "Gul status"
        case .green: return "Grön status"
        case .purple: return "Lila status"
        case .orange: return "Orange status"
        case .blue: return "Blå status"
        case .warning: return "Varning"
        case .success: return "OK"
        case .prohibited, .stop: return "Stopp"
        case .inactive: return "Inaktiv"
        case .goalReached: return "Mål uppnått"
        case .unavailable: return "Ej möjligt"
        case .sos: return "SOS"
        case .clock: return "Fördröjd"
        case .increase: return "Ökad"
        case .decrease: return "Minskad"
        case .charging: return "Laddar"
        }
    }
}

/// Compatibility for machine-generated status strings; never applied to user notes or profile names.
struct InfoStatusValue: Equatable {
    let text: String
    let symbol: InfoStatusSymbol?

    init(legacyText: String) {
        let trimmed = legacyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = trimmed.last {
            let normalized = String(last).unicodeScalars.filter { $0.value != 0xFE0F && $0.value != 0xFE0E }
            if let symbol = InfoStatusSymbol(rawValue: String(String.UnicodeScalarView(normalized))) {
                self.text = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
                self.symbol = symbol
                return
            }
        }
        self.text = legacyText
        self.symbol = nil
    }
}
