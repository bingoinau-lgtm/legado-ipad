import Foundation
import Combine

@MainActor
final class SearchHistoryStore: ObservableObject {
    static let shared = SearchHistoryStore()

    @Published private(set) var keywords: [String] = []

    private let storageKey = "legado.discoverSearchHistory"
    private let maxCount = 30

    private init() {
        load()
    }

    func add(_ keyword: String) {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        keywords.removeAll { $0.caseInsensitiveCompare(key) == .orderedSame }
        keywords.insert(key, at: 0)
        if keywords.count > maxCount {
            keywords = Array(keywords.prefix(maxCount))
        }
        save()
    }

    func remove(_ keyword: String) {
        keywords.removeAll { $0 == keyword }
        save()
    }

    func clear() {
        keywords = []
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            keywords = []
            return
        }
        keywords = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(keywords) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
