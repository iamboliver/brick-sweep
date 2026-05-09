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

        let input = setNumInput
        isLoading = true
        errorMessage = nil
        var createdSet: LegoSet?

        do {
            createdSet = try await importService.createSet(setNum: input, modelContext: modelContext)
            setNumInput = ""
            isLoading = false  // overlay dismisses; set row appears with spinner

            if let set = createdSet {
                try await importService.loadParts(into: set, setNum: set.setNum, modelContext: modelContext)
            }
        } catch {
            // Partial set (if created) is kept with isImporting = true.
            // User can swipe to delete it and try again.
            errorMessage = createdSet != nil
                ? "Import failed partway through — swipe to delete the set and try again."
                : error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    func retryImport(legoSet: LegoSet, modelContext: ModelContext) async {
        do {
            try await importService.retryLoadParts(into: legoSet, modelContext: modelContext)
        } catch {
            // importFailed = true is already set by loadParts on failure
        }
    }

    func deleteSet(_ legoSet: LegoSet, modelContext: ModelContext) {
        modelContext.delete(legoSet)
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
