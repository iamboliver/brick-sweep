import SwiftUI

struct PartListView: View {
    @Bindable var legoSet: LegoSet
    @State private var viewModel = PartListViewModel()
    @State private var showResetConfirmation = false

    private var missingCount: Int {
        legoSet.parts.filter { $0.missingQty > 0 }.count
    }

    private var accountedCount: Int {
        legoSet.parts.count - missingCount
    }

    var body: some View {
        let filtered = viewModel.filteredParts(legoSet.parts)

        VStack(spacing: 0) {
            // Summary header
            if !legoSet.isImporting || !legoSet.parts.isEmpty {
                HStack(spacing: AppTheme.Spacing.lg) {
                    CompletionRing(
                        completed: legoSet.isImporting ? legoSet.parts.count : accountedCount,
                        total: legoSet.isImporting ? legoSet.numParts : legoSet.parts.count,
                        size: 52
                    )

                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        if legoSet.isImporting {
                            Text("\(legoSet.parts.count) of \(legoSet.numParts) parts loaded")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(.secondary)
                        } else if missingCount > 0 {
                            Text("\(missingCount) of \(legoSet.parts.count) parts missing")
                                .font(AppTheme.Typography.headline)
                        } else {
                            Text("All \(legoSet.parts.count) parts accounted for")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(AppTheme.completedGreen)
                        }
                    }

                    Spacer()

                    if legoSet.isImporting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.legoYellow)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, AppTheme.Spacing.md)

                PartFilterBar(
                    filter: $viewModel.filter,
                    allCount: legoSet.parts.count,
                    missingCount: missingCount,
                    accountedCount: accountedCount
                )
                .padding(.horizontal)
                .padding(.bottom, AppTheme.Spacing.sm)
            }

            if filtered.isEmpty && !viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            } else if filtered.isEmpty && legoSet.isImporting {
                ContentUnavailableView {
                    Label("Loading Parts", systemImage: "arrow.trianglehead.2.clockwise")
                } description: {
                    Text("Parts are being fetched and will appear shortly.")
                }
            } else if filtered.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: emptyIcon)
                } description: {
                    Text(emptyDescription)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: AppTheme.Spacing.sm) {
                        ForEach(filtered) { part in
                            PartCardView(part: part)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
        .animation(AppTheme.Animation.snappy, value: viewModel.filter)
        .animation(AppTheme.Animation.snappy, value: viewModel.sortOption)
        .searchable(text: $viewModel.searchText, prompt: "Search by part number")
        .keyboardType(.numbersAndPunctuation)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(legoSet.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    Text(legoSet.setNum)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $viewModel.sortOption) {
                        ForEach(PartSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }

                    Divider()

                    Button("Mark All Present", systemImage: "checkmark.circle") {
                        showResetConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Reset All Parts", isPresented: $showResetConfirmation) {
            Button("Mark All Present", role: .destructive) {
                viewModel.resetAllParts(legoSet.parts)
            }
        } message: {
            Text("This will reset all missing counts to zero.")
        }
    }

    private var emptyTitle: String {
        switch viewModel.filter {
        case .all: "No Parts"
        case .missing: "No Missing Parts"
        case .untouched: "All Parts Accounted For"
        }
    }

    private var emptyIcon: String {
        switch viewModel.filter {
        case .all: "tray"
        case .missing: "checkmark.circle"
        case .untouched: "hand.thumbsup"
        }
    }

    private var emptyDescription: String {
        switch viewModel.filter {
        case .all: "This set has no parts."
        case .missing: "No parts have been marked as missing."
        case .untouched: "All parts have been accounted for."
        }
    }
}
