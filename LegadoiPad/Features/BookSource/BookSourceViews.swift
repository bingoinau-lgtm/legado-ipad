import SwiftUI

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

struct SourceBookReaderContainer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var sourceStore = BookSourceStore.shared
    @ObservedObject private var bookshelf = LocalBookshelfStore.shared
    @ObservedObject private var settings = ReaderSettings.shared

    @State private var currentBook: SourceBook
    @State private var chapters: [SourceChapter] = []
    @State private var selectedChapter: SourceChapter?
    @State private var content = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showChrome = false
    @State private var showTOC = false
    @State private var showSettings = false
    @State private var showChangeSource = false
    @State private var pageIndex = 0

    init(book: SourceBook) {
        _currentBook = State(initialValue: book)
    }

    private var source: BookSource? {
        sourceStore.sources.first(where: { $0.bookSourceUrl == currentBook.origin })
    }

    private var pages: [String] {
        Self.paginate(content, fontSize: settings.fontSize)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                settings.pageBackground.ignoresSafeArea()

                contentArea(size: geo.size)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        TapGesture().onEnded { _ in
                            // Approximate center toggle; edge turns handled in page mode via overlay.
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showChrome.toggle()
                            }
                        }
                    )

                // Edge turn zones for page mode (won't block vertical scroll much).
                if settings.pageMode == .page && !showChrome {
                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { turnPage(-1) }
                            .frame(width: geo.size.width * 0.25)
                        Spacer(minLength: 0)
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { turnPage(1) }
                            .frame(width: geo.size.width * 0.25)
                    }
                }

                if isLoading {
                    ProgressView()
                        .tint(settings.textColor)
                }

                if showChrome {
                    VStack(spacing: 0) {
                        topBar
                        Spacer()
                        bottomBar
                    }
                    .transition(.opacity)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBar(hidden: !showChrome)
        .sheet(isPresented: $showTOC) { tocSheet }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: $showChangeSource) {
            ChangeSourceSheet(book: currentBook) { selected in
                Task { await switchToBook(selected) }
            }
        }
        .task(id: currentBook.bookUrl) {
            await bootstrap()
        }
        .onDisappear {
            OrientationLockController.shared.mask = .all
            OrientationLockController.shared.apply()
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentArea(size: CGSize) -> some View {
        if let errorMessage, content.isEmpty {
            ContentUnavailableView(
                "无法阅读",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
            .foregroundStyle(settings.textColor)
        } else if settings.pageMode == .scroll {
            ScrollView {
                Text(content)
                    .font(.system(size: settings.fontSize))
                    .foregroundStyle(settings.textColor)
                    .lineSpacing(settings.fontSize * 0.45)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.hidden)
        } else {
            TabView(selection: $pageIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    Text(page)
                        .font(.system(size: settings.fontSize))
                        .foregroundStyle(settings.textColor)
                        .lineSpacing(settings.fontSize * 0.45)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func turnPage(_ delta: Int) {
        let next = pageIndex + delta
        if pages.indices.contains(next) {
            withAnimation { pageIndex = next }
            return
        }
        Task { await go(delta) }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                appState.readingBook = nil
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(settings.chromeBackground.opacity(0.95)))
            }

            Text(currentBook.name)
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            Button {
                showChangeSource = true
            } label: {
                Text("换源")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(Capsule().fill(settings.chromeBackground.opacity(0.95)))
            }

            Button {
                showTOC = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(settings.chromeBackground.opacity(0.95)))
            }
        }
        .foregroundStyle(settings.chromeForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(settings.chromeBackground.opacity(0.96).ignoresSafeArea(edges: .top))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack {
                Button("上一章") { Task { await go(-1) } }
                    .disabled(isLoading)
                Spacer()
                Button {
                    showTOC = true
                } label: {
                    Text(selectedChapter?.title ?? "目录")
                        .lineLimit(1)
                        .frame(maxWidth: 280)
                }
                Spacer()
                Button("下一章") { Task { await go(1) } }
                    .disabled(isLoading)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(settings.chromeForeground)
            .padding(.horizontal, 18)
            .padding(.top, 10)

            HStack(spacing: 18) {
                chromeAction(title: "设置", systemImage: "textformat.size") {
                    showSettings = true
                }
                chromeAction(title: settings.isNight ? "夜间" : "白天", systemImage: settings.isNight ? "moon.fill" : "sun.max.fill") {
                    settings.isNight.toggle()
                }
                chromeAction(title: settings.pageMode.title, systemImage: settings.pageMode == .scroll ? "arrow.up.arrow.down" : "book.pages") {
                    settings.pageMode = settings.pageMode == .scroll ? .page : .scroll
                    pageIndex = 0
                }
                chromeAction(title: "换源", systemImage: "arrow.triangle.2.circlepath") {
                    showChangeSource = true
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .background(settings.chromeBackground.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    private func chromeAction(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(settings.chromeForeground)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sheets

    private var tocSheet: some View {
        NavigationStack {
            List(chapters) { chapter in
                Button {
                    showTOC = false
                    Task { await open(chapter) }
                } label: {
                    HStack {
                        Text(chapter.title)
                            .foregroundStyle(settings.textColor)
                        Spacer()
                        if chapter.id == selectedChapter?.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { showTOC = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("字体") {
                    HStack {
                        Text("A").font(.footnote)
                        Slider(value: $settings.fontSize, in: 14...36, step: 1)
                        Text("A").font(.title3)
                    }
                    Text("当前 \(Int(settings.fontSize)) pt")
                        .foregroundStyle(.secondary)
                }

                Section("主题") {
                    Picker("显示", selection: $settings.isNight) {
                        Text("白天").tag(false)
                        Text("夜间").tag(true)
                    }
                    .pickerStyle(.segmented)
                }

                Section("阅读方式") {
                    Picker("翻页", selection: $settings.pageMode) {
                        ForEach(ReaderPageMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("屏幕方向") {
                    Picker("锁定", selection: $settings.orientationLock) {
                        ForEach(ReaderOrientationLock.allCases) { lock in
                            Text(lock.title).tag(lock)
                        }
                    }
                }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showSettings = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Data

    private func bootstrap() async {
        guard source != nil else {
            errorMessage = "找不到对应书源"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let info = try await BookSourceEngine.loadBook(source: source!, book: currentBook)
            currentBook = info
            bookshelf.add(info)
            chapters = try await BookSourceEngine.loadChapters(source: source!, book: info)
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
        errorMessage = nil
        defer { isLoading = false }
        do {
            content = try await BookSourceEngine.loadContent(source: source, chapter: chapter)
            pageIndex = 0
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

    private func switchToBook(_ book: SourceBook) async {
        showChangeSource = false
        currentBook = book
        bookshelf.add(book)
        appState.readingBook = book
        chapters = []
        content = ""
        selectedChapter = nil
        await bootstrap()
    }

    private static func paginate(_ text: String, fontSize: Double) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [""] }
        // Rough page size for full-screen reading.
        let charsPerPage = max(400, Int(9000 / max(fontSize, 14)))
        var pages: [String] = []
        var start = trimmed.startIndex
        while start < trimmed.endIndex {
            let end = trimmed.index(start, offsetBy: charsPerPage, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
            pages.append(String(trimmed[start..<end]))
            start = end
        }
        return pages.isEmpty ? [trimmed] : pages
    }
}

struct ChangeSourceSheet: View {
    let book: SourceBook
    var onSelect: (SourceBook) -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sourceStore = BookSourceStore.shared
    @State private var candidates: [SourceBook] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && candidates.isEmpty {
                    ProgressView("正在各书源中查找《\(book.name)》…")
                } else if let errorMessage, candidates.isEmpty {
                    ContentUnavailableView("换源失败", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else if candidates.isEmpty {
                    ContentUnavailableView(
                        "没有找到其它源",
                        systemImage: "books.vertical",
                        description: Text("可在「我的 → 书源管理」添加更多书源后再试")
                    )
                } else {
                    List(candidates) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.originName).font(.headline)
                                    if item.origin == book.origin {
                                        Text("当前")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(AppTheme.accent.opacity(0.15)))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                                Text(item.name)
                                    .font(.subheadline)
                                Text(item.author.isEmpty ? "未知作者" : item.author)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let last = item.lastChapter, !last.isEmpty {
                                    Text(last)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("换源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await search() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task { await search() }
        }
    }

    private func search() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var found: [SourceBook] = []
        var lastError: Error?
        let key = book.name

        for source in sourceStore.sources where source.isEnabled {
            do {
                let books = try await BookSourceEngine.search(source: source, key: key)
                let matched = books.filter {
                    $0.name == book.name
                        || $0.name.contains(book.name)
                        || book.name.contains($0.name)
                }
                found.append(contentsOf: matched.isEmpty ? Array(books.prefix(3)) : matched)
            } catch {
                lastError = error
            }
        }

        var seen = Set<String>()
        candidates = found.filter { seen.insert($0.bookUrl).inserted }

        // Always keep current book in list.
        if !candidates.contains(where: { $0.bookUrl == book.bookUrl }) {
            candidates.insert(book, at: 0)
        }

        if candidates.isEmpty {
            errorMessage = lastError?.localizedDescription ?? "未找到可切换的书源"
        }
    }
}
