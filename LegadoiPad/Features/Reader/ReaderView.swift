import SwiftUI

struct ReaderView: View {
    @EnvironmentObject private var appState: AppState
    let book: Book
    @StateObject private var box = ReaderVMBox()

    var body: some View {
        Group {
            if let viewModel = box.viewModel {
                ReaderContentView(viewModel: viewModel)
            } else {
                ProgressView("打开书籍…")
            }
        }
        .task(id: book.bookUrl) {
            let vm = ReaderViewModel(book: book, api: appState.api)
            box.viewModel = vm
            await vm.loadChapters()
        }
    }
}

@MainActor
final class ReaderVMBox: ObservableObject {
    @Published var viewModel: ReaderViewModel?
}

struct ReaderContentView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @State private var fontSize: Double = 20
    @State private var lineSpacing: Double = 8

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingContent && viewModel.content.isEmpty {
                Spacer()
                ProgressView("加载正文…")
                Spacer()
            } else if let error = viewModel.errorMessage, viewModel.content.isEmpty {
                ContentUnavailableView(
                    "无法阅读",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ScrollView {
                    Text(viewModel.content)
                        .font(.system(size: fontSize))
                        .lineSpacing(lineSpacing)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        .textSelection(.enabled)
                }
            }

            Divider()
            HStack {
                Button {
                    Task { await viewModel.goPrevious() }
                } label: {
                    Label("上一章", systemImage: "chevron.left")
                }
                .disabled(viewModel.isLoadingContent)

                Spacer()

                Button {
                    viewModel.showChapterList = true
                } label: {
                    Text(viewModel.currentChapterTitle)
                        .lineLimit(1)
                        .frame(maxWidth: 280)
                }

                Spacer()

                Button {
                    Task { await viewModel.goNext() }
                } label: {
                    HStack {
                        Text("下一章")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(viewModel.isLoadingContent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
        .navigationTitle(viewModel.book.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showChapterList = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Slider(value: $fontSize, in: 16...32, step: 1)
                    .frame(width: 140)
            }
        }
        .sheet(isPresented: $viewModel.showChapterList) {
            ChapterListView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.isLoadingContent && !viewModel.content.isEmpty {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct ChapterListView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(viewModel.chapters) { chapter in
                Button {
                    Task {
                        await viewModel.goTo(index: chapter.index)
                        dismiss()
                    }
                } label: {
                    HStack {
                        Text(chapter.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if chapter.index == viewModel.chapterIndex {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
