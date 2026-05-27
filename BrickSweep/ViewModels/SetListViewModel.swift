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
        let input = setNumInput.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }

        await loadSet(setNum: input, modelContext: modelContext, clearInputOnSuccess: true)
    }

    func loadExampleSet(modelContext: ModelContext) async {
        await loadSet(setNum: AppConstants.Support.exampleSetNumber, modelContext: modelContext)
    }

    private func loadSet(setNum: String, modelContext: ModelContext, clearInputOnSuccess: Bool = false) async {
        isLoading = true
        errorMessage = nil
        var createdSet: LegoSet?

        do {
            createdSet = try await importService.createSet(setNum: setNum, modelContext: modelContext)
            if clearInputOnSuccess {
                setNumInput = ""
            }
            isLoading = false  // overlay dismisses; set row appears with spinner

            if let set = createdSet {
                try await importService.loadParts(into: set, setNum: set.setNum, modelContext: modelContext)
            }
        } catch {
            // Partial set (if created) is kept with isImporting = true.
            // User can swipe to delete it and try again.
            errorMessage = createdSet != nil
                ? "Rebrickable was temporarily unavailable. Your progress was saved — open the set and tap Retry Download when you're ready."
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
