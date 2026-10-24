import UIKit

/// Shared local history editor; choosing None is also an explicit manual override.
final class SiteSelectionButton: UIButton {
    private(set) var selectedSite: String?
    private(set) var wasEdited = false

    init() {
        super.init(frame: .zero)
        showsMenuAsPrimaryAction = true
        contentHorizontalAlignment = .leading
        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "chevron.up.chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 12
        configuration = config
        updateMenu()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(site: String?) {
        selectedSite = site
        wasEdited = false
        updateMenu()
    }

    private func updateMenu() {
        configuration?.title = "Site: \(selectedSite ?? "Ingen site")"
        accessibilityLabel = "Ange site"
        accessibilityValue = selectedSite ?? "Ingen site"
        let choices: [String?] = [nil] + HealthLogSite.allCases.map { Optional($0.rawValue) }
        menu = UIMenu(children: choices.map { site in
            UIAction(title: site ?? "Ingen site", state: selectedSite == site ? .on : .off) { [weak self] _ in
                self?.selectedSite = site
                self?.wasEdited = true
                self?.updateMenu()
            }
        })
    }
}
