import SwiftUI
import UIKit

@available(iOS 16.0, *)
struct ProfileSettingsLogModal: UIViewControllerRepresentable {
    let initialSearchText: String

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = TrioSettingsLogView(initialSearchText: initialSearchText)
        let nav = UINavigationController(rootViewController: vc)
        
        // 1. Gör Navigationsbaren helt transparent (kopierat från din fungerande kod)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // Se till att titeln syns (kan behövas om texten är vit/svart mot bakgrunden)
        // appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        
        // 2. Sätt bakgrunden på själva navigation viewn till transparent
        nav.view.backgroundColor = .clear
        
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        if let vc = uiViewController.viewControllers.first as? TrioSettingsLogView {
            // OBS: Detta anrop kan orsaka oönskad loop om du skriver i sökfältet
            // och SwiftUI uppdaterar vyn. Kontrollera att logiken i TrioSettingsLogView hanterar dubbletter.
            vc.setSearchTextAndFilter(initialSearchText)
        }
    }
}

