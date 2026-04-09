import Foundation
import SwiftData
import Network
import SQLite3

@Observable
@MainActor
final class SearchIndexer {
    var indexProgress: Double = 0
    var isIndexing = false

    private var db: OpaquePointer?
    private let dbPath: String

    init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsPath.appendingPathComponent("search_index.sqlite").path
    }

    func openDatabase() {
        guard db == nil else { return }
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let createSQL = "CREATE VIRTUAL TABLE IF NOT EXISTS stories_fts USING fts5(date, fact_text, source_info)"
            sqlite3_exec(db, createSQL, nil, nil, nil)
        }
    }

    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    func rebuildIndex() {
        openDatabase()
        guard let db else { return }
        sqlite3_exec(db, "DROP TABLE IF EXISTS stories_fts", nil, nil, nil)
        let createSQL = "CREATE VIRTUAL TABLE IF NOT EXISTS stories_fts USING fts5(date, fact_text, source_info)"
        sqlite3_exec(db, createSQL, nil, nil, nil)
        UserDefaults.standard.set(3, forKey: "searchIndexVersion")
    }

    // MARK: - Index

    /// Writes a day's parsed stories into the FTS5 index.
    ///
    /// This method is transitional — the whole `SearchIndexer` class is being
    /// removed in the next phase in favor of a direct `@Query` + `#Predicate`
    /// search against SwiftData. During the transition, we keep FTS5 working by
    /// projecting already-parsed `ArchivedStory` rows into it, rather than
    /// re-parsing raw archive text.
    func indexDay(dateString: String, stories: [ArchivedStory]) {
        openDatabase()
        guard let db else { return }

        // Check if already indexed
        let checkSQL = "SELECT COUNT(*) FROM stories_fts WHERE date = ?"
        var checkStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK {
            sqlite3_bind_text(checkStmt, 1, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            if sqlite3_step(checkStmt) == SQLITE_ROW && sqlite3_column_int(checkStmt, 0) > 0 {
                sqlite3_finalize(checkStmt)
                return // Already indexed
            }
        }
        sqlite3_finalize(checkStmt)

        let insertSQL = "INSERT INTO stories_fts (date, fact_text, source_info) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK {
            for story in stories {
                let sources = story.sources.joined(separator: ", ")
                let ratings = story.ratings.joined(separator: ", ")
                let sourceInfo = sources.isEmpty ? "" : "\(sources) · \(ratings)"

                sqlite3_bind_text(stmt, 1, dateString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 2, story.factText, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(stmt, 3, sourceInfo, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_step(stmt)
                sqlite3_reset(stmt)
            }
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            print("[SearchIndexer] prepare insert failed: \(err)")
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Search

    func search(query: String) -> [SearchResult] {
        openDatabase()
        guard let db, !query.isEmpty else { return [] }

        let searchQuery = query.components(separatedBy: " ")
            .map { "\($0)*" }
            .joined(separator: " ")

        let sql = "SELECT date, fact_text, source_info FROM stories_fts WHERE stories_fts MATCH ? ORDER BY rank LIMIT 100"
        var stmt: OpaquePointer?
        var results: [SearchResult] = []

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, searchQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let date = String(cString: sqlite3_column_text(stmt, 0))
                let factText = String(cString: sqlite3_column_text(stmt, 1))
                let sourceInfo = String(cString: sqlite3_column_text(stmt, 2))
                results.append(SearchResult(date: date, factText: factText, sourceInfo: sourceInfo))
            }
        } else {
            let err = String(cString: sqlite3_errmsg(db))
            print("[SearchIndexer] prepare search failed: \(err) — query: \(searchQuery)")
        }
        sqlite3_finalize(stmt)
        return results
    }

    // MARK: - Progressive Indexing

    func performProgressiveIndex(modelContainer: ModelContainer) async {
        // Rebuild if index was created with old (broken) parser
        if UserDefaults.standard.integer(forKey: "searchIndexVersion") < 3 {
            rebuildIndex()
        }

        isIndexing = true
        indexProgress = 0

        let archiveService = ArchiveService(modelContainer: modelContainer)

        do {
            let dates = try await archiveService.fetchIndex()
            let recentDates = Array(dates.suffix(30)) // Last 30 days

            for (index, dateString) in recentDates.enumerated() {
                do {
                    let stories = try await archiveService.fetchDay(dateString: dateString)
                    indexDay(dateString: dateString, stories: stories)
                } catch {
                    // Skip unavailable days
                }
                indexProgress = Double(index + 1) / Double(recentDates.count)
            }
        } catch {
            // Graceful degradation
        }

        isIndexing = false
        indexProgress = 1.0
    }

    func performBackfillIndex(modelContainer: ModelContainer) async {
        let monitor = NWPathMonitor(requiredInterfaceType: .wifi)
        let queue = DispatchQueue(label: "wifi-check")

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            monitor.pathUpdateHandler = { path in
                if path.status == .satisfied {
                    continuation.resume()
                    monitor.cancel()
                }
            }
            monitor.start(queue: queue)

            // Timeout after 2 seconds
            queue.asyncAfter(deadline: .now() + 2) {
                monitor.cancel()
                continuation.resume()
            }
        }

        let archiveService = ArchiveService(modelContainer: modelContainer)
        do {
            let dates = try await archiveService.fetchIndex()
            let olderDates = Array(dates.dropLast(30))

            for dateString in olderDates {
                do {
                    let stories = try await archiveService.fetchDay(dateString: dateString)
                    indexDay(dateString: dateString, stories: stories)
                } catch {
                    continue
                }
            }
        } catch {
            // Graceful degradation
        }
    }
}

struct SearchResult: Identifiable, Sendable {
    let id = UUID()
    let date: String
    let factText: String
    let sourceInfo: String
}
