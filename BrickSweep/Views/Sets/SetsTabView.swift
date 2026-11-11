import SwiftData
import SwiftUI

struct SetsTabView: View {
    private enum SetsViewMode: String, CaseIterable, Identifiable {
        case all = "All"
        case themes = "Themes"

        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LegoSet.dateAdded, order: .reverse) private var sets: [LegoSet]
    @State private var viewModel = SetListViewModel(
        importService: SetImportService(
            apiClient: RebrickableAPIClient(apiKeyProvider: { APIKeyProvider.getAPIKey() }),
            setDataClient: SetDataClient(),
            usesOwnAPIKey: { APIKeyProvider.hasVerifiedAPIKey() }
        )
    )
    @State private var didCleanUpStuckImports = false
    @State private var isRefreshingThemeMetadata = false
    @State private var viewMode: SetsViewMode = .all
    @State private var path = NavigationPath()

    private var totalMissingCount: Int {
        sets.reduce(0) { sum, set in
            sum + set.parts.filter { $0.missingQty > 0 }.count
        }
    }

    private var themeGroups: [ThemeGroup] {
        ThemeGroup.groups(from: sets)
    }

    private var hasSetsNeedingThemeMetadata: Bool {
        sets.contains { set in
            let themeName = set.themeName?.trimmingCharacters(in: .whitespacesAndNewlines)
            return set.themeId == nil || themeName?.isEmpty != false
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if sets.isEmpty && !viewModel.isLoading {
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
                } else {
                    List {
                        Section {
                            Picker("View", selection: $viewMode) {
                                ForEach(SetsViewMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                        Section {
                            SummaryHeaderView(stats: [
                                StatCard(icon: "square.stack.3d.up.fill", value: sets.count, label: "Sets", iconColor: AppTheme.legoYellow),
                                StatCard(icon: "exclamationmark.triangle.fill", value: totalMissingCount, label: "Missing", iconColor: AppTheme.legoRed),
                            ])
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            if viewMode == .all {
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
                            } else {
                                if hasSetsNeedingThemeMetadata {
                                    if isRefreshingThemeMetadata {
                                        HStack {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("Categorising sets...")
                                                .foregroundStyle(.secondary)
                                        }
                                    } else {
                                        Button {
                                            refreshThemeMetadataIfNeeded()
                                        } label: {
                                            Label("Categorise Existing Sets", systemImage: "arrow.triangle.2.circlepath")
                                        }
                                    }
                                }

                                ForEach(themeGroups) { group in
                                    NavigationLink(value: group) {
                                        ThemeGroupRowView(group: group)
                                    }
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
            .navigationDestination(for: ThemeGroup.self) { group in
                ThemeSetListView(group: group)
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
                if viewMode == .themes {
                    refreshThemeMetadataIfNeeded()
                }
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
            .onChange(of: viewMode) { _, newValue in
                if newValue == .themes {
                    refreshThemeMetadataIfNeeded()
                }
            }
        }
        // Alerts take the tint from above the view they're attached to, so the yellow sits
        // inside the stack and the alerts outside it; yellow button text is unreadable on glass.
        .tint(AppTheme.legoYellow)
        .alert(
            "Already in Your Sets",
            isPresented: Binding(
                get: { viewModel.existingSetNotice != nil },
                set: { if !$0 { viewModel.existingSetNotice = nil } }
            ),
            presenting: viewModel.existingSetNotice
        ) { notice in
            Button("Open Set") { path.append(notice.legoSet) }
            Button("OK", role: .cancel) {}
        } message: { notice in
            if notice.isDownloading {
                Text("\(notice.legoSet.name) (\(notice.legoSet.setNum)) is still downloading. Open it to follow its progress.")
            } else {
                Text("\(notice.legoSet.name) (\(notice.legoSet.setNum)) is already in your collection, with your progress saved.")
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    /// Fills in missing themes, from the user's own key if they have one and from
    /// BrickSweep's data files otherwise.
    private func refreshThemeMetadataIfNeeded() {
        guard hasSetsNeedingThemeMetadata, !isRefreshingThemeMetadata else {
            return
        }

        isRefreshingThemeMetadata = true
        Task {
            await viewModel.refreshThemeMetadata(for: sets, modelContext: modelContext)
            isRefreshingThemeMetadata = false
        }
    }
}
