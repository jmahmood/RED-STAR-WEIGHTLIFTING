import Foundation
import Combine
import SQLite3

public final class StoredLinkStore: ObservableObject {
    public static let shared = StoredLinkStore()

    private let dbURL: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "StoredLinkStore.sqlite")
    // Swift doesn't expose SQLITE_TRANSIENT; define for bind APIs.
    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(
        appGroupID: String = "group.com.jawaadmahmood.WEIGHTLIFTING_SHARED",
        fileManager: FileManager = .default
    ) {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            dbURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("stored_links.sqlite3")
            return
        }
        dbURL = container.appendingPathComponent("stored_links.sqlite3")
        openAndMigrate()
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    private func openAndMigrate() {
        queue.sync {
            if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
                print("StoredLinkStore: failed to open db at \(dbURL.path)")
                return
            }

            let createSQL = """
            CREATE TABLE IF NOT EXISTS stored_links (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT NOT NULL UNIQUE,
                kind TEXT NOT NULL,
                title TEXT,
                created_at REAL NOT NULL
            );
            """
            if sqlite3_exec(db, createSQL, nil, nil, nil) != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                print("StoredLinkStore: failed to create table: \(msg)")
            }

            // Lightweight migration for older installs without title column.
            if !self.columnExists("title", in: "stored_links") {
                let alterSQL = "ALTER TABLE stored_links ADD COLUMN title TEXT;"
                _ = sqlite3_exec(db, alterSQL, nil, nil, nil)
            }
        }
    }

    public func addSharedURL(_ url: URL, title: String? = nil) {
        let kind = classify(url)
        let ts = Date().timeIntervalSince1970
        let normalizedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = (normalizedTitle?.isEmpty == false) ? normalizedTitle : nil
        queue.async {
            guard let db = self.db else { return }
            let insertSQL = "INSERT OR IGNORE INTO stored_links (url, kind, title, created_at) VALUES (?, ?, ?, ?);"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, insertSQL, -1, &stmt, nil) == SQLITE_OK else {
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, url.absoluteString, -1, self.sqliteTransient)
            sqlite3_bind_text(stmt, 2, kind.rawValue, -1, self.sqliteTransient)
            if let finalTitle {
                sqlite3_bind_text(stmt, 3, finalTitle, -1, self.sqliteTransient)
            } else {
                sqlite3_bind_null(stmt, 3)
            }
            sqlite3_bind_double(stmt, 4, ts)

            _ = sqlite3_step(stmt)

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }

    public func fetchAllGrouped() -> [StoredLinkKind: [StoredLink]] {
        var result: [StoredLinkKind: [StoredLink]] = [:]
        StoredLinkKind.allCases.forEach { result[$0] = [] }

        return queue.sync {
            guard let db = db else { return result }
            let querySQL = "SELECT id, url, kind, title, created_at FROM stored_links ORDER BY created_at DESC;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, querySQL, -1, &stmt, nil) == SQLITE_OK else {
                return result
            }
            defer { sqlite3_finalize(stmt) }

            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                guard let urlC = sqlite3_column_text(stmt, 1),
                      let kindC = sqlite3_column_text(stmt, 2)
                else { continue }
                let urlStr = String(cString: urlC)
                let kindStr = String(cString: kindC)
                let title: String?
                if let titleC = sqlite3_column_text(stmt, 3) {
                    title = String(cString: titleC)
                } else {
                    title = nil
                }
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
                guard let url = URL(string: urlStr),
                      let kind = StoredLinkKind(rawValue: kindStr)
                else { continue }
                result[kind, default: []].append(StoredLink(id: id, url: url, kind: kind, title: title, createdAt: createdAt))
            }
            return result
        }
    }

    public func delete(_ link: StoredLink) {
        queue.async {
            guard let db = self.db else { return }
            let deleteSQL = "DELETE FROM stored_links WHERE id = ?;"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, deleteSQL, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int64(stmt, 1, link.id)
            _ = sqlite3_step(stmt)
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }

    private func classify(_ url: URL) -> StoredLinkKind {
        let host = (url.host ?? "").lowercased()
        if host == "music.youtube.com" {
            return .music
        }
        if host.contains("youtube.com") || host == "youtu.be" {
            return .video
        }
        return .reading
    }

    private func columnExists(_ column: String, in table: String) -> Bool {
        guard let db else { return false }
        let pragmaSQL = "PRAGMA table_info(\(table));"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, pragmaSQL, -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let nameC = sqlite3_column_text(stmt, 1) {
                let name = String(cString: nameC)
                if name == column { return true }
            }
        }
        return false
    }
}
