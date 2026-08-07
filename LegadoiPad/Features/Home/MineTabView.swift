import SwiftUI

struct MineTabView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var sourceStore = BookSourceStore.shared
    @ObservedObject private var feedStore = LocalRssFeedStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        BookSourceManageView()
                    } label: {
                        settingsLabel(
                            title: "书源管理",
                            subtitle: sourceStore.sources.isEmpty ? "添加书源后即可搜书" : "已有 \(sourceStore.sources.count) 个书源",
                            systemImage: "server.rack"
                        )
                    }

                    NavigationLink {
                        SubscriptionManageView()
                    } label: {
                        settingsLabel(
                            title: "订阅管理",
                            subtitle: feedStore.feeds.isEmpty ? "添加 RSS / Atom 订阅" : "已有 \(feedStore.feeds.count) 个订阅",
                            systemImage: "dot.radiowaves.up.forward"
                        )
                    }
                } header: {
                    Text("内容来源")
                }

                Section {
                    NavigationLink {
                        ConnectionView()
                    } label: {
                        settingsLabel(
                            title: "连接手机",
                            subtitle: appState.isConnected ? "已连接 \(appState.serverConfig.baseURLString)" : "可选：同步手机书架",
                            systemImage: "link"
                        )
                    }
                } header: {
                    Text("同步")
                }

                Section {
                    LabeledContent("版本", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                } header: {
                    Text("关于")
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle("我的")
        }
    }

    private func settingsLabel(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accent)
        }
    }
}

struct BookSourceManageView: View {
    @ObservedObject private var store = BookSourceStore.shared
    @State private var showAdd = false

    var body: some View {
        List {
            if store.sources.isEmpty {
                Text("点右上角 + 导入书源 JSON")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.sources) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(source.bookSourceName).font(.headline)
                        Text(source.displayGroup).font(.caption).foregroundStyle(.secondary)
                        Text(source.bookSourceUrl).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.remove(url: store.sources[index].bookSourceUrl)
                    }
                }
            }
        }
        .navigationTitle("书源管理")
        .navigationBarTitleDisplayMode(.inline)
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
}

struct SubscriptionManageView: View {
    var body: some View {
        LocalRssFeedsView()
            .navigationTitle("订阅管理")
            .navigationBarTitleDisplayMode(.inline)
    }
}
