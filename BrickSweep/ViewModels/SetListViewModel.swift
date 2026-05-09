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
            if let partial = createdSet {
                modelContext.delete(partial)
                try? modelContext.save()
            }
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
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
