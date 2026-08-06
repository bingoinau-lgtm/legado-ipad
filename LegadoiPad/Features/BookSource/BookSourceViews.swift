import SwiftUI

struct BookSourcesHomeView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var store = BookSourceStore.shared
    @State private var showAdd = false
    @State private var searchText = ""

    private var filtered: [BookSource] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return store.sources }
        return store.sources.filter {
            $0.bookSourceName.localizedCaseInsensitiveContains(keyword)
                || $0.bookSourceUrl.localizedCaseInsensitiveContains(keyword)
                || ($0.bookSourceGroup?.localizedCaseInsensitiveContains(keyword) ?? false)
        }
    }

    var body: some View {
        List(selection: $appState.bookSourceSelection) {
            if filtered.isEmpty {
                Text("点右上角 + 从网址导入书源 JSON，即可搜书阅读。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filtered) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.bookSourceName)
                            .font(.headline)
                        Text(source.displayGroup)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(source.bookSourceUrl)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                    .tag(BookSourceSelection.source(source))
                }
                .onDelete(perform: delete)
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "搜索书源")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddBookSourceSheet()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let url = filtered[index].bookSourceUrl
            if case .source(let source) = appState.bookSourceSelection, source.bookSourceUrl == url {
                appState.bookSourceSelection = nil
            }
            store.remove(url: url)
        }
    }
}

struct AddBookSourceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = BookSourceStore.shared
    @State private var urlText = "https://www.yckceo.com/yuedu/shuyuan/json/id/7655.json"
    @State private var isWorking = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://.../xxx.json", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("书源 JSON 地址")
                } footer: {
                    Text("支持单个书源或书源数组。示例已填入「五八书阁」。")
                }

                if let message {
                    Section {
                        Text(message)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("添加书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("导入") {
                        Task { await importSources() }
                    }
                    .disabled(isWorking || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isWorking {
                    ProgressView("导入中…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func importSources() async {
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let sources = try await BookSourceImporter.importFromURL(urlText)
            store.add(contentsOf: sources)
            message = "已导入 \(sources.count) 个书源"
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct BookSourceDetailView: View {
    let source: BookSource
    @EnvironmentObject private var appState: AppState
    @State private var keyword = ""
    @State private var books: [SourceBook] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedKind: String?

    private var kinds: [(name: String, url: String)] {
        BookSourceEngine.exploreKinds(source: source)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("输入书名或作者", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await runSearch() } }
                Button("搜索") {
                    Task { await runSearch() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            if !kinds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(kinds.prefix(20), id: \.name) { kind in
                            Button(kind.name) {
                                selectedKind = kind.name
                                Task { await runExplore(kind.url) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
            }

            Group {
                if isLoading && books.isEmpty {
                    ProgressView("加载中…")
                } else if let errorMessage, books.isEmpty {
                    ContentUnavailableView("失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if books.isEmpty {
                    ContentUnavailableView(
                        "搜书或点分类",
                        systemImage: "magnifyingglass",
                        description: Text(source.bookSourceComment ?? "使用该书源搜索网络书籍")
                    )
                } else {
                    List(books) { book in
                        Button {
                            appState.bookSourceSelection = .book(book)
                        } label: {
                            SourceBookRow(book: book)
                        }
                    }
                }
            }
        }
        .navigationTitle(source.bookSourceName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runSearch() async {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            books = try await BookSourceEngine.search(source: source, key: key)
            if books.isEmpty {
                errorMessage = "没有搜到结果"
            }
        } catch {
            books = []
            errorMessage = error.localizedDescription
        }
    }

    private func runExplore(_ path: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            books = try await BookSourceEngine.explore(source: source, path: path)
            if books.isEmpty {
                errorMessage = "分类下没有书籍"
            }
        } catch {
            books = []
            errorMessage = error.localizedDescription
        }
    }
}

private struct SourceBookRow: View {
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
            .frame(width: 48, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.name).font(.headline).lineLimit(1)
                Text(book.author.isEmpty ? "未知作者" : book.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let last = book.lastChapter, !last.isEmpty {
                    Text(last).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct SourceBookReaderContainer: View {
    let book: SourceBook
    @ObservedObject private var store = BookSourceStore.shared
    @State private var detail: SourceBook?
    @State private var chapters: [SourceChapter] = []
    @State private var selectedChapter: SourceChapter?
    @State private var content = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showTOC = false

    private var source: BookSource? {
        store.sources.first(where: { $0.bookSourceUrl == book.origin })
    }

    var body: some View {
        Group {
            if isLoading && content.isEmpty && chapters.isEmpty {
                ProgressView("打开书籍…")
            } else if let errorMessage, content.isEmpty {
                ContentUnavailableView("无法阅读", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
            } else {
                ScrollView {
                    Text(content.isEmpty ? "请从目录选择章节" : content)
                        .font(.system(size: 20))
                        .lineSpacing(8)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(28)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(detail?.name ?? book.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showTOC = true
                } label: {
                    Image(systemName: "list.bullet")
                }
                .disabled(chapters.isEmpty)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !chapters.isEmpty {
                HStack {
                    Button("上一章") { Task { await go(-1) } }
                    Spacer()
                    Text(selectedChapter?.title ?? "目录")
                        .lineLimit(1)
                        .frame(maxWidth: 260)
                    Spacer()
                    Button("下一章") { Task { await go(1) } }
                }
                .padding()
                .background(.bar)
            }
        }
        .sheet(isPresented: $showTOC) {
            NavigationStack {
                List(chapters) { chapter in
                    Button(chapter.title) {
                        showTOC = false
                        Task { await open(chapter) }
                    }
                }
                .navigationTitle("目录")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭") { showTOC = false }
                    }
                }
            }
        }
        .task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        guard let source else {
            errorMessage = "找不到对应书源"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let info = try await BookSourceEngine.loadBook(source: source, book: book)
            detail = info
            chapters = try await BookSourceEngine.loadChapters(source: source, book: info)
            if let first = chapters.first {
                await open(first)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func open(_ chapter: SourceChapter) async {
        guard let source else { return }
        selectedChapter = chapter
        isLoading = true
        defer { isLoading = false }
        do {
            content = try await BookSourceEngine.loadContent(source: source, chapter: chapter)
        } catch {
            errorMessage = error.localizedDescription
            content = ""
        }
    }

    private func go(_ delta: Int) async {
        guard let selectedChapter,
              let index = chapters.firstIndex(of: selectedChapter) else { return }
        let next = index + delta
        guard chapters.indices.contains(next) else { return }
        await open(chapters[next])
    }
}
