import Foundation

struct PodcastEpisode: Sendable, Identifiable {
    let id: String
    let title: String
    let date: Date
    let audioURL: String
    let duration: String
}

actor PodcastService {
    func fetchEpisodes(baseURL: String = "https://jtfnews.org") async throws -> [PodcastEpisode] {
        let url = URL(string: "\(baseURL)/podcast.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = PodcastXMLParser(data: data)
        return parser.parse()
    }

    func fetchYouTubeURL(baseURL: String = "https://jtfnews.org") async throws -> String? {
        let url = URL(string: "\(baseURL)/monitor.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let monitor = try JSONDecoder().decode(MonitorResponse.self, from: data)
        return monitor.dailyDigest?.youtubeURL
    }
}

// MARK: - Monitor DTO

struct MonitorResponse: Codable, Sendable {
    let dailyDigest: DailyDigestInfo?

    enum CodingKeys: String, CodingKey {
        case dailyDigest = "daily_digest"
    }
}

struct DailyDigestInfo: Codable, Sendable {
    let youtubeURL: String?

    enum CodingKeys: String, CodingKey {
        case youtubeURL = "youtube_url"
    }
}

// MARK: - Podcast XML Parser

final class PodcastXMLParser: NSObject, XMLParserDelegate, @unchecked Sendable {
    private let data: Data
    private var episodes: [PodcastEpisode] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDate = ""
    private var currentAudioURL = ""
    private var currentDuration = ""
    private var inItem = false

    init(data: Data) {
        self.data = data
    }

    func parse() -> [PodcastEpisode] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return episodes
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentDate = ""
            currentAudioURL = ""
            currentDuration = ""
        } else if elementName == "enclosure" && inItem {
            currentAudioURL = attributeDict["url"] ?? ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "pubDate": currentDate += string
        case "itunes:duration": currentDuration += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            inItem = false
            let date = parseRFC2822Date(currentDate.trimmingCharacters(in: .whitespacesAndNewlines))
            let episode = PodcastEpisode(
                id: currentAudioURL,
                title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date ?? Date(),
                audioURL: currentAudioURL.trimmingCharacters(in: .whitespacesAndNewlines),
                duration: currentDuration.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            if !episode.audioURL.isEmpty {
                episodes.append(episode)
            }
        }
        currentElement = ""
    }

    private func parseRFC2822Date(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: string)
    }
}
