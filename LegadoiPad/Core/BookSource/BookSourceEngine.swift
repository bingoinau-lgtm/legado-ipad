import Foundation

@MainActor
final class BookSourceStore: ObservableObject {
    static let shared = BookSourceStore()

    @Published private(set) var sources: [BookSource] = []

    private let storageKey = "legado.bookSources"

    private init() {
        load()
    }

    func add(_ source: BookSource) {
        if let index = sources.firstIndex(where: { $0.bookSourceUrl == source.bookSourceUrl }) {
            sources[index] = source
        } else {
            sources.insert(source, at: 0)
        }
        save()
    }

    func add(contentsOf list: [BookSource]) {
        for source in list {
            add(source)
        }
    }

    func remove(url: String) {
        sources.removeAll { $0.bookSourceUrl == url }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BookSource].self, from: data) else {
            sources = []
            return
        }
        sources = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

enum BookSourceImporter {
    static func importFromURL(_ urlString: String) async throws -> [BookSource] {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw BookSourceError.invalidURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BookSourceError.emptyResult("下载书源失败")
        }
        return try decodeSources(from: data)
    }

    static func decodeSources(from data: Data) throws -> [BookSource] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([BookSource].self, from: data) {
            return list.filter { !$0.bookSourceUrl.isEmpty && !$0.bookSourceName.isEmpty }
        }
        if let single = try? decoder.decode(BookSource.self, from: data) {
            return [single]
        }
        throw BookSourceError.rule("无法识别书源 JSON")
    }
}

enum BookSourceEngine {
    static func search(source: BookSource, key: String) async throws -> [SourceBook] {
        guard let searchUrl = source.searchUrl, !searchUrl.isEmpty else {
            throw BookSourceError.rule("该书源未配置搜索")
        }
        let resolved: String
        if searchUrl.contains("<js>") || searchUrl.hasPrefix("@js:") {
            resolved = try AnalyzeJS.evalSearchURL(searchUrl, key: key)
        } else {
            resolved = searchUrl
                .replacingOccurrences(of: "{{key}}", with: key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)
                .replacingOccurrences(of: "{{page}}", with: "1")
        }

        let headers = parseHeaders(source.header)
        let base = URL(string: source.bookSourceUrl)
        let response = try await AnalyzeHttp.fetch(urlString: resolved, baseURL: base, defaultHeaders: headers)
        let rule = try AnalyzeRule(html: response.body, baseURL: response.url)
        return try parseBookList(rule: rule, listRule: source.ruleSearch, source: source)
    }

    static func explore(source: BookSource, path: String) async throws -> [SourceBook] {
        let headers = parseHeaders(source.header)
        let base = URL(string: source.bookSourceUrl)
        let pagePath = path.replacingOccurrences(of: "{{page}}", with: "1")
        let response = try await AnalyzeHttp.fetch(urlString: pagePath, baseURL: base, defaultHeaders: headers)
        let rule = try AnalyzeRule(html: response.body, baseURL: response.url)
        let listRule = source.ruleExplore ?? source.ruleSearch
        return try parseBookList(rule: rule, listRule: listRule, source: source)
    }

    static func exploreKinds(source: BookSource) -> [(name: String, url: String)] {
        guard let exploreUrl = source.exploreUrl else { return [] }
        var result: [(String, String)] = []
        for line in exploreUrl.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.contains("::") else { continue }
            let parts = trimmed.components(separatedBy: "::")
            guard parts.count >= 2 else { continue }
            let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let url = parts[1...].joined(separator: "::").trimmingCharacters(in: .whitespacesAndNewlines)
            if name.contains("—") || name.isEmpty || url.isEmpty { continue }
            result.append((name, url))
        }
        return result
    }

    static func loadBook(source: BookSource, book: SourceBook) async throws -> SourceBook {
        let headers = parseHeaders(source.header)
        let response = try await AnalyzeHttp.fetch(
            urlString: book.bookUrl,
            baseURL: URL(string: source.bookSourceUrl),
            defaultHeaders: headers
        )
        let rule = try AnalyzeRule(html: response.body, baseURL: response.url)
        let info = source.ruleBookInfo
        var updated = book
        let name = try rule.getString(info?.name)
        if !name.isEmpty { updated.name = name }
        let author = try rule.getString(info?.author)
        if !author.isEmpty { updated.author = author }
        let intro = try rule.getString(info?.intro)
        if !intro.isEmpty { updated.intro = intro }
        let kind = try rule.getString(info?.kind)
        if !kind.isEmpty { updated.kind = kind }
        let last = try rule.getString(info?.lastChapter)
        if !last.isEmpty { updated.lastChapter = last }
        let cover = try rule.getString(info?.coverUrl, absoluteURL: true)
        if !cover.isEmpty { updated.coverUrl = cover }
        let toc = try rule.getString(info?.tocUrl, absoluteURL: true)
        if !toc.isEmpty {
            updated.tocUrl = toc
        } else {
            updated.tocUrl = book.bookUrl
        }
        return updated
    }

    static func loadChapters(source: BookSource, book: SourceBook) async throws -> [SourceChapter] {
        let tocURL = book.tocUrl ?? book.bookUrl
        let headers = parseHeaders(source.header)
        let response = try await AnalyzeHttp.fetch(
            urlString: tocURL,
            baseURL: URL(string: source.bookSourceUrl),
            defaultHeaders: headers
        )
        let rule = try AnalyzeRule(html: response.body, baseURL: response.url)
        guard let listRule = source.ruleToc?.chapterList else {
            throw BookSourceError.rule("未配置目录规则")
        }
        let elements = try rule.getElements(listRule)
        var chapters: [SourceChapter] = []
        for (index, element) in elements.enumerated() {
            let html = try element.outerHtml()
            let itemRule = try AnalyzeRule(html: html, baseURL: response.url)
            let title = try itemRule.getString(source.ruleToc?.chapterName)
            let url = try itemRule.getString(source.ruleToc?.chapterUrl, absoluteURL: true)
            guard !title.isEmpty, !url.isEmpty else { continue }
            chapters.append(SourceChapter(title: title, url: url, index: index))
        }
        if chapters.isEmpty {
            throw BookSourceError.emptyResult("未解析到章节")
        }
        return chapters
    }

    static func loadContent(source: BookSource, chapter: SourceChapter) async throws -> String {
        let headers = parseHeaders(source.header)
        var url = chapter.url
        var pages: [String] = []
        var guardCount = 0

        while guardCount < 20 {
            guardCount += 1
            let response = try await AnalyzeHttp.fetch(
                urlString: url,
                baseURL: URL(string: source.bookSourceUrl),
                defaultHeaders: headers
            )
            let rule = try AnalyzeRule(html: response.body, baseURL: response.url)
            let html = try rule.getString(source.ruleContent?.content)
            let plain = HTMLText.plain(from: html)
            if !plain.isEmpty {
                pages.append(plain)
            }
            let next = try rule.getString(source.ruleContent?.nextContentUrl, absoluteURL: true)
            if next.isEmpty || next == url || next == response.url.absoluteString {
                break
            }
            url = next
        }

        let text = pages.joined(separator: "\n\n")
        if text.isEmpty {
            throw BookSourceError.emptyResult("正文为空")
        }
        return text
    }

    // MARK: - Helpers

    private static func parseBookList(
        rule: AnalyzeRule,
        listRule: BookListRule?,
        source: BookSource
    ) throws -> [SourceBook] {
        guard let bookList = listRule?.bookList, !bookList.isEmpty else {
            throw BookSourceError.rule("未配置书列表规则")
        }
        let elements = try rule.getElements(bookList)
        var books: [SourceBook] = []
        for element in elements {
            let html = try element.outerHtml()
            let item = try AnalyzeRule(html: html, baseURL: rule.baseURL)
            let name = try item.getString(listRule?.name)
            let bookUrl = try item.getString(listRule?.bookUrl, absoluteURL: true)
            guard !name.isEmpty, !bookUrl.isEmpty else { continue }
            let book = SourceBook(
                name: name,
                author: (try? item.getString(listRule?.author)) ?? "",
                bookUrl: bookUrl,
                coverUrl: try? item.getString(listRule?.coverUrl, absoluteURL: true),
                intro: try? item.getString(listRule?.intro),
                kind: try? item.getString(listRule?.kind),
                lastChapter: try? item.getString(listRule?.lastChapter),
                origin: source.bookSourceUrl,
                originName: source.bookSourceName,
                tocUrl: nil
            )
            books.append(book)
        }
        return books
    }

    private static func parseHeaders(_ raw: String?) -> [String: String] {
        guard let raw, let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [
                "User-Agent": "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
            ]
        }
        return json
    }
}
