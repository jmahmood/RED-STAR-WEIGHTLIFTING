//
//  FileSystem.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Darwin
import Foundation

struct FileSystem {
    enum FileError: Swift.Error {
        case containerURLUnavailable
        case couldNotCreateDirectory(URL)
        case fileHandleUnavailable(URL)
    }

    enum Directory: String {
        case global = "Global"
        case sessions = "Sessions"
        case plans = "Plans"
    }

    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager) {
        self.fileManager = fileManager
        if let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let root = applicationSupport.appendingPathComponent("WeightWatch", isDirectory: true)
            try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            self.rootURL = root
        } else {
            self.rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("WeightWatch", isDirectory: true)
            try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - Public URLs

    func walURL(for sessionID: String) throws -> URL {
        let directory = try directoryURL(.sessions)
        return directory.appendingPathComponent("\(sessionID).wal.json", isDirectory: false)
    }

    func metaURL(for sessionID: String) throws -> URL {
        let directory = try directoryURL(.sessions)
        return directory.appendingPathComponent("\(sessionID).meta.json", isDirectory: false)
    }

    func globalCsvURL() throws -> URL {
        let directory = try directoryURL(.global)
        return directory.appendingPathComponent("all_time.csv", isDirectory: false)
    }

    func indexURL() throws -> URL {
        let directory = try directoryURL(.global)
        return directory.appendingPathComponent("index_last_by_ex.json", isDirectory: false)
    }

    func planURL(named filename: String) throws -> URL {
        let directory = try directoryURL(.plans)
        return directory.appendingPathComponent(filename, isDirectory: false)
    }

    func listSessionMetaFiles() throws -> [URL] {
        let directory = try directoryURL(.sessions)
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
        return contents.filter { $0.lastPathComponent.hasSuffix(".meta.json") }
    }

    func listWalFiles() throws -> [URL] {
        let directory = try directoryURL(.sessions)
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
        return contents.filter { $0.lastPathComponent.hasSuffix(".wal.json") }
    }

    // MARK: - File operations

    @discardableResult
    func ensureFile(at url: URL, contents: Data?) throws -> URL {
        let folder = url.deletingLastPathComponent()
        try ensureDirectoryExists(at: folder)
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: contents)
        }
        return url
    }

    func append(_ data: Data, to url: URL, performFsync: Bool) throws {
        try ensureFile(at: url, contents: nil)
        guard let handle = FileHandle(forWritingAtPath: url.path) else {
            throw FileError.fileHandleUnavailable(url)
        }
        defer { try? handle.close() }

        try handle.seekToEnd()
        try handle.write(contentsOf: data)

        if performFsync {
            #if os(watchOS)
            fsync(handle.fileDescriptor)
            #endif
        }
    }

    func writeAtomic(_ data: Data, to url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try ensureDirectoryExists(at: folder)

        let tempURL = folder.appendingPathComponent(UUID().uuidString)
        try data.write(to: tempURL, options: .atomic)
        _ = try fileManager.replaceItemAt(url, withItemAt: tempURL)
    }

    func copyIfMissing(from sourceURL: URL, to destinationURL: URL) throws {
        let folder = destinationURL.deletingLastPathComponent()
        try ensureDirectoryExists(at: folder)
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    func fileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    func fsyncDirectory(containing fileURL: URL) {
        let directoryURL = fileURL.deletingLastPathComponent()
        directoryURL.path.withCString { pointer in
            let fd = open(pointer, O_RDONLY)
            if fd >= 0 {
                fsync(fd)
                close(fd)
            }
        }
    }

    func ensureDirectoryExists(at url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                throw FileError.couldNotCreateDirectory(url)
            }
        }
    }

    func removeDirectoryContents(_ directory: Directory) throws {
        let target = try directoryURL(directory)
        let contents = try fileManager.contentsOfDirectory(at: target, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }

    func availableBytes() -> Int64? {
        return try? fileManager.attributesOfFileSystem(forPath: rootURL.path)[.systemFreeSize] as? Int64
    }

    func fileSize(at url: URL) throws -> UInt64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? UInt64 ?? 0
    }

    // MARK: - Helpers

    private func directoryURL(_ directory: Directory) throws -> URL {
        let target = rootURL.appendingPathComponent(directory.rawValue, isDirectory: true)
        try ensureDirectoryExists(at: target)
        return target
    }
}
