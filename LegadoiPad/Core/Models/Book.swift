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
