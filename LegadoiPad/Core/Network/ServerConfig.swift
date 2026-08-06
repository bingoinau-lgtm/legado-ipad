import Foundation

struct ServerConfig: Codable, Equatable {
    var host: String
    var port: Int

    static let defaultPort = 1122
    private static let storageKey = "legado.serverConfig"

    var baseURLString: String {
        "http://\(host):\(port)"
    }

    var baseURL: URL? {
        URL(string: baseURLString)
    }

    static func load() -> ServerConfig {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(ServerConfig.self, from: data) {
            return decoded
        }
        return ServerConfig(host: "192.168.1.100", port: defaultPort)
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
