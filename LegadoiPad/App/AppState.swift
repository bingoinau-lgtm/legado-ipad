import Foundation
import Combine

enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case bookshelf
    case discover
    case explore
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bookshelf: return "书架"
        case .discover: return "发现"
        case .explore: return "探索"
        case .mine: return "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .bookshelf: return "book.closed.fill"
        case .discover: return "safari.fill"
        case .explore: return "square.grid.3x3.fill"
        case .mine: return "person.fill"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var serverConfig: ServerConfig
    @Published var isConnected = false
    @Published var connectionMessage: String?
    @Published var selectedTab: MainTab = .discover
    @Published var readingBook: SourceBook?
    @Published var selectedPhoneBook: Book?

    let api: LegadoAPIClient

    init() {
        let config = ServerConfig.load()
        self.serverConfig = config
        self.api = LegadoAPIClient(config: config)
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
