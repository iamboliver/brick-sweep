import SwiftUI

struct PartFilterBar: View {
    @Binding var filter: PartFilter
    var allCount: Int = 0
    var missingCount: Int = 0
    var accountedCount: Int = 0

    var body: some View {
        Picker("Filter", selection: $filter.animation(AppTheme.Animation.snappy)) {
            Text("All (\(allCount))").tag(PartFilter.all)
            Text("Missing (\(missingCount))").tag(PartFilter.missing)
            Text("Found (\(accountedCount))").tag(PartFilter.untouched)
        }
        .pickerStyle(.segmented)
    }
}
