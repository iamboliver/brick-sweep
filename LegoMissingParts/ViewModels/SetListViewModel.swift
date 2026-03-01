import Foundation
import SwiftData

@MainActor
@Observable
final class SetListViewModel {
    var setNumInput = ""
    var isLoading = false
    var errorMessage: String?
    var showError = false

    private let importService: SetImportService

    init(importService: SetImportService) {
        self.importService = importService
    }

    func loadSet(modelContext: ModelContext) async {
        guard !setNumInput.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await importService.importSet(setNum: setNumInput, modelContext: modelContext)
            setNumInput = ""
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isLoading = false
    }

    func deleteSet(_ legoSet: LegoSet, modelContext: ModelContext) {
        modelContext.delete(legoSet)
        try? modelContext.save()
    }
}
