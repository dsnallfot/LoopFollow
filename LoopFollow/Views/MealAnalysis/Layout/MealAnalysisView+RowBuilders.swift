import UIKit

extension MealAnalysisView {
    func makeDivider(height: CGFloat = 1) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .separator   // systemanpassad färg
        NSLayoutConstraint.activate([
            v.heightAnchor.constraint(equalToConstant: height)
        ])
        return v
    }

    static func makeValueLabel(bold: Bool = false) -> UILabel {
        let label = UILabel()
        label.text = "0.00 E"
        label.font = bold
            ? .preferredFont(forTextStyle: .body).withTraits(traits: .traitBold)
            : .preferredFont(forTextStyle: .body)
        return label
    }

    func makeRow(iconName: String,
                         iconColor: UIColor,
                         text: String,
                         valueLabel: UILabel,
                         boldText: Bool = false,
                         secondary: Bool = false) -> UIStackView {
        let icon = UIImageView(image: UIImage(systemName: iconName))
        icon.tintColor = iconColor
        let textLabel = UILabel()
        textLabel.font = boldText
            ? .preferredFont(forTextStyle: .body).withTraits(traits: .traitBold)
            : .preferredFont(forTextStyle: .body)
        textLabel.text = text
        let spacer = UIView()
        let row = UIStackView(arrangedSubviews: [icon, textLabel, spacer, valueLabel])
        row.axis = .horizontal
        row.spacing = 5
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        if secondary {
            textLabel.textColor = .secondaryLabel
            valueLabel.textColor = .secondaryLabel
        }
        return row
    }
    /// Normalizes and merges BG entries by timestamp, removes duplicates, and gap-fills 5‑min intervals.
    func makeStatRow(textLabel externalTextLabel: UILabel? = nil,
                             text: String,
                             valueLabel: UILabel,
                             boldText: Bool = false,
                             unit: String) -> UIStackView {
        let textLabel = externalTextLabel ?? UILabel()
        textLabel.text = text
        textLabel.font = boldText
            ? .preferredFont(forTextStyle: .caption1).withTraits(traits: .traitBold)
            : .preferredFont(forTextStyle: .caption1)
        let spacer = UIView()
        // Append unit to value label later; start blank
        valueLabel.text = "--\(unit)"
        let row = UIStackView(arrangedSubviews: [textLabel, spacer, valueLabel])
        row.axis = .horizontal
        row.spacing = 5
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textLabel.textColor = .label
        valueLabel.textColor = .label
        valueLabel.font = .preferredFont(forTextStyle: .caption1)
        return row
    }
}
