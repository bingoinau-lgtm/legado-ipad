import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            if let book = appState.selectedBook {
                ReaderView(book: book)
            } else if appState.isConnected {
                ContentUnavailableView(
                    "选择一本书开始阅读",
                    systemImage: "book.closed",
                    description: Text("从左侧书架打开书籍")
                )
            } else {
                ConnectionView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showConnection = false

    var body: some View {
        Group {
            if appState.isConnected {
                BookshelfView()
            } else {
                ContentUnavailableView(
                    "尚未连接手机",
                    systemImage: "wifi.exclamationmark",
                    description: Text("请先配置阅读 App 的 Web 服务地址")
                )
            }
        }
        .navigationTitle("阅读")
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
        }
    }
}
