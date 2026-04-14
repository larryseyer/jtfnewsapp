import Testing
import Foundation
@testable import JTFNews

@Suite("MonitorResponse")
struct MonitorResponseTests {

    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle(for: BundleToken.self).url(forResource: name, withExtension: "json")!
        return try Data(contentsOf: url)
    }

    @Test("Full monitor.json: all DailyDigestInfo fields decode")
    func fullMonitor() throws {
        let data = try fixtureData("fixture_monitor_full")
        let monitor = try JSONDecoder().decode(MonitorResponse.self, from: data)

        #expect(monitor.dailyDigest != nil)
        #expect(monitor.dailyDigest?.youtubeURL == "https://youtube.com/watch?v=abc123")
        #expect(monitor.dailyDigest?.lastDate == "2026-04-13")
        #expect(monitor.dailyDigest?.podcastUpdated == true)
    }

    @Test("Minimal monitor.json: lastDate and podcastUpdated are nil, no crash")
    func minimalMonitor() throws {
        let data = try fixtureData("fixture_monitor_minimal")
        let monitor = try JSONDecoder().decode(MonitorResponse.self, from: data)

        #expect(monitor.dailyDigest != nil)
        #expect(monitor.dailyDigest?.youtubeURL == "https://youtube.com/watch?v=xyz789")
        #expect(monitor.dailyDigest?.lastDate == nil)
        #expect(monitor.dailyDigest?.podcastUpdated == nil)
    }

    @Test("last_date parses as Date in GMT")
    func lastDateParsing() throws {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .gmt

        let date = formatter.date(from: "2026-04-13")
        #expect(date != nil)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = calendar.dateComponents([.year, .month, .day], from: date!)
        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 13)
    }
}

private final class BundleToken {}
