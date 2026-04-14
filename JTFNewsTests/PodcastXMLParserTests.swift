import Testing
import Foundation
@testable import JTFNews

@Suite("PodcastXMLParser")
struct PodcastXMLParserTests {

    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "xml", subdirectory: "Fixtures")
            ?? Bundle(for: BundleToken.self).url(forResource: name, withExtension: "xml")!
        return try Data(contentsOf: url)
    }

    @Test("Full feed: all 3 items parse with audio, sorted newest first")
    func fullFeed() throws {
        let data = try fixtureData("fixture_fullFeed")
        let parser = PodcastXMLParser(data: data)
        let episodes = try parser.parseThrowing().sorted { $0.date > $1.date }

        #expect(episodes.count == 3)
        #expect(episodes.allSatisfy(\.hasAudio))
        #expect(episodes[0].date > episodes[1].date)
        #expect(episodes[1].date > episodes[2].date)
    }

    @Test("Partial feed: middle item has no enclosure, still present with hasAudio == false")
    func partialFeed() throws {
        let data = try fixtureData("fixture_partialFeed")
        let parser = PodcastXMLParser(data: data)
        let episodes = try parser.parseThrowing().sorted { $0.date > $1.date }

        #expect(episodes.count == 3)
        #expect(episodes[0].hasAudio == true)
        #expect(episodes[1].hasAudio == false)
        #expect(episodes[2].hasAudio == true)
    }

    @Test("Malformed pubDate: item dropped, only 2 returned, no Date() fallback")
    func malformedPubDate() throws {
        let data = try fixtureData("fixture_malformedPubDate")
        let parser = PodcastXMLParser(data: data)
        let episodes = try parser.parseThrowing().sorted { $0.date > $1.date }

        #expect(episodes.count == 2)
        let titles = episodes.map(\.title)
        #expect(!titles.contains("JTF News Daily Digest - 2026-04-12"))
    }

    @Test("Conflict markers: parseThrowing() throws malformedXML")
    func conflictMarkers() throws {
        let data = try fixtureData("fixture_conflictMarkers")
        let parser = PodcastXMLParser(data: data)

        #expect(throws: PodcastFeedError.self) {
            _ = try parser.parseThrowing()
        }
    }

    @Test("Conflict markers: legacy parse() returns without crashing")
    func conflictMarkersLegacy() throws {
        let data = try fixtureData("fixture_conflictMarkers")
        let parser = PodcastXMLParser(data: data)
        let episodes = parser.parse()
        #expect(episodes.count < 7)
    }
}

private final class BundleToken {}
