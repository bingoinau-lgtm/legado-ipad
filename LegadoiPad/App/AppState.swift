import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var serverConfig: ServerConfig
    @Published var isConnected = false
    @Published var connectionMessage: String?
    @Published var selectedBook: Book?

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
