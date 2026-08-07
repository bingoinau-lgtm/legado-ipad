import SwiftUI

struct BookshelfView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = BookshelfViewModel()
    @State private var searchText = ""

    private var filteredBooks: [Book] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return viewModel.books }
        return viewModel.books.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.author.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.books.isEmpty {
                ProgressView("加载书架…")
            } else if let error = viewModel.errorMessage, viewModel.books.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if filteredBooks.isEmpty {
                ContentUnavailableView(
                    "书架为空",
                    systemImage: "books.vertical",
                    description: Text("手机书架暂无书籍，或搜索无结果")
                )
            } else {
                List(filteredBooks, selection: $appState.selectedPhoneBook) { book in
                    BookRowView(book: book)
                        .tag(book)
                }
                .listStyle(.sidebar)
            }
        }
        .searchable(text: $searchText, prompt: "搜索书名或作者")
        .refreshable {
            await viewModel.load(using: appState.api)
        }
        .task(id: appState.serverConfig) {
            guard appState.isConnected else { return }
            await viewModel.load(using: appState.api)
        }
    }
}

private struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: book.displayCoverURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.15)
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 44, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "未知作者" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(book.progressText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
