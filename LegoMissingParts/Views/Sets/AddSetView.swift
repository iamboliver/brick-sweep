import SwiftUI

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: SetListViewModel
    @State private var showSheet = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .sheet(isPresented: $showSheet) {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text("Add LEGO Set")
                    .font(AppTheme.Typography.headline)

                TextField("Set number (e.g. 75192)", text: $viewModel.setNumInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        loadSet()
                    }

                Button {
                    loadSet()
                } label: {
                    Text("Load Set")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.legoYellow)
                .foregroundStyle(.black)
                .controlSize(.large)
                .disabled(
                    viewModel.setNumInput.trimmingCharacters(in: .whitespaces).isEmpty
                        || viewModel.isLoading
                )
            }
            .padding(AppTheme.Spacing.xl)
            .presentationDetents([.height(220)])
        }
    }

    private func loadSet() {
        showSheet = false
        Task {
            await viewModel.loadSet(modelContext: modelContext)
        }
    }
}
