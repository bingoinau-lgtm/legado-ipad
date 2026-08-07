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
