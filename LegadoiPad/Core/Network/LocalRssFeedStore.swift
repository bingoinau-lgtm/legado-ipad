import Foundation

@MainActor
final class LocalRssFeedStore: ObservableObject {
    static let shared = LocalRssFeedStore()

    @Published private(set) var feeds: [LocalRssFeed] = []

    private let storageKey = "legado.localRssFeeds"

    private init() {
        load()
    }

    func add(_ feed: LocalRssFeed) {
        if let index = feeds.firstIndex(where: { $0.feedURL == feed.feedURL }) {
            feeds[index] = feed
        } else {
            feeds.insert(feed, at: 0)
        }
        save()
    }

    func remove(ids: IndexSet) {
        for index in ids.sorted(by: >) where feeds.indices.contains(index) {
            feeds.remove(at: index)
        }
        save()
    }

    func remove(feedURL: String) {
        feeds.removeAll { $0.feedURL == feedURL }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([LocalRssFeed].self, from: data) else {
            feeds = []
            return
        }
        feeds = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(feeds) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
