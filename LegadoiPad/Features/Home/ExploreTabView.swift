import SwiftUI

struct ExploreTabView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "探索",
                systemImage: "square.grid.3x3",
                description: Text("这里先留空，后续再慢慢扩充")
            )
            .background(AppTheme.pageBackground)
            .navigationTitle("探索")
        }
    }
}
