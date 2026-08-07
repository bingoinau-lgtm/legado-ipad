import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    private var isReading: Bool {
        appState.readingBook != nil
    }

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

            VStack {
                Spacer()
                if !isReading {
                    FloatingTabBar(selection: $appState.selectedTab)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 12)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isReading)
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selection == tab ? AppTheme.accent : Color.primary.opacity(0.85))
                    .frame(width: 64, height: 48)
                    .background(
                        Capsule()
                            .fill(selection == tab ? AppTheme.tabHighlight : Color.clear)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppTheme.tabBarBackground)
                .shadow(color: .black.opacity(0.10), radius: 14, y: 3)
        )
        // Keep the pill compact and centered like the mockup.
        .fixedSize(horizontal: true, vertical: true)
        .frame(maxWidth: .infinity)
    }
}
