//
//  WalReplay.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

struct WalReplay {
    let fileSystem: FileSystem
    let globalCsv: GlobalCsvWriting
    let indexRepository: IndexRepositorying

    func replayPendingSessions() {
        guard let metaFiles = try? fileSystem.listSessionMetaFiles() else { return }
        for url in metaFiles {
            guard let sessionID = extractSessionID(from: url) else { continue }
            guard var meta = try? loadMeta(at: url) else { continue }

            let now = Date()
            var retained: [SessionMeta.Pending] = []

            for pending in meta.pending {
                let deadline = pending.savedAt.addingTimeInterval(5)
                if now >= deadline {
                    do {
                        try globalCsv.appendCommitting(pending.row)
                        try indexRepository.applyCommit(pending.row)
                    } catch {
                        #if DEBUG
                        print("WalReplay: failed to commit pending row for session \(sessionID): \(error)")
                        #endif
                    }
                } else {
                    retained.append(pending)
                }
            }

            if retained.count != meta.pending.count {
                meta.pending = retained
                meta.sessionId = sessionID
                save(meta: meta, for: sessionID)
            }
        }
    }

    private func extractSessionID(from url: URL) -> String? {
        let filename = url.lastPathComponent
        guard filename.hasSuffix(".meta.json") else { return nil }
        return String(filename.dropLast(".meta.json".count))
    }

    private func loadMeta(at url: URL) throws -> SessionMeta {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SessionMeta.self, from: data)
    }

    private func save(meta: SessionMeta, for sessionID: String) {
        do {
            let url = try fileSystem.metaURL(for: sessionID)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(meta)
            try fileSystem.writeAtomic(data, to: url)
        } catch {
            #if DEBUG
            print("WalReplay: failed to persist meta for session \(sessionID): \(error)")
            #endif
        }
    }
}
