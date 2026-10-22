import SwiftUI

struct ThemeSetListView: View {
    let group: ThemeGroup

    var body: some View {
        List {
            Section {
                SummaryHeaderView(stats: [
                    StatCard(icon: "square.stack.3d.up.fill", value: group.setCount, label: "Sets", iconColor: AppTheme.legoYellow),
                    StatCard(icon: "exclamationmark.triangle.fill", value: group.missingTypeCount, label: "Missing", iconColor: AppTheme.legoRed),
                ])
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(group.sets) { legoSet in
                    NavigationLink(value: legoSet) {
                        SetRowView(legoSet: legoSet)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
