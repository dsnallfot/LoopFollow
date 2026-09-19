import UIKit

extension MealAnalysisView {
    // MARK: - Date sync overlay
    func showDateSyncOverlay(message: String) {
        // Semi-transparent full-screen overlay
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlay.alpha = 0.0
        
        // Centered solid container
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        container.layer.cornerRadius = 14
        container.clipsToBounds = true
        
        // SF Symbol icon
        let imageView = UIImageView(image: UIImage(systemName: "info.circle"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.textAlignment = .center
        label.textColor = .label
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [imageView, label])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 40),
            imageView.widthAnchor.constraint(equalToConstant: 40),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 17),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -17),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])
        
        overlay.addSubview(container)
        view.addSubview(overlay)
        
        let containerTopInset: CGFloat = showsDoneButton ? 77 : 120

        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            container.topAnchor.constraint(equalTo: overlay.topAnchor, constant: containerTopInset),
            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -12)
        ])
        view.layoutIfNeeded()
        
        // Light haptic feedback when the overlay appears
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        
        UIView.animate(withDuration: 0.25, animations: {
            overlay.alpha = 1.0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3,
                           delay: 1.4,
                           options: [.curveEaseInOut],
                           animations: {
                overlay.alpha = 0.0
            }, completion: { _ in
                overlay.removeFromSuperview()
            })
        })
    }
}
