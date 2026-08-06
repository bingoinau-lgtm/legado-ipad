import Foundation

@MainActor
final class RssSourcesViewModel: ObservableObject {
    @Published var sources: [RssSource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var groupedSources: [(group: String, items: [RssSource])] {
        let sorted = sources.sorted {
            let order0 = $0.customOrder ?? Int.max
            let order1 = $1.customOrder ?? Int.max
            if order0 != order1 { return order0 < order1 }
            return $0.sourceName.localizedStandardCompare($1.sourceName) == .orderedAscending
        }
        let dict = Dictionary(grouping: sorted, by: \.displayGroup)
        return dict.keys.sorted().map { key in
            (group: key, items: dict[key] ?? [])
        }
    }

    func load(using api: LegadoAPIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            sources = try await api.getRssSources()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
