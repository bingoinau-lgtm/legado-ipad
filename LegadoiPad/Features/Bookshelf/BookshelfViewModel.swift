import Foundation

@MainActor
final class BookshelfViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(using api: LegadoAPIClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            books = try await api.getBookshelf()
                .sorted { ($0.durChapterTime ?? 0) > ($1.durChapterTime ?? 0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
