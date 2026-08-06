import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var chapters: [BookChapter] = []
    @Published var content: String = ""
    @Published var chapterIndex: Int
    @Published var isLoadingChapters = false
    @Published var isLoadingContent = false
    @Published var errorMessage: String?
    @Published var showChapterList = false

    let book: Book
    private let api: LegadoAPIClient

    init(book: Book, api: LegadoAPIClient) {
        self.book = book
        self.api = api
        self.chapterIndex = book.durChapterIndex ?? 0
    }

    var currentChapterTitle: String {
        chapters.first(where: { $0.index == chapterIndex })?.title
            ?? book.durChapterTitle
            ?? "正文"
    }

    func loadChapters() async {
        isLoadingChapters = true
        errorMessage = nil
        defer { isLoadingChapters = false }
        do {
            chapters = try await api.getChapterList(bookUrl: book.bookUrl)
                .filter { !($0.isVolume ?? false) }
            if chapters.isEmpty {
                errorMessage = "目录为空"
                return
            }
            if !chapters.contains(where: { $0.index == chapterIndex }) {
                chapterIndex = chapters[0].index
            }
            await loadContent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadContent() async {
        isLoadingContent = true
        errorMessage = nil
        defer { isLoadingContent = false }
        do {
            content = try await api.getBookContent(bookUrl: book.bookUrl, index: chapterIndex)
            await saveProgress()
        } catch {
            errorMessage = error.localizedDescription
            content = ""
        }
    }

    func goTo(index: Int) async {
        guard index != chapterIndex else { return }
        chapterIndex = index
        showChapterList = false
        await loadContent()
    }

    func goNext() async {
        guard let current = chapters.firstIndex(where: { $0.index == chapterIndex }),
              current + 1 < chapters.count else { return }
        await goTo(index: chapters[current + 1].index)
    }

    func goPrevious() async {
        guard let current = chapters.firstIndex(where: { $0.index == chapterIndex }),
              current > 0 else { return }
        await goTo(index: chapters[current - 1].index)
    }

    private func saveProgress() async {
        let title = chapters.first(where: { $0.index == chapterIndex })?.title
        let progress = BookProgress(
            name: book.name,
            author: book.author,
            durChapterIndex: chapterIndex,
            durChapterPos: 0,
            durChapterTime: Int64(Date().timeIntervalSince1970 * 1000),
            durChapterTitle: title
        )
        try? await api.saveBookProgress(progress)
    }
}
