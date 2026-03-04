import SwiftData
import SwiftUI

struct SetsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LegoSet.dateAdded, order: .reverse) private var sets: [LegoSet]
    @State private var viewModel = SetListViewModel(
        importService: SetImportService(
            apiClient: RebrickableAPIClient(apiKeyProvider: { APIKeyProvider.getAPIKey() })
        )
    )
    @State private var showDeleteConfirmation = false
    @State private var setToDelete: LegoSet?

    private var totalMissingCount: Int {
        sets.reduce(0) { sum, set in
            sum + set.parts.filter { $0.missingQty > 0 }.count
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sets.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "No Sets Added",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Enter a set number above to get started.")
                    )
                    .tint(AppTheme.legoYellow)
                } else {
                    List {
                        Section {
                            SummaryHeaderView(stats: [
                                StatCard(icon: "square.stack.3d.up.fill", value: sets.count, label: "Sets", iconColor: AppTheme.legoYellow),
                                StatCard(icon: "exclamationmark.triangle.fill", value: totalMissingCount, label: "Missing", iconColor: AppTheme.legoRed),
                            ])
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(sets) { legoSet in
                                NavigationLink(value: legoSet) {
                                    SetRowView(legoSet: legoSet)
                                }
                            }
                            .onDelete { indexSet in
                                if let index = indexSet.first {
                                    setToDelete = sets[index]
                                    showDeleteConfirmation = true
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Sets")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LegoSet.self) { legoSet in
                PartListView(legoSet: legoSet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AddSetView(viewModel: viewModel)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    SetLoadingOverlay()
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(AppTheme.Animation.easeInOut, value: viewModel.isLoading)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .confirmationDialog(
                "Delete Set",
                isPresented: $showDeleteConfirmation,
                presenting: setToDelete
            ) { legoSet in
                Button("Delete \(legoSet.name)", role: .destructive) {
                    viewModel.deleteSet(legoSet, modelContext: modelContext)
                }
            } message: { legoSet in
                Text("This will delete \(legoSet.name) and all its part data. This cannot be undone.")
            }
        }
    }
}
