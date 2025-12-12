//
//  CSVRowParser.swift
//  Shared
//
//  A small, newline-friendly CSV row parser shared by the iOS app and
//  watch app. Handles quoted fields, escaped quotes, commas inside quotes,
//  and ignores trailing carriage returns.
//

import Foundation

public enum CSVRowParser {
    /// Parse a single CSV line into columns.
    /// - Parameter line: Raw line (without trailing newline).
    /// - Returns: Array of column values in order.
    public static func parse(line: String) -> [String] {
        var result: [String] = []
        var buffer = ""
        var insideQuotes = false
        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if insideQuotes && index + 1 < characters.count && characters[index + 1] == "\"" {
                    buffer.append("\"")
                    index += 2
                    continue
                }
                insideQuotes.toggle()
                index += 1
                continue
            }

            if character == "," && !insideQuotes {
                result.append(buffer)
                buffer.removeAll(keepingCapacity: true)
                index += 1
                continue
            }

            if character == "\r" {
                index += 1
                continue
            }

            buffer.append(character)
            index += 1
        }

        result.append(buffer)
        return result
    }
}
