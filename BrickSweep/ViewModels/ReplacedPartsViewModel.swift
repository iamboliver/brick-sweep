import Foundation
import SwiftData

@MainActor
@Observable
final class ReplacedPartsViewModel {
    var replacedParts: [GlobalReplacedPart] = []
    var sortOption: PartSortOption = .color
    var searchText: String = ""
    var saveErrorMessage: String?
    var showSaveError = false

    var filteredReplacedParts: [GlobalReplacedPart] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return replacedParts }
        return replacedParts.filter {
            $0.partNum.localizedCaseInsensitiveContains(query)
            || $0.elementId?.localizedCaseInsensitiveContains(query) == true
            || $0.brickLinkPartNum?.localizedCaseInsensitiveContains(query) == true
        }
    }

    func refresh(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<LegoPartInstance>(
            predicate: #Predicate { $0.replacedQty > 0 }
        )
        let parts = (try? modelContext.fetch(descriptor)) ?? []
        replacedParts = GlobalReplacedPart.aggregate(from: parts, sortedBy: sortOption)
    }

    func markAsNotReplaced(_ part: GlobalReplacedPart, modelContext: ModelContext) {
        let partNum = part.partNum
        let colorId = part.colorId
        let descriptor = FetchDescriptor<LegoPartInstance>(
            predicate: #Predicate { $0.partNum == partNum && $0.colorId == colorId && $0.replacedQty > 0 }
        )
        guard let instances = try? modelContext.fetch(descriptor) else { return }
        for instance in instances {
            instance.missingQty += instance.replacedQty
            instance.replacedQty = 0
        }
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
        refresh(modelContext: modelContext)
    }
}
