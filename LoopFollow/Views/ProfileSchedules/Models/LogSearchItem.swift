import Foundation

@available(iOS 26.0, *)
struct LogSearchItem: Identifiable {
    let term: String
    var id: String { term }
}

