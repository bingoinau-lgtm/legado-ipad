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
        if !appState.isConnected {
            ConnectionView()
        } else {
            switch appState.sidebarDestination {
            case .bookshelf:
                if let book = appState.selectedBook {
                    ReaderView(book: book)
                } else {
                    ContentUnavailableView(
                        "选择一本书开始阅读",
                        systemImage: "book.closed",
                        description: Text("从左侧书架打开书籍")
                    )
                }
            case .rss:
                if let source = appState.selectedRssSource {
                    RssSourceDetailView(source: source)
                } else {
                    ContentUnavailableView(
                        "选择一个订阅源",
                        systemImage: "dot.radiowaves.up.forward",
                        description: Text("从左侧订阅列表查看详情")
                    )
                }
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
                    Label(destination.title, systemImage: destination.systemImage)
                        .tag(destination)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Group {
                if appState.isConnected {
                    switch appState.sidebarDestination {
                    case .bookshelf:
                        BookshelfView()
                    case .rss:
                        RssSourcesView()
                    }
                } else {
                    ContentUnavailableView(
                        "尚未连接服务",
                        systemImage: "wifi.exclamationmark",
                        description: Text("请先配置阅读 Web 服务地址")
                    )
                }
            }
        }
        .navigationTitle(appState.sidebarDestination.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showConnection = true
                } label: {
                    Label("连接", systemImage: "link")
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
