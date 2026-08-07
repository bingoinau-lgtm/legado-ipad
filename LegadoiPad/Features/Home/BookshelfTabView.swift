import SwiftUI

struct BookshelfTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var store = LocalBookshelfStore.shared

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 20)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if store.books.isEmpty {
                    ContentUnavailableView(
                        "书架是空的",
                        systemImage: "books.vertical",
                        description: Text("去「发现」搜索书名，加入书架后会显示在这里")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(store.books) { book in
                                Button {
                                    appState.readingBook = book
                                } label: {
                                    BookCoverCard(book: book)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("从书架移除", role: .destructive) {
                                        store.remove(bookUrl: book.bookUrl)
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .padding(.bottom, 72)
                    }
                }
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("书架")
            .navigationDestination(item: $appState.readingBook) { book in
                SourceBookReaderContainer(book: book)
            }
        }
    }
}

private struct BookCoverCard: View {
    let book: SourceBook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: book.coverUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "book.closed.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(book.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(book.author.isEmpty ? book.originName : book.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// Shared theme used by tab pages
enum AppTheme {
    static let pageBackground = Color(red: 0.94, green: 0.94, blue: 0.95)
    static let accent = Color(red: 0.20, green: 0.48, blue: 0.96)
    static let tabBarBackground = Color.white
    static let tabHighlight = Color(red: 0.92, green: 0.92, blue: 0.93)
}
