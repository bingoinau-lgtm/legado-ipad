import Foundation
import Combine

@MainActor
final class LocalBookshelfStore: ObservableObject {
    static let shared = LocalBookshelfStore()

    @Published private(set) var books: [SourceBook] = []

    private let storageKey = "legado.localBookshelf"

    private init() {
        load()
    }

    func contains(_ book: SourceBook) -> Bool {
        books.contains(where: { $0.bookUrl == book.bookUrl })
    }

    func add(_ book: SourceBook) {
        if let index = books.firstIndex(where: { $0.bookUrl == book.bookUrl }) {
            books[index] = book
            books.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
        } else {
            books.insert(book, at: 0)
        }
        save()
    }

    func remove(bookUrl: String) {
        books.removeAll { $0.bookUrl == bookUrl }
        save()
    }

    func remove(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where books.indices.contains(index) {
            books.remove(at: index)
        }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SourceBook].self, from: data) else {
            books = []
            return
        }
        books = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
