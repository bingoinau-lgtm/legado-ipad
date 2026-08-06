import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch appState.sidebarDestination {
        case .bookSource:
            switch appState.bookSourceSelection {
            case .source(let source):
                BookSourceDetailView(source: source)
            case .book(let book):
                SourceBookReaderContainer(book: book)
            case nil:
                ContentUnavailableView(
                    "书源阅读",
                    systemImage: "server.rack",
                    description: Text("导入书源后搜索或浏览分类，即可直接看书，无需连接手机")
                )
            }
        case .bookshelf:
            if !appState.isConnected {
                ConnectionView()
            } else if let book = appState.selectedBook {
                ReaderView(book: book)
            } else {
                ContentUnavailableView(
                    "选择一本书开始阅读",
                    systemImage: "book.closed",
                    description: Text("从左侧书架打开书籍；书架仍需连接手机 Web 服务")
                )
            }
        case .rss:
            switch appState.rssSelection {
            case .local(let feed):
                LocalRssFeedDetailView(feed: feed)
            case .phone(let source):
                PhoneRssSourceDetailView(source: source)
            case nil:
                ContentUnavailableView(
                    "本机订阅",
                    systemImage: "dot.radiowaves.up.forward",
                    description: Text("点左上角 + 添加网上的 RSS / Atom 地址，无需连接手机")
                )
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showConnection = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("分区", selection: destinationBinding) {
                ForEach(SidebarDestination.allCases) { destination in
                    Text(destination.title).tag(destination)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Group {
                switch appState.sidebarDestination {
                case .bookSource:
                    BookSourcesHomeView()
                case .bookshelf:
                    if appState.isConnected {
                        BookshelfView()
                    } else {
                        ContentUnavailableView(
                            "书架需要连接手机",
                            systemImage: "wifi.exclamationmark",
                            description: Text("书源与订阅可不连手机直接使用")
                        )
                    }
                case .rss:
                    LocalRssFeedsView()
                }
            }
        }
        .navigationTitle(appState.sidebarDestination.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showConnection = true
                } label: {
                    Label(
                        appState.isConnected ? "已连接" : "连接",
                        systemImage: appState.isConnected ? "link.circle.fill" : "link"
                    )
                }
            }
        }
        .sheet(isPresented: $showConnection) {
            NavigationStack {
                ConnectionView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("完成") { showConnection = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var destinationBinding: Binding<SidebarDestination> {
        Binding(
            get: { appState.sidebarDestination },
            set: { appState.selectDestination($0) }
        )
    }
}
