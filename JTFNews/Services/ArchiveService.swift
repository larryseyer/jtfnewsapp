import Foundation
import SwiftData

actor ArchiveService {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchIndex(baseURL: String = "https://jtfnews.org") async throws -> [String] {
        let url = URL(string: "\(baseURL)/archive/index.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let index = try JSONDecoder().decode(ArchiveIndex.self, from: data)
        return index.dates
    }

    func fetchDay(dateString: String, baseURL: String = "https://jtfnews.org") async throws -> String {
        let context = ModelContext(modelContainer)

        // Check cache first
        let descriptor = FetchDescriptor<ArchivedDay>(
            predicate: #Predicate { $0.rawText != "" }
        )
        let cached = try context.fetch(descriptor)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let existing = cached.first(where: { formatter.string(from: $0.date) == dateString }) {
            return existing.rawText
        }

        // Fetch from network
        let components = dateString.split(separator: "-")
        guard components.count == 3 else { throw ArchiveError.invalidDate }

        let year = components[0]
        let urlString = "\(baseURL)/archive/\(year)/\(dateString).txt.gz"
        let url = URL(string: urlString)!
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let decompressed = GzipUtility.decompress(data),
              let text = String(data: decompressed, encoding: .utf8)
        else {
            throw ArchiveError.decompressionFailed
        }

        // Cache in SwiftData
        let day = ArchivedDay()
        day.date = formatter.date(from: dateString) ?? Date()
        day.rawText = text
        day.isIndexed = false
        context.insert(day)
        try context.save()

        return text
    }
}

struct ArchiveIndex: Codable, Sendable {
    let dates: [String]
}

enum ArchiveError: Error {
    case invalidDate
    case decompressionFailed
}
