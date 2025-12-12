//
//  CSVReader.swift
//  Shared
//
//  Shared CSV v0.3 reader utilities.
//

import Foundation

public enum CSVReader {
    public static func readRows(from url: URL, fileManager: FileManager = .default) throws -> (columns: CSVSchemaV03.Columns, rows: [CSVRow]) {
        guard fileManager.fileExists(atPath: url.path) else {
            throw CSVIndexBuilderError.fileMissing
        }

        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents
            .split(maxSplits: .max, omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)
        guard let headerLine = lines.first else {
            throw CSVIndexBuilderError.invalidHeader
        }

        let headers = CSVRowParser.parse(line: headerLine)
        guard let columns = CSVSchemaV03.Columns(headers: headers) else {
            throw CSVIndexBuilderError.invalidHeader
        }

        var rows: [CSVRow] = []
        rows.reserveCapacity(max(0, lines.count - 1))

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let values = CSVRowParser.parse(line: line)
            if values.count != headers.count { continue }
            if let row = CSVRow(values: values, columns: columns) {
                rows.append(row)
            }
        }

        return (columns, rows)
    }
}
