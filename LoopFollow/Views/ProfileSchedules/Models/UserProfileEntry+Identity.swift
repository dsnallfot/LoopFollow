import Foundation

extension Notification.Name {
    static let userProfileUpdated = Notification.Name("UserProfileUpdated")
}

extension UserProfileEntry: Identifiable {
    public var id: Date { updatedAt }
}

