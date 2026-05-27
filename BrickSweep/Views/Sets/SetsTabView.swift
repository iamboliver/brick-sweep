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
    @State private var hasVerifiedAPIKey = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasVerifiedAPIKey)
    @State private var didCleanUpStuckImports = false
    @State private var showAPIKeyHelp = false

    private var totalMissingCount: Int {
        sets.reduce(0) { sum, set in
            sum + set.parts.filter { $0.missingQty > 0 }.count
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sets.isEmpty && !viewModel.isLoading {
                    if !hasAPIKey || !hasVerifiedAPIKey {
                        ContentUnavailableView {
                            Label("API Key Required", systemImage: "key.fill")
                        } description: {
                            Text("BrickSweep uses your free Rebrickable API key to download set inventories. Add and test your key in **Settings** before importing a set.")
                        } actions: {
                            VStack {
                                Button("Open Settings") {
                                    navigator.selectedTab = .settings
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.legoYellow)

                                Button("How to get an API key") {
                                    showAPIKeyHelp = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .tint(AppTheme.legoYellow)
                    } else {
                        ContentUnavailableView {
                            Label("Add Your First Set", systemImage: "square.stack.3d.up.fill")
                        } description: {
                            Text("Search by set number above to import your LEGO set and start tracking missing pieces.")
                        } actions: {
                            Button("Try Example Set") {
                                Task {
                                    await viewModel.loadExampleSet(modelContext: modelContext)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.legoYellow)
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
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: LegoSet.self) { legoSet in
                PartListView(legoSet: legoSet) {
                    await viewModel.retryImport(legoSet: legoSet, modelContext: modelContext)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AddSetView(viewModel: viewModel, setCount: sets.count)
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
                hasVerifiedAPIKey = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.hasVerifiedAPIKey)
                if !didCleanUpStuckImports {
                    didCleanUpStuckImports = true
                    // Mark any mid-import sets (crashed before finishing) as failed so the user can retry
                    let descriptor = FetchDescriptor<LegoSet>(
                        predicate: #Predicate { $0.isImporting && !$0.importFailed }
                    )
                    if let stuck = try? modelContext.fetch(descriptor), !stuck.isEmpty {
                        stuck.forEach { $0.importFailed = true }
                        try? modelContext.save()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .sheet(isPresented: $showAPIKeyHelp) {
                APIKeyHelpView()
            }
        }
    }
}
