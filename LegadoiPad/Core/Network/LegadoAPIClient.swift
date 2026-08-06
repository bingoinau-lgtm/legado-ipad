import Foundation

actor LegadoAPIClient {
    private var config: ServerConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    init(config: ServerConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
        self.decoder = JSONDecoder()
    }

    func update(config: ServerConfig) {
        self.config = config
    }

    func getBookshelf() async throws -> [Book] {
        try await get(path: "/getBookshelf")
    }

    func getChapterList(bookUrl: String) async throws -> [BookChapter] {
        try await get(path: "/getChapterList", query: ["url": bookUrl])
    }

    func getBookContent(bookUrl: String, index: Int) async throws -> String {
        try await get(path: "/getBookContent", query: [
            "url": bookUrl,
            "index": String(index)
        ])
    }

    func saveBookProgress(_ progress: BookProgress) async throws {
        struct OK: Decodable {}
        let _: OK? = try await postOptional(path: "/saveBookProgress", body: progress)
    }

    // MARK: - Private

    private func get<T: Decodable>(path: String, query: [String: String] = [:]) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", query: query)
        return try await sendRequired(request)
    }

    private func postOptional<Body: Encodable, T: Decodable>(path: String, body: Body) async throws -> T? {
        var request = try makeRequest(path: path, method: "POST")
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await sendOptional(request)
    }

    private func makeRequest(
        path: String,
        method: String,
        query: [String: String] = [:]
    ) throws -> URLRequest {
        guard var components = URLComponents(string: config.baseURLString + path) else {
            throw LegadoAPIError.invalidURL
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw LegadoAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        return request
    }

    private func sendRequired<T: Decodable>(_ request: URLRequest) async throws -> T {
        let envelope: APIResponse<T> = try await fetchEnvelope(request)
        guard envelope.isSuccess else {
            throw LegadoAPIError.server(envelope.errorMsg ?? "请求失败")
        }
        guard let data = envelope.data else {
            throw LegadoAPIError.server(envelope.errorMsg ?? "无数据")
        }
        return data
    }

    private func sendOptional<T: Decodable>(_ request: URLRequest) async throws -> T? {
        let envelope: APIResponse<T> = try await fetchEnvelope(request)
        guard envelope.isSuccess else {
            throw LegadoAPIError.server(envelope.errorMsg ?? "请求失败")
        }
        return envelope.data
    }

    private func fetchEnvelope<T: Decodable>(_ request: URLRequest) async throws -> APIResponse<T> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LegadoAPIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LegadoAPIError.invalidResponse
        }

        do {
            return try decoder.decode(APIResponse<T>.self, from: data)
        } catch {
            throw LegadoAPIError.decoding(error)
        }
    }
}
