import Foundation
import Combine

enum SidebarDestination: String, CaseIterable, Identifiable, Hashable {
    case bookshelf
    case rss

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookshelf: return "书架"
        case .rss: return "订阅"
        }
    }

    var systemImage: String {
        switch self {
        case .bookshelf: return "books.vertical"
        case .rss: return "dot.radiowaves.up.forward"
        }
    }
}

enum RssSelection: Hashable {
    case local(LocalRssFeed)
    case phone(RssSource)
}

@MainActor
final class AppState: ObservableObject {
    @Published var serverConfig: ServerConfig
    @Published var isConnected = false
    @Published var connectionMessage: String?
    @Published var sidebarDestination: SidebarDestination = .rss
    @Published var selectedBook: Book?
    @Published var rssSelection: RssSelection?

    let api: LegadoAPIClient

    init() {
        let config = ServerConfig.load()
        self.serverConfig = config
        self.api = LegadoAPIClient(config: config)
    }

    func selectDestination(_ destination: SidebarDestination) {
        guard sidebarDestination != destination else { return }
        sidebarDestination = destination
        selectedBook = nil
        rssSelection = nil
    }

    func updateServer(host: String, port: Int) async {
        var next = serverConfig
        next.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        next.port = port
        serverConfig = next
        next.save()
        await api.update(config: next)
        isConnected = false
        connectionMessage = nil
        selectedBook = nil
        rssSelection = nil
    }

    func testConnection() async {
        connectionMessage = "正在连接…"
        do {
            _ = try await api.getBookshelf()
            isConnected = true
            connectionMessage = "已连接 \(serverConfig.baseURLString)"
        } catch {
            isConnected = false
            connectionMessage = error.localizedDescription
        }
    }
}
