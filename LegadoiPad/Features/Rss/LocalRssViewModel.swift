import Foundation
import Combine

@MainActor
final class LocalRssViewModel: ObservableObject {
    @Published var articles: [RssArticle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var feedTitle: String = ""

    func load(feed: LocalRssFeed) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let parsed = try await RssFeedClient.fetch(feedURLString: feed.feedURL)
            feedTitle = parsed.title
            articles = parsed.articles
            if articles.isEmpty {
                errorMessage = RssFeedError.emptyFeed.localizedDescription
            }
        } catch {
            articles = []
            errorMessage = error.localizedDescription
        }
    }
}
