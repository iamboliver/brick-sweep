import StoreKit
import SwiftUI

struct ExportOptionsView: View {
    @Bindable var viewModel: MissingPartsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var copied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.lg) {
                Picker("Format", selection: $viewModel.exportFormat) {
                    ForEach(MissingPartsViewModel.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: viewModel.exportFormat) {
                    Task {
                        await viewModel.generateExport()
                    }
                }

                ScrollView {
                    Text(viewModel.exportText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .padding(.horizontal)

                HStack(spacing: AppTheme.Spacing.lg) {
                    Button {
                        UIPasteboard.general.string = viewModel.exportText
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                            if viewModel.exportFormat == .brickLinkXML {
                                requestReview()
                            }
                        }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy to Clipboard",
                            systemImage: copied ? "checkmark" : "doc.on.doc"
                        )
                        .contentTransition(.symbolEffect(.replace))
                        .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.legoYellow)
                    .foregroundStyle(.black)

                    if let data = viewModel.exportText.data(using: .utf8) {
                        let filename = viewModel.exportFormat == .brickLinkXML ? "missing_parts.xml" : "missing_parts.csv"
                        ShareLink(
                            item: data,
                            preview: SharePreview(filename)
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Export Missing Parts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
