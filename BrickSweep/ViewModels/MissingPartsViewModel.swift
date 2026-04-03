import Foundation
import SwiftData

@MainActor
@Observable
final class MissingPartsViewModel {
    var missingParts: [GlobalMissingPart] = []
    var sortOption: PartSortOption = .color
    var searchText: String = ""
    var exportText: String = ""
    var showExportOptions = false
    var exportFormat: ExportFormat = .brickLinkXML
    var saveErrorMessage: String?
    var showSaveError = false

    enum ExportFormat: String, CaseIterable {
        case brickLinkXML = "BrickLink XML"
        case csv = "CSV"
    }

    var filteredMissingParts: [GlobalMissingPart] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return missingParts }
        return missingParts.filter {
            $0.partNum.localizedCaseInsensitiveContains(query)
            || $0.elementId?.localizedCaseInsensitiveContains(query) == true
            || $0.brickLinkPartNum?.localizedCaseInsensitiveContains(query) == true
        }
    }

    func refresh(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<LegoPartInstance>(
            predicate: #Predicate { $0.missingQty > 0 }
        )
        let parts = (try? modelContext.fetch(descriptor)) ?? []
        missingParts = GlobalMissingPart.aggregate(from: parts, sortedBy: sortOption)
    }

    func markAsReplaced(_ part: GlobalMissingPart, modelContext: ModelContext) {
        let partNum = part.partNum
        let colorId = part.colorId
        let descriptor = FetchDescriptor<LegoPartInstance>(
            predicate: #Predicate { $0.partNum == partNum && $0.colorId == colorId && $0.missingQty > 0 }
        )
        guard let instances = try? modelContext.fetch(descriptor) else { return }
        for instance in instances {
            instance.replacedQty += instance.missingQty
            instance.missingQty = 0
        }
        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
        refresh(modelContext: modelContext)
    }

    func generateExport() async {
        let exportService = ExportService()
        switch exportFormat {
        case .brickLinkXML:
            exportText = await exportService.generateBrickLinkXML(from: missingParts)
        case .csv:
            exportText = exportService.generateCSV(from: missingParts)
        }
        showExportOptions = true
    }
}
