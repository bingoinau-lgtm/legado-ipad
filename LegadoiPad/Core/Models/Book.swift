import Foundation

struct Book: Codable, Identifiable, Hashable {
    var id: String { bookUrl }

    let name: String
    let author: String
    let bookUrl: String
    let tocUrl: String?
    let origin: String?
    let originName: String?
    let type: Int?
    let coverUrl: String?
    let customCoverUrl: String?
    let intro: String?
    let kind: String?
    let wordCount: String?
    let latestChapterTitle: String?
    let totalChapterNum: Int?
    let durChapterTitle: String?
    let durChapterIndex: Int?
    let durChapterPos: Int?
    let durChapterTime: Int64?
    let canUpdate: Bool?
    let order: Int?

    var displayCoverURL: URL? {
        if let customCoverUrl, let url = URL(string: customCoverUrl), !customCoverUrl.isEmpty {
            return url
        }
        if let coverUrl, let url = URL(string: coverUrl), !coverUrl.isEmpty {
            return url
        }
        return nil
    }

    var progressText: String {
        if let title = durChapterTitle, !title.isEmpty {
            return title
        }
        if let latest = latestChapterTitle, !latest.isEmpty {
            return latest
        }
        return "尚未阅读"
    }
}

struct BookChapter: Codable, Identifiable, Hashable {
    var id: String { "\(bookUrl)-\(index)-\(url)" }

    let url: String
    let title: String
    let bookUrl: String
    let index: Int
    let isVolume: Bool?
    let isVip: Bool?
    let isPay: Bool?
    let tag: String?
}

struct BookProgress: Codable {
    let name: String
    let author: String
    let durChapterIndex: Int
    let durChapterPos: Int
    let durChapterTime: Int64
    let durChapterTitle: String?
}

struct RssSource: Codable, Identifiable, Hashable {
    var id: String { sourceUrl }

    let sourceUrl: String
    let sourceName: String
    let sourceIcon: String?
    let sourceGroup: String?
    let sourceComment: String?
    let enabled: Bool?
    let singleUrl: Bool?
    let articleStyle: Int?
    let customOrder: Int?
    let lastUpdateTime: Int64?
    let enableJs: Bool?
    let loadWithBaseUrl: Bool?

    var displayGroup: String {
        let group = sourceGroup?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return group.isEmpty ? "未分组" : group
    }

    var isEnabled: Bool {
        enabled ?? true
    }
}

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

enum RssSelection: Hashable {
    case local(LocalRssFeed)
    case phone(RssSource)
}

// MARK: - Book Source

struct BookSource: Codable, Identifiable, Hashable {
    var id: String { bookSourceUrl }

    var bookSourceUrl: String
    var bookSourceName: String
    var bookSourceGroup: String?
    var bookSourceComment: String?
    var bookSourceType: Int?
    var enabled: Bool?
    var enabledExplore: Bool?
    var header: String?
    var searchUrl: String?
    var exploreUrl: String?
    var bookUrlPattern: String?
    var loginUrl: String?
    var loginCheckJs: String?
    var ruleSearch: BookListRule?
    var ruleExplore: BookListRule?
    var ruleBookInfo: BookInfoRule?
    var ruleToc: TocRule?
    var ruleContent: ContentRule?
    var customOrder: Int?
    var respondTime: Int?
    var weight: Int?
    var lastUpdateTime: String?

    var isEnabled: Bool { enabled ?? true }

    var displayGroup: String {
        let group = bookSourceGroup?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return group.isEmpty ? "未分组" : group
    }
}

struct BookListRule: Codable, Hashable {
    var bookList: String?
    var name: String?
    var author: String?
    var intro: String?
    var kind: String?
    var lastChapter: String?
    var bookUrl: String?
    var coverUrl: String?
    var wordCount: String?
}

struct BookInfoRule: Codable, Hashable {
    var name: String?
    var author: String?
    var intro: String?
    var kind: String?
    var lastChapter: String?
    var coverUrl: String?
    var tocUrl: String?
    var wordCount: String?
}

struct TocRule: Codable, Hashable {
    var chapterList: String?
    var chapterName: String?
    var chapterUrl: String?
    var nextTocUrl: String?
}

struct ContentRule: Codable, Hashable {
    var content: String?
    var nextContentUrl: String?
    var replaceRegex: String?
}

struct SourceBook: Identifiable, Hashable {
    var id: String { bookUrl }
    var name: String
    var author: String
    var bookUrl: String
    var coverUrl: String?
    var intro: String?
    var kind: String?
    var lastChapter: String?
    var origin: String
    var originName: String
    var tocUrl: String?
}

struct SourceChapter: Identifiable, Hashable {
    var id: String { url }
    var title: String
    var url: String
    var index: Int
}

enum BookSourceError: LocalizedError {
    case invalidURL
    case emptyResult(String)
    case rule(String)
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "地址无效"
        case .emptyResult(let message):
            return message
        case .rule(let message):
            return message
        case .transport(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}

enum BookSourceSelection: Hashable {
    case source(BookSource)
    case book(SourceBook)
}
