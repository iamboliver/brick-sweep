import SwiftData
import SwiftUI

struct MissingPartsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager
    @State private var viewModel = MissingPartsViewModel()
    @State private var showPaywall = false

    private var uniquePartCount: Int {
        viewModel.missingParts.count
    }

    private var totalMissingQty: Int {
        viewModel.missingParts.reduce(0) { $0 + $1.totalMissingQty }
    }

    private var setsAffected: Int {
        Set(viewModel.missingParts.flatMap(\.contributingSets)).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.missingParts.isEmpty {
                    ContentUnavailableView(
                        "No Missing Parts",
                        systemImage: "checkmark.circle",
                        description: Text("All parts accounted for. Tap parts in a set to mark them as missing.")
                    )
                } else if viewModel.filteredMissingParts.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                } else {
                    List {
                        Section {
                            SummaryHeaderView(stats: [
                                StatCard(icon: "puzzlepiece.fill", value: uniquePartCount, label: "Unique", iconColor: AppTheme.legoYellow),
                                StatCard(icon: "number", value: totalMissingQty, label: "Total Qty", iconColor: AppTheme.legoRed),
                                StatCard(icon: "square.stack.3d.up.fill", value: setsAffected, label: "Sets", iconColor: .orange),
                            ])
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(viewModel.filteredMissingParts) { part in
                                MissingPartRowView(part: part)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            viewModel.markAsReplaced(part, modelContext: modelContext)
                                        } label: {
                                            Label("Replaced", systemImage: "checkmark.circle.fill")
                                        }
                                        .tint(.green)
                                    }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Missing Parts")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search by part number")
            .toolbar {
                if !viewModel.missingParts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort by", selection: $viewModel.sortOption) {
                                ForEach(PartSortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }

                            Divider()

                            Button("Export", systemImage: "square.and.arrow.up") {
                                if storeManager.isPro {
                                    Task {
                                        await viewModel.generateExport()
                                    }
                                } else {
                                    showPaywall = true
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
            .sheet(isPresented: $viewModel.showExportOptions) {
                ExportOptionsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .proFeature)
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
