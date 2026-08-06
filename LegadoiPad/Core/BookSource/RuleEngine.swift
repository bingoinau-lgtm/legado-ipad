import Foundation
import JavaScriptCore
import SwiftSoup

enum AnalyzeHttp {
    struct Response {
        let url: URL
        let body: String
    }

    static func fetch(
        urlString: String,
        baseURL: URL?,
        defaultHeaders: [String: String] = [:]
    ) async throws -> Response {
        let (absolute, options) = try parseURLAndOptions(urlString, baseURL: baseURL)
        var request = URLRequest(url: absolute)
        request.timeoutInterval = 30
        request.httpMethod = options.method
        var headers = defaultHeaders
        for (key, value) in options.headers {
            headers[key] = value
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let body = options.body {
            request.httpBody = body.data(using: .utf8)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<400).contains(http.statusCode),
                  let text = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                throw BookSourceError.emptyResult("页面请求失败")
            }
            let finalURL = http.url ?? absolute
            return Response(url: finalURL, body: text)
        } catch let error as BookSourceError {
            throw error
        } catch {
            throw BookSourceError.transport(error)
        }
    }

    private struct RequestOptions {
        var method = "GET"
        var body: String?
        var headers: [String: String] = [:]
    }

    private static func parseURLAndOptions(
        _ raw: String,
        baseURL: URL?
    ) throws -> (URL, RequestOptions) {
        var options = RequestOptions()
        var urlPart = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let comma = urlPart.firstIndex(of: ","),
           comma < urlPart.endIndex {
            let after = String(urlPart[urlPart.index(after: comma)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if after.hasPrefix("{"),
               let data = after.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                urlPart = String(urlPart[..<comma]).trimmingCharacters(in: .whitespacesAndNewlines)
                if let method = json["method"] as? String {
                    options.method = method.uppercased()
                }
                if let body = json["body"] as? String {
                    options.body = body
                }
                if let headers = json["headers"] as? [String: String] {
                    options.headers = headers
                }
            }
        }

        guard let url = resolveURL(urlPart, baseURL: baseURL) else {
            throw BookSourceError.invalidURL
        }
        return (url, options)
    }

    static func resolveURL(_ value: String, baseURL: URL?) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }
        guard let baseURL else { return URL(string: trimmed) }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }
}

enum AnalyzeJS {
    static func evalSearchURL(_ scriptWrapped: String, key: String) throws -> String {
        var script = scriptWrapped.trimmingCharacters(in: .whitespacesAndNewlines)
        if script.hasPrefix("<js>"), script.hasSuffix("</js>") {
            script = String(script.dropFirst(4).dropLast(5))
        } else if script.hasPrefix("@js:") {
            script = String(script.dropFirst(4))
        }

        guard let context = JSContext() else {
            throw BookSourceError.rule("无法创建 JS 环境")
        }
        context.exceptionHandler = { _, _ in }
        context.setObject(key, forKeyedSubscript: "key" as NSString)
        let result = context.evaluateScript(script)
        if let exception = context.exception {
            throw BookSourceError.rule("JS 执行失败：\(exception)")
        }
        guard let value = result?.toString(), !value.isEmpty, value != "undefined" else {
            throw BookSourceError.rule("JS 未返回有效 URL")
        }
        return value
    }
}

final class AnalyzeRule {
    private let document: Document
    let baseURL: URL?

    init(html: String, baseURL: URL?) throws {
        self.document = try SwiftSoup.parse(html)
        self.baseURL = baseURL
    }

    func getElements(_ rule: String?) throws -> [Element] {
        guard let rule, !rule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let parts = splitOr(rule)
        var collected: [Element] = []
        for part in parts {
            let els = try selectElements(part.trimmingCharacters(in: .whitespacesAndNewlines))
            if !els.isEmpty {
                collected.append(contentsOf: els)
                // `||` style is handled by splitOr only when explicit; commas merge CSS lists
            }
        }
        return collected
    }

    func getString(_ rule: String?, absoluteURL: Bool = false) throws -> String {
        let list = try getStringList(rule, absoluteURL: absoluteURL)
        if list.isEmpty { return "" }
        if list.count == 1 { return list[0] }
        return list.joined(separator: "\n")
    }

    func getStringList(_ rule: String?, absoluteURL: Bool = false) throws -> [String] {
        guard let rawRule = rule?.trimmingCharacters(in: .whitespacesAndNewlines), !rawRule.isEmpty else {
            return []
        }

        let alternatives = splitOr(rawRule)
        for alternative in alternatives {
            let (selectorPart, replaceRegex, replacement) = splitReplace(alternative)
            let values = try extractValues(selectorPart)
            let mapped = values.compactMap { value -> String? in
                var text = applyReplace(value, regex: replaceRegex, replacement: replacement)
                text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                if absoluteURL, let url = AnalyzeHttp.resolveURL(text, baseURL: baseURL) {
                    return url.absoluteString
                }
                return text
            }
            if !mapped.isEmpty {
                return mapped
            }
        }
        return []
    }

    // MARK: - Private

    private func splitOr(_ rule: String) -> [String] {
        // Support `||` alternatives; keep CSS commas intact.
        if rule.contains("||") {
            return rule.components(separatedBy: "||").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        return [rule]
    }

    private func splitReplace(_ rule: String) -> (String, String?, String) {
        let parts = rule.components(separatedBy: "##")
        let main = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let regex = parts.count > 1 ? parts[1] : nil
        let replacement = parts.count > 2 ? parts[2] : ""
        return (main, regex, replacement)
    }

    private func applyReplace(_ text: String, regex: String?, replacement: String) -> String {
        guard let regex, !regex.isEmpty else { return text }
        guard let expression = try? NSRegularExpression(pattern: regex, options: [.dotMatchesLineSeparators]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: replacement)
    }

    private func extractValues(_ rule: String) throws -> [String] {
        var working = rule
        if working.hasPrefix("@CSS:") {
            working = String(working.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let segments = splitAt(working)
        guard let last = segments.last else { return [] }
        let elementRules = Array(segments.dropLast())
        var elements: [Element] = [document]

        if elementRules.isEmpty {
            // Attribute/text on root
        } else {
            for segment in elementRules {
                var next: [Element] = []
                for element in elements {
                    next.append(contentsOf: try selectSingle(element, rule: segment))
                }
                elements = next
                if elements.isEmpty { return [] }
            }
        }

        return try values(from: elements, lastRule: last)
    }

    private func selectElements(_ rule: String) throws -> [Element] {
        if rule.contains("@") {
            // Rare for lists; treat as CSS if no classic prefix.
            let first = splitAt(rule).first ?? rule
            return try selectSingle(document, rule: first)
        }
        // CSS list like `dl.B,dl.S`
        let selected = try document.select(rule)
        return Array(selected)
    }

    private func splitAt(_ rule: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for ch in rule {
            if ch == "@" {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        parts.append(current)
        return parts.filter { !$0.isEmpty || parts.count == 1 }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private func selectSingle(_ root: Element, rule: String) throws -> [Element] {
        let (before, indexes) = parseIndex(rule)
        let selected: [Element]
        if before.isEmpty {
            selected = Array(root.children())
        } else {
            let pieces = before.split(separator: ".", maxSplits: 1).map(String.init)
            let head = pieces.first ?? before
            switch head {
            case "children":
                selected = Array(root.children())
            case "class":
                let name = pieces.count > 1 ? pieces[1] : ""
                selected = Array(try root.getElementsByClass(name))
            case "tag":
                let name = pieces.count > 1 ? pieces[1] : ""
                selected = Array(try root.getElementsByTag(name))
            case "id":
                let name = pieces.count > 1 ? pieces[1] : ""
                if let el = try root.getElementById(name) {
                    selected = [el]
                } else {
                    selected = []
                }
            case "text":
                let text = pieces.count > 1 ? pieces[1] : ""
                selected = Array(try root.getElementsContainingOwnText(text))
            default:
                selected = Array(try root.select(before))
            }
        }

        guard !indexes.isEmpty else { return selected }
        var result: [Element] = []
        for index in indexes {
            let resolved = index >= 0 ? index : selected.count + index
            if selected.indices.contains(resolved) {
                result.append(selected[resolved])
            }
        }
        return result
    }

    private func parseIndex(_ rule: String) -> (String, [Int]) {
        // Patterns: tag.dd.1 / tag.dd.-1 / class.B
        let parts = rule.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return (rule, []) }

        // If last is Int, treat as index; support leading keywords class/tag/id/text
        if let last = parts.last, let value = Int(last) {
            let before = parts.dropLast().joined(separator: ".")
            return (before, [value])
        }
        return (rule, [])
    }

    private func values(from elements: [Element], lastRule: String) throws -> [String] {
        var texts: [String] = []
        switch lastRule {
        case "text":
            for el in elements {
                let text = try el.text()
                if !text.isEmpty { texts.append(text) }
            }
        case "textNodes":
            for el in elements {
                let nodes = el.textNodes().map { $0.text().trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !nodes.isEmpty {
                    texts.append(nodes.joined(separator: "\n"))
                }
            }
        case "ownText":
            for el in elements {
                let text = el.ownText()
                if !text.isEmpty { texts.append(text) }
            }
        case "html":
            for el in elements {
                try el.select("script").remove()
                try el.select("style").remove()
                let html = try el.outerHtml()
                if !html.isEmpty { texts.append(html) }
            }
        case "all":
            for el in elements {
                let html = try el.outerHtml()
                if !html.isEmpty { texts.append(html) }
            }
        default:
            for el in elements {
                let value = try el.attr(lastRule)
                if !value.isEmpty, !texts.contains(value) {
                    texts.append(value)
                }
            }
        }
        return texts
    }
}

enum HTMLText {
    static func plain(from html: String) -> String {
        guard let doc = try? SwiftSoup.parseBodyFragment(html) else {
            return html
        }
        let text = (try? doc.text()) ?? html
        return text
            .replacingOccurrences(of: "\\s+", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
