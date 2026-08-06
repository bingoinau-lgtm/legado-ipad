import Foundation

struct LocalRssFeed: Codable, Identifiable, Hashable {
    var id: String { feedURL }
    var title: String
    var feedURL: String
    var siteURL: String?
    var addedAt: Date

    init(title: String, feedURL: String, siteURL: String? = nil, addedAt: Date = Date()) {
        self.title = title
        self.feedURL = feedURL
        self.siteURL = siteURL
        self.addedAt = addedAt
    }
}

struct RssArticle: Identifiable, Hashable {
    var id: String { link.isEmpty ? "\(title)-\(publishedAt?.timeIntervalSince1970 ?? 0)" : link }

    let title: String
    let link: String
    let summary: String
    let author: String?
    let publishedAt: Date?
}

enum RssFeedError: LocalizedError {
    case invalidURL
    case emptyFeed
    case parseFailed
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "订阅地址无效"
        case .emptyFeed:
            return "未解析到任何文章，请确认是 RSS / Atom 地址"
        case .parseFailed:
            return "无法解析该订阅，请使用标准 RSS 或 Atom 链接"
        case .transport(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
