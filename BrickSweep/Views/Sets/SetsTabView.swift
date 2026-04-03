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
    @Environment(AppNavigator.self) private var navigator
    @State private var hasAPIKey = APIKeyProvider.getAPIKey() != nil

    private var totalMissingCount: Int {
        sets.reduce(0) { sum, set in
            sum + set.parts.filter { $0.missingQty > 0 }.count
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sets.isEmpty && !viewModel.isLoading {
                    if !hasAPIKey {
                        ContentUnavailableView {
                            Label("API Key Required", systemImage: "key.fill")
                        } description: {
                            Text("BrickSweep looks up set part lists using Rebrickable's free community database — over 1 million LEGO parts catalogued by fans.\n\nAdd your free API key in the **Settings** tab to get started.")
                        } actions: {
                            Button("Open Settings") {
                                navigator.selectedTab = .settings
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.legoYellow)
                        }
                        .tint(AppTheme.legoYellow)
                    } else {
                        ContentUnavailableView {
                            Label("Add Your First Set", systemImage: "square.stack.3d.up.fill")
                        } description: {
                            Text("Search by set number above to import your LEGO set and start tracking missing pieces.")
                        }
                        .tint(AppTheme.legoYellow)
                    }
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
                                for index in indexSet {
                                    viewModel.deleteSet(sets[index], modelContext: modelContext)
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
            .onAppear {
                hasAPIKey = APIKeyProvider.getAPIKey() != nil
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
        }
    }
}
