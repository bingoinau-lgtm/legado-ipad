import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            AppTheme.pageBackground.ignoresSafeArea()

            Group {
                switch appState.selectedTab {
                case .bookshelf:
                    BookshelfTabView()
                case .discover:
                    DiscoverTabView()
                case .explore:
                    ExploreTabView()
                case .mine:
                    MineTabView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingTabBar(selection: $appState.selectedTab)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 10)
            }
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? AppTheme.accent : Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(selection == tab ? AppTheme.tabHighlight : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(AppTheme.tabBarBackground)
                .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
        )
    }
}
