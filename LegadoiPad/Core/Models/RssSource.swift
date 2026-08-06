import Foundation

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
