import SwiftData
import SwiftUI

struct MissingPartsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MissingPartsViewModel()

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
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Missing Parts")
            .navigationBarTitleDisplayMode(.inline)
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
                                Task {
                                    await viewModel.generateExport()
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
            .onAppear {
                viewModel.refresh(modelContext: modelContext)
            }
        }
    }
}
