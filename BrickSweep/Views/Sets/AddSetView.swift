import SwiftUI

struct AddSetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var storeManager
    @Bindable var viewModel: SetListViewModel
    let setCount: Int
    @State private var showSheet = false
    @State private var showPaywall = false

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityLabel("Add set")
        .sheet(isPresented: $showSheet) {
            VStack(spacing: AppTheme.Spacing.lg) {
                Text("Add Set")
                    .font(AppTheme.Typography.headline)

                TextField("Set number (e.g. 60272)", text: $viewModel.setNumInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onSubmit {
                        loadSetOrShowPaywall()
                    }

                Button {
                    loadSetOrShowPaywall()
                } label: {
                    Text("Load Set")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.legoYellow)
                .foregroundStyle(Color(.label))
                .controlSize(.large)
                .disabled(
                    viewModel.setNumInput.trimmingCharacters(in: .whitespaces).isEmpty
                        || viewModel.isLoading
                )
            }
            .padding(AppTheme.Spacing.xl)
            .presentationDetents([.height(220)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .setLimit)
        }
    }

    private func loadSetOrShowPaywall() {
        if setCount >= AppConstants.IAP.freeTierSetLimit && !storeManager.isPro {
            showSheet = false
            showPaywall = true
        } else {
            showSheet = false
            Task {
                await viewModel.loadSet(modelContext: modelContext)
            }
        }
    }
}
