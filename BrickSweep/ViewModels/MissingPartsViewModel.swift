import Foundation
import SwiftData

@MainActor
@Observable
final class MissingPartsViewModel {
    var missingParts: [GlobalMissingPart] = []
    var sortOption: PartSortOption = .color
    var searchText: String = ""
    var exportText: String = ""
    /// The export written to a named file for Share. Nil if writing it failed.
    var exportFileURL: URL?
    var showExportOptions = false
    var exportFormat: ExportFormat = .brickLinkXML
    var saveErrorMessage: String?
    var showSaveError = false

    typealias ExportTextGenerator = (ExportFormat, [GlobalMissingPart]) async -> String
    private let generateExportText: ExportTextGenerator
    private let exportDirectory: URL
    /// Counts export requests, so a slow one finishing late can tell it's been superseded.
    private var latestExportRequest = 0

    init(
        generateExportText: @escaping ExportTextGenerator = MissingPartsViewModel.defaultExportText(format:parts:),
        exportDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.generateExportText = generateExportText
        self.exportDirectory = exportDirectory
    }

    enum ExportFormat: String, CaseIterable {
        case brickLinkXML = "BrickLink XML"
        case csv = "CSV"

        var filename: String {
            switch self {
            case .brickLinkXML: "BrickSweep Missing Parts.xml"
            case .csv: "BrickSweep Missing Parts.csv"
            }
        }
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
            instance.markMissingAsReplaced()
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
        latestExportRequest += 1
        let request = latestExportRequest
        let format = exportFormat
        let text = await generateExportText(format, missingParts)
        // XML generation suspends, so switching to CSV meanwhile starts a newer request
        // that can finish first. The older one mustn't overwrite it, or the sheet would
        // show XML and share it named .csv.
        guard request == latestExportRequest else { return }
        exportText = text
        exportFileURL = Self.writeExportFile(text, named: format.filename, in: exportDirectory)
        showExportOptions = true
    }

    static func defaultExportText(format: ExportFormat, parts: [GlobalMissingPart]) async -> String {
        let exportService = ExportService()
        switch format {
        case .brickLinkXML:
            return await exportService.generateBrickLinkXML(from: parts)
        case .csv:
            return exportService.generateCSV(from: parts)
        }
    }

    /// Shared as raw data, the export arrived as ".com.apple.Foundation.NSItemProvider.XXXX.tmp";
    /// shared as a file, it keeps this name.
    static func writeExportFile(
        _ text: String,
        named filename: String,
        in directory: URL
    ) -> URL? {
        let url = directory.appendingPathComponent(filename)
        do {
            try Data(text.utf8).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
