import Foundation
import SwiftData

/// Shown when the user tries to add a set that is already in their collection.
struct ExistingSetNotice: Identifiable {
    let legoSet: LegoSet
    /// True when the set's parts are still downloading in this session.
    let isDownloading: Bool

    var id: String { legoSet.setNum }
}

@MainActor
@Observable
final class SetListViewModel {
    var setNumInput = ""
    var isLoading = false
    var errorMessage: String?
    var showError = false
    var existingSetNotice: ExistingSetNotice?

    /// Set numbers whose parts are being downloaded right now, so the same set is
    /// never imported twice at once (double taps, re-adding mid-download, retry).
    private(set) var importsInProgress: Set<String> = []

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

    /// Whether this set number is already in the collection (ignoring letter case).
    func isInCollection(setNum: String, modelContext: ModelContext) -> Bool {
        let input = setNum.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return false }
        return (try? importService.existingSet(setNum: input, modelContext: modelContext)) != nil
    }

    /// Whether adding the typed set should show the paywall. A set that's already in
    /// the collection doesn't use up a free slot: adding it explains it's already
    /// there, or resumes a failed import.
    func shouldShowPaywall(setCount: Int, isPro: Bool, modelContext: ModelContext) -> Bool {
        setCount >= AppConstants.IAP.freeTierSetLimit
            && !isPro
            && !isInCollection(setNum: setNumInput, modelContext: modelContext)
    }

    private func loadSet(setNum: String, modelContext: ModelContext, clearInputOnSuccess: Bool = false) async {
        if let downloading = try? importService.existingSet(setNum: setNum, modelContext: modelContext),
           importsInProgress.contains(downloading.setNum) {
            if clearInputOnSuccess { setNumInput = "" }
            existingSetNotice = ExistingSetNotice(legoSet: downloading, isDownloading: true)
            return
        }

        isLoading = true
        errorMessage = nil
        var startedSet: LegoSet?

        do {
            let outcome = try await importService.createSet(setNum: setNum, modelContext: modelContext)
            if clearInputOnSuccess {
                setNumInput = ""
            }
            isLoading = false  // overlay dismisses; set row appears with spinner

            switch outcome {
            case .created(let set):
                startedSet = set
                try await runImport(of: set) {
                    try await importService.loadParts(into: set, setNum: set.setNum, modelContext: modelContext)
                }
            case .needsRetry(let set):
                // Another add may have finished this import since createSet looked.
                guard set.isImporting || set.importFailed else {
                    existingSetNotice = ExistingSetNotice(legoSet: set, isDownloading: false)
                    break
                }
                startedSet = set
                try await runImport(of: set) {
                    try await importService.retryLoadParts(into: set, modelContext: modelContext)
                }
            case .alreadyInCollection(let set):
                existingSetNotice = ExistingSetNotice(legoSet: set, isDownloading: false)
            }
        } catch is ImportAlreadyRunning {
            // Another import of this set started while we were creating it; it carries on.
            if let set = startedSet {
                existingSetNotice = ExistingSetNotice(legoSet: set, isDownloading: true)
            }
        } catch {
            // Partial set (if created) is kept with importFailed = true.
            // User can open it and retry, or swipe to delete it.
            errorMessage = startedSet != nil
                ? "The download didn't finish. Your progress was saved — open the set and tap Retry Download when you're ready."
                : error.localizedDescription
            showError = true
            isLoading = false
        }
    }

    func retryImport(legoSet: LegoSet, modelContext: ModelContext) async {
        do {
            try await runImport(of: legoSet) {
                try await importService.retryLoadParts(into: legoSet, modelContext: modelContext)
            }
        } catch {
            // importFailed = true is already set by loadParts on failure
        }
    }

    private struct ImportAlreadyRunning: Error {}

    /// Runs one import for a set, refusing to start a second while the first is running.
    private func runImport(of legoSet: LegoSet, _ work: () async throws -> Void) async throws {
        let setNum = legoSet.setNum
        guard !importsInProgress.contains(setNum) else { throw ImportAlreadyRunning() }
        importsInProgress.insert(setNum)
        defer { importsInProgress.remove(setNum) }
        try await work()
    }

    func refreshThemeMetadata(for sets: [LegoSet], modelContext: ModelContext) async {
        await importService.refreshThemeMetadata(for: sets, modelContext: modelContext)
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
