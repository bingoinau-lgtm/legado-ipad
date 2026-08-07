import SwiftUI

struct DiscoverTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var sourceStore = BookSourceStore.shared
    @ObservedObject private var bookshelf = LocalBookshelfStore.shared
    @ObservedObject private var historyStore = SearchHistoryStore.shared

    @State private var keyword = ""
    @State private var results: [SourceBook] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var toast: String?
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                content
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("发现")
            .navigationDestination(item: $appState.readingBook) { book in
                SourceBookReaderContainer(book: book)
            }
            .overlay(alignment: .top) {
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索书名或作者", text: $keyword)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await search() } }
            if isSearching {
                ProgressView()
            } else {
                Button("搜索") {
                    Task { await search() }
                }
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.accent)
                .disabled(keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
    }

    @ViewBuilder
    private var content: some View {
        if sourceStore.sources.isEmpty {
            ContentUnavailableView(
                "还没有书源",
                systemImage: "server.rack",
                description: Text("先到「我的 → 书源管理」添加书源，再来搜索")
            )
        } else if isSearching && results.isEmpty {
            ProgressView("搜索中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !results.isEmpty {
            resultsList
        } else if let errorMessage, hasSearched {
            VStack(spacing: 16) {
                ContentUnavailableView(
                    "搜索失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
                if !historyStore.keywords.isEmpty {
                    historySection
                }
            }
        } else {
            historyOrEmpty
        }
    }

    private var resultsList: some View {
        List {
            ForEach(results) { book in
                HStack(spacing: 12) {
                    Button {
                        appState.readingBook = book
                    } label: {
                        DiscoverBookRow(book: book)
                    }
                    .buttonStyle(.plain)

                    Button {
                        addToShelf(book)
                    } label: {
                        Image(systemName: bookshelf.contains(book) ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(bookshelf.contains(book) ? .green : AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(Color.white)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 72)
    }

    @ViewBuilder
    private var historyOrEmpty: some View {
        if historyStore.keywords.isEmpty {
            ContentUnavailableView(
                "发现好书",
                systemImage: "safari",
                description: Text("输入书名搜索，再添加到书架")
            )
        } else {
            historySection
        }
    }

    private var historySection: some View {
        List {
            Section {
                ForEach(historyStore.keywords, id: \.self) { item in
                    Button {
                        keyword = item
                        Task { await search() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text(item)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyStore.remove(item)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("搜索历史")
                    Spacer()
                    Button("清空") {
                        historyStore.clear()
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .padding(.bottom, 72)
    }

    private func search() async {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        guard !sourceStore.sources.isEmpty else {
            errorMessage = "请先添加书源"
            return
        }

        historyStore.add(key)
        hasSearched = true
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        var collected: [SourceBook] = []
        var lastError: Error?

        for source in sourceStore.sources where source.isEnabled {
            do {
                let books = try await BookSourceEngine.search(source: source, key: key)
                collected.append(contentsOf: books)
            } catch {
                lastError = error
            }
        }

        var seen = Set<String>()
        results = collected.filter { seen.insert($0.bookUrl).inserted }

        if results.isEmpty {
            errorMessage = lastError?.localizedDescription ?? "没有搜到结果"
        }
    }

    private func addToShelf(_ book: SourceBook) {
        bookshelf.add(book)
        withAnimation {
            toast = "已加入书架"
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation { toast = nil }
        }
    }
}

private struct DiscoverBookRow: View {
    let book: SourceBook

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: book.coverUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "book.closed")
                    }
                }
            }
            .frame(width: 52, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(book.author.isEmpty ? "未知作者" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(book.originName)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
