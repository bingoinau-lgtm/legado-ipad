import SwiftUI

struct RssSourcesView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = RssSourcesViewModel()
    @State private var searchText = ""
    @State private var showDisabled = true

    private var filteredGroups: [(group: String, items: [RssSource])] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return viewModel.groupedSources.compactMap { section in
            let items = section.items.filter { source in
                if !showDisabled && !source.isEnabled { return false }
                guard !keyword.isEmpty else { return true }
                return source.sourceName.localizedCaseInsensitiveContains(keyword)
                    || source.sourceUrl.localizedCaseInsensitiveContains(keyword)
                    || (source.sourceGroup?.localizedCaseInsensitiveContains(keyword) ?? false)
            }
            guard !items.isEmpty else { return nil }
            return (group: section.group, items: items)
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.sources.isEmpty {
                ProgressView("加载订阅源…")
            } else if let error = viewModel.errorMessage, viewModel.sources.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if filteredGroups.isEmpty {
                ContentUnavailableView(
                    "暂无订阅源",
                    systemImage: "dot.radiowaves.up.forward",
                    description: Text("手机端添加订阅源后下拉刷新即可同步")
                )
            } else {
                List(selection: $appState.selectedRssSource) {
                    ForEach(filteredGroups, id: \.group) { section in
                        Section(section.group) {
                            ForEach(section.items) { source in
                                RssSourceRowView(source: source)
                                    .tag(source)
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .searchable(text: $searchText, prompt: "搜索订阅源")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $showDisabled) {
                    Image(systemName: showDisabled ? "eye" : "eye.slash")
                }
                .help(showDisabled ? "隐藏已禁用" : "显示已禁用")
            }
        }
        .refreshable {
            await viewModel.load(using: appState.api)
        }
        .task(id: appState.serverConfig) {
            guard appState.isConnected else { return }
            await viewModel.load(using: appState.api)
        }
    }
}

private struct RssSourceRowView: View {
    let source: RssSource

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: source.sourceIcon ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Image(systemName: "dot.radiowaves.up.forward")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(source.sourceName)
                        .font(.headline)
                        .lineLimit(1)
                    if !source.isEnabled {
                        Text("禁用")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }
                Text(source.sourceUrl)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .opacity(source.isEnabled ? 1 : 0.55)
    }
}

struct RssSourceDetailView: View {
    let source: RssSource

    var body: some View {
        List {
            Section("基本信息") {
                LabeledContent("名称", value: source.sourceName)
                LabeledContent("分组", value: source.displayGroup)
                LabeledContent("状态", value: source.isEnabled ? "启用" : "禁用")
                LabeledContent("地址") {
                    Text(source.sourceUrl)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }

            if let comment = source.sourceComment, !comment.isEmpty {
                Section("注释") {
                    Text(comment)
                }
            }

            Section {
                Text("当前版本仅同步订阅源列表。文章抓取与阅读将在后续版本加入。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(source.sourceName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
