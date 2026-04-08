import SwiftData
import SwiftUI

struct ReplacedPartsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = ReplacedPartsViewModel()

    private var uniquePartCount: Int {
        viewModel.replacedParts.count
    }

    private var totalReplacedQty: Int {
        viewModel.replacedParts.reduce(0) { $0 + $1.totalReplacedQty }
    }

    private var setsAffected: Int {
        Set(viewModel.replacedParts.flatMap(\.contributingSets)).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.replacedParts.isEmpty {
                    ContentUnavailableView(
                        "No Replaced Parts",
                        systemImage: "checkmark.circle",
                        description: Text("Swipe left on missing parts to mark them as replaced.")
                    )
                } else if viewModel.filteredReplacedParts.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    List {
                        Section {
                            SummaryHeaderView(stats: [
                                StatCard(icon: "puzzlepiece.fill", value: uniquePartCount, label: "Unique", iconColor: AppTheme.legoYellow),
                                StatCard(icon: "number", value: totalReplacedQty, label: "Total Qty", iconColor: AppTheme.completedGreen),
                                StatCard(icon: "square.stack.3d.up.fill", value: setsAffected, label: "Sets", iconColor: .orange),
                            ])
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(viewModel.filteredReplacedParts) { part in
                                ReplacedPartRowView(part: part)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            viewModel.markAsNotReplaced(part, modelContext: modelContext)
                                        } label: {
                                            Label("Undo", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.orange)
                                    }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Replaced Parts")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search by part number")
            .toolbar {
                if !viewModel.replacedParts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort by", selection: $viewModel.sortOption) {
                                ForEach(PartSortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .onChange(of: viewModel.sortOption) {
                viewModel.refresh(modelContext: modelContext)
            }
            .refreshable {
                viewModel.refresh(modelContext: modelContext)
            }
            .onAppear {
                viewModel.refresh(modelContext: modelContext)
            }
            .alert("Save Error", isPresented: $viewModel.showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.saveErrorMessage {
                    Text(error)
                }
            }
        }
    }
}
