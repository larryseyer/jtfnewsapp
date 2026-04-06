import Foundation
import SwiftData

actor DataService {
    private let modelContainer: ModelContainer
    private static let cooldownInterval: TimeInterval = 300 // 5 minutes

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Fetch Stories

    func fetchStories(baseURL: String = "https://jtfnews.org") async throws {
        guard shouldFetch(key: "lastStoriesFetch") else { return }

        let url = URL(string: "\(baseURL)/stories.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(StoriesResponse.self, from: data)

        let context = ModelContext(modelContainer)
        for dto in response.stories {
            let descriptor = FetchDescriptor<Story>(
                predicate: #Predicate { $0.hash == dto.hash }
            )
            let existing = try context.fetch(descriptor)

            if let story = existing.first {
                story.fact = dto.fact
                story.sourceDisplay = dto.source
                story.sourceURLs = dto.sourceURLs ?? [:]
                story.audioURL = dto.audio
                story.status = dto.status ?? ""
            } else {
                let story = Story()
                story.id = dto.id
                story.hash = dto.hash
                story.fact = dto.fact
                story.sourceDisplay = dto.source
                story.sourceURLs = dto.sourceURLs ?? [:]
                story.audioURL = dto.audio
                story.publishedAt = parseDate(dto.publishedAt) ?? Date()
                story.status = dto.status ?? ""
                context.insert(story)
            }
        }
        try context.save()
        markFetched(key: "lastStoriesFetch")
    }

    // MARK: - Fetch Corrections

    func fetchCorrections(baseURL: String = "https://jtfnews.org") async throws {
        guard shouldFetch(key: "lastCorrectionsFetch") else { return }

        let url = URL(string: "\(baseURL)/corrections.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let corrections = try JSONDecoder().decode([CorrectionDTO].self, from: data)

        let context = ModelContext(modelContainer)
        for dto in corrections {
            let descriptor = FetchDescriptor<Correction>(
                predicate: #Predicate { $0.storyId == dto.storyId }
            )
            let existing = try context.fetch(descriptor)

            if let correction = existing.first {
                correction.originalFact = dto.originalFact
                correction.correctedFact = dto.correctedFact
                correction.reason = dto.reason
                correction.correctingSources = dto.correctingSources
                correction.type = dto.type
            } else {
                let correction = Correction()
                correction.storyId = dto.storyId
                correction.originalFact = dto.originalFact
                correction.correctedFact = dto.correctedFact
                correction.reason = dto.reason
                correction.correctingSources = dto.correctingSources
                correction.correctedAt = parseDate(dto.correctedAt) ?? Date()
                correction.type = dto.type
                context.insert(correction)
            }
        }
        try context.save()
        markFetched(key: "lastCorrectionsFetch")
    }

    // MARK: - Cooldown

    private func shouldFetch(key: String) -> Bool {
        let lastFetch = UserDefaults.standard.double(forKey: key)
        return Date().timeIntervalSince1970 - lastFetch >= Self.cooldownInterval
    }

    private func markFetched(key: String) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
    }

    // MARK: - Date Parsing

    private func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - DTOs

struct StoriesResponse: Codable, Sendable {
    let date: String
    let source: String
    let stories: [StoryDTO]
}

struct StoryDTO: Codable, Sendable {
    let id: String
    let hash: String
    let fact: String
    let source: String
    let sourceURLs: [String: String]?
    let audio: String?
    let publishedAt: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, hash, fact, source, audio, status
        case sourceURLs = "source_urls"
        case publishedAt = "published_at"
    }
}

struct CorrectionDTO: Codable, Sendable {
    let storyId: String
    let originalFact: String
    let correctedFact: String
    let reason: String
    let correctingSources: [String]
    let correctedAt: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case reason, type
        case storyId = "story_id"
        case originalFact = "original_fact"
        case correctedFact = "corrected_fact"
        case correctingSources = "correcting_sources"
        case correctedAt = "corrected_at"
    }
}
