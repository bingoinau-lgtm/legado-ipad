import SwiftUI
import SafariServices

struct LocalRssFeedsView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var store = LocalRssFeedStore.shared
    @StateObject private var phoneSources = RssSourcesViewModel()
    @State private var showAddSheet = false
    @State private var searchText = ""

    private var filteredLocalFeeds: [LocalRssFeed] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return store.feeds }
        return store.feeds.filter {
            $0.title.localizedCaseInsensitiveContains(keyword)
                || $0.feedURL.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        List(selection: selectionBinding) {
            Section {
                if filteredLocalFeeds.isEmpty {
                    Text("添加网上的 RSS / Atom 地址即可直接阅读，无需连接手机。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredLocalFeeds) { feed in
                        LocalFeedRowView(feed: feed)
                            .tag(RssSelection.local(feed))
                    }
                    .onDelete(perform: deleteLocal)
                }
            } header: {
                Text("本机订阅")
            }

            if appState.isConnected {
                Section("手机同步（规则源）") {
                    if phoneSources.isLoading && phoneSources.sources.isEmpty {
                        ProgressView()
                    } else if phoneSources.sources.isEmpty {
                        Text("手机上暂无订阅源")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(phoneSources.sources) { source in
                            RssSourceRowView(source: source)
                                .tag(RssSelection.phone(source))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, prompt: "搜索订阅")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("添加订阅")
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddLocalRssFeedSheet()
        }
        .refreshable {
            if appState.isConnected {
                await phoneSources.load(using: appState.api)
            }
        }
        .task(id: appState.isConnected) {
            if appState.isConnected {
                await phoneSources.load(using: appState.api)
            }
        }
    }

    private var selectionBinding: Binding<RssSelection?> {
        Binding(
            get: { appState.rssSelection },
            set: { appState.rssSelection = $0 }
        )
    }

    private func deleteLocal(at offsets: IndexSet) {
        let urls = offsets.map { filteredLocalFeeds[$0].feedURL }
        for url in urls {
            if case .local(let feed) = appState.rssSelection, feed.feedURL == url {
                appState.rssSelection = nil
            }
            store.remove(feedURL: url)
        }
    }
}

private struct LocalFeedRowView: View {
    let feed: LocalRssFeed

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(feed.title)
                .font(.headline)
                .lineLimit(1)
            Text(feed.feedURL)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

struct RssSourceRowView: View {
    let source: RssSource

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: source.sourceIcon ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
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
                Text(source.sourceName)
                    .font(.headline)
                    .lineLimit(1)
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

struct AddLocalRssFeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LocalRssFeedStore.shared
    @State private var urlText = ""
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/feed.xml", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } header: {
                    Text("RSS / Atom 地址")
                } footer: {
                    Text("填写网上公开的订阅地址。阅读 App 的「规则订阅源」JSON 仍需手机规则引擎，本机暂不支持。")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("添加订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        Task { await addFeed() }
                    }
                    .disabled(isWorking || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .overlay {
                if isWorking {
                    ProgressView("校验订阅…")
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func addFeed() async {
        let raw = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            let parsed = try await RssFeedClient.fetch(feedURLString: raw)
            let feed = LocalRssFeed(
                title: parsed.title,
                feedURL: raw,
                siteURL: parsed.siteURL
            )
            store.add(feed)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LocalRssFeedDetailView: View {
    let feed: LocalRssFeed
    @StateObject private var viewModel = LocalRssViewModel()
    @State private var articleURL: URL?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.articles.isEmpty {
                ProgressView("拉取文章…")
            } else if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
                ContentUnavailableView(
                    "无法加载",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                List(viewModel.articles) { article in
                    Button {
                        if let url = URL(string: article.link) {
                            articleURL = url
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(article.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            if !article.summary.isEmpty {
                                Text(article.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            HStack {
                                if let author = article.author, !author.isEmpty {
                                    Text(author)
                                }
                                if let date = article.publishedAt {
                                    Text(dateFormatter.string(from: date))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(viewModel.feedTitle.isEmpty ? feed.title : viewModel.feedTitle)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.load(feed: feed)
        }
        .task(id: feed.feedURL) {
            await viewModel.load(feed: feed)
        }
        .sheet(item: Binding(
            get: { articleURL.map(IdentifiableURL.init) },
            set: { articleURL = $0?.url }
        )) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}

struct PhoneRssSourceDetailView: View {
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
            Section {
                Text("这是手机上的阅读「规则订阅源」。要在不连手机时阅读，请改用左侧「本机订阅」添加标准 RSS / Atom 地址。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(source.sourceName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
