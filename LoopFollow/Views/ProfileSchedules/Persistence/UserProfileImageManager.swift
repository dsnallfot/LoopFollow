import UIKit

// MARK: - User profile image persistence

final class UserProfileImageManager {
    static let shared = UserProfileImageManager()
    private let key = "UserProfileImageData"

    private init() {}

    func save(image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.9) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() -> UIImage? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return UIImage(data: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

