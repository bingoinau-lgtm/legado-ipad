import Foundation

struct ParsedRssFeed {
    var title: String
    var siteURL: String?
    var articles: [RssArticle]
}

enum RssFeedClient {
    static func fetch(feedURLString: String) async throws -> ParsedRssFeed {
        guard let url = URL(string: feedURLString),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            throw RssFeedError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue(
            "LegadoiPad/0.1 (RSS Reader)",
            forHTTPHeaderField: "User-Agent"
        )

        let data: Data
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw RssFeedError.parseFailed
            }
            data = responseData
        } catch let error as RssFeedError {
            throw error
        } catch {
            throw RssFeedError.transport(error)
        }

        guard let parsed = RssFeedParser.parse(data: data) else {
            throw RssFeedError.parseFailed
        }
        guard !parsed.articles.isEmpty || !parsed.title.isEmpty else {
            throw RssFeedError.emptyFeed
        }
        return parsed
    }
}

final class RssFeedParser: NSObject, XMLParserDelegate {
    static func parse(data: Data) -> ParsedRssFeed? {
        let parser = RssFeedParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        guard xml.parse() else { return nil }
        return ParsedRssFeed(
            title: parser.feedTitle.isEmpty ? "未命名订阅" : parser.feedTitle,
            siteURL: parser.siteURL,
            articles: parser.articles
        )
    }

    private var feedTitle = ""
    private var siteURL: String?
    private var articles: [RssArticle] = []

    private var path: [String] = []
    private var textBuffer = ""

    private var itemTitle = ""
    private var itemLink = ""
    private var itemSummary = ""
    private var itemAuthor = ""
    private var itemDateText = ""
    private var atomLinkCandidate = ""

    private var isInsideEntry: Bool {
        path.contains("item") || path.contains("entry")
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = elementName.lowercased()
        path.append(name)
        textBuffer = ""

        if name == "item" || name == "entry" {
            itemTitle = ""
            itemLink = ""
            itemSummary = ""
            itemAuthor = ""
            itemDateText = ""
            atomLinkCandidate = ""
        }

        if name == "link" {
            if let href = attributeDict["href"], !href.isEmpty {
                let rel = attributeDict["rel"]?.lowercased() ?? "alternate"
                if !isInsideEntry {
                    if rel == "alternate" || siteURL == nil {
                        siteURL = href
                    }
                } else if rel == "alternate" || itemLink.isEmpty {
                    atomLinkCandidate = href
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = elementName.lowercased()
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if !isInsideEntry {
            switch name {
            case "title" where path.count <= 3:
                if feedTitle.isEmpty { feedTitle = text }
            case "link" where path.count <= 3:
                if siteURL == nil, !text.isEmpty { siteURL = text }
            default:
                break
            }
        } else {
            switch name {
            case "title":
                itemTitle = text
            case "link":
                if !text.isEmpty {
                    itemLink = text
                } else if !atomLinkCandidate.isEmpty {
                    itemLink = atomLinkCandidate
                }
            case "description", "summary", "content", "content:encoded":
                if itemSummary.isEmpty || name == "content" || name == "content:encoded" {
                    itemSummary = stripHTML(text)
                }
            case "author", "dc:creator", "name":
                if itemAuthor.isEmpty { itemAuthor = text }
            case "pubdate", "published", "updated", "dc:date":
                if itemDateText.isEmpty || name == "published" || name == "pubdate" {
                    itemDateText = text
                }
            case "item", "entry":
                let link = itemLink.isEmpty ? atomLinkCandidate : itemLink
                let article = RssArticle(
                    title: itemTitle.isEmpty ? "无标题" : itemTitle,
                    link: link,
                    summary: itemSummary,
                    author: itemAuthor.isEmpty ? nil : itemAuthor,
                    publishedAt: parseDate(itemDateText)
                )
                articles.append(article)
            default:
                break
            }
        }

        if path.last == name {
            path.removeLast()
        }
        textBuffer = ""
    }

    private func stripHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parseDate(_ text: String) -> Date? {
        guard !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: text) { return date }

        let rfc = DateFormatter()
        rfc.locale = Locale(identifier: "en_US_POSIX")
        rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let date = rfc.date(from: text) { return date }
        rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return rfc.date(from: text)
    }
}
