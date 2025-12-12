//
//  TemplateRepository.swift
//  WEIGHTLIFTING
//
//  Created by Claude Code on 2025-12-11.
//

import Foundation

// MARK: - Template Models

public struct TemplateSegment {
    public let exerciseCode: String
    public let sets: Int
    public let repsMin: Int
    public let repsMax: Int
    public let sequence: Int

    public init(exerciseCode: String, sets: Int, repsMin: Int, repsMax: Int, sequence: Int) {
        self.exerciseCode = exerciseCode
        self.sets = sets
        self.repsMin = repsMin
        self.repsMax = repsMax
        self.sequence = sequence
    }
}

public struct TemplateDay {
    public let templateID: String
    public let category: String
    public let displayName: String
    public let sourceName: String?
    public let videoURL: String?
    public let dayLabel: String
    public let segments: [TemplateSegment]

    public init(
        templateID: String,
        category: String,
        displayName: String,
        sourceName: String?,
        videoURL: String?,
        dayLabel: String,
        segments: [TemplateSegment]
    ) {
        self.templateID = templateID
        self.category = category
        self.displayName = displayName
        self.sourceName = sourceName
        self.videoURL = videoURL
        self.dayLabel = dayLabel
        self.segments = segments
    }
}

// MARK: - Template Repository

public final class TemplateRepository {
    private let templates: [TemplateDay]

    public init(csvURL: URL) throws {
        self.templates = try Self.parseCSV(url: csvURL)
    }

    public var allTemplates: [TemplateDay] {
        templates
    }

    public func templatesByCategory() -> [String: [TemplateDay]] {
        Dictionary(grouping: templates, by: { $0.category })
    }

    public func template(byID templateID: String) -> TemplateDay? {
        templates.first { $0.templateID == templateID }
    }

    // MARK: - CSV Parsing

    private static func parseCSV(url: URL) throws -> [TemplateDay] {
        let csvContent = try String(contentsOf: url, encoding: .utf8)
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty && !$0.starts(with: "#") }

        guard lines.count > 1 else {
            // Empty CSV or only header - return empty array
            return []
        }

        // Parse header
        let header = lines[0].components(separatedBy: ",")
        let expectedHeader = ["template_id", "category", "display_name", "source_name", "video_url", "day_label", "sequence", "ex_code", "sets", "reps_min", "reps_max"]

        guard header == expectedHeader else {
            print("TemplateRepository: Invalid CSV header. Expected: \(expectedHeader), Got: \(header)")
            throw TemplateError.invalidCSVHeader
        }

        // Parse rows
        var rowsByTemplateID: [String: [CSVRow]] = [:]

        for line in lines.dropFirst() {
            let row = try parseCSVRow(line)
            rowsByTemplateID[row.templateID, default: []].append(row)
        }

        // Build templates
        var templates: [TemplateDay] = []

        for (templateID, rows) in rowsByTemplateID {
            guard let firstRow = rows.first else { continue }

            let segments = rows
                .sorted { $0.sequence < $1.sequence }
                .map { row in
                    TemplateSegment(
                        exerciseCode: row.exerciseCode,
                        sets: row.sets,
                        repsMin: row.repsMin,
                        repsMax: row.repsMax,
                        sequence: row.sequence
                    )
                }

            let template = TemplateDay(
                templateID: templateID,
                category: firstRow.category,
                displayName: firstRow.displayName,
                sourceName: firstRow.sourceName.isEmpty ? nil : firstRow.sourceName,
                videoURL: firstRow.videoURL.isEmpty ? nil : firstRow.videoURL,
                dayLabel: firstRow.dayLabel,
                segments: segments
            )

            templates.append(template)
        }

        return templates.sorted { $0.category < $1.category || ($0.category == $1.category && $0.displayName < $1.displayName) }
    }

    private struct CSVRow {
        let templateID: String
        let category: String
        let displayName: String
        let sourceName: String
        let videoURL: String
        let dayLabel: String
        let sequence: Int
        let exerciseCode: String
        let sets: Int
        let repsMin: Int
        let repsMax: Int
    }

    private static func parseCSVRow(_ line: String) throws -> CSVRow {
        let fields = line.components(separatedBy: ",")

        guard fields.count == 11 else {
            throw TemplateError.invalidCSVRow(line)
        }

        guard let sequence = Int(fields[6]),
              let sets = Int(fields[8]),
              let repsMin = Int(fields[9]),
              let repsMax = Int(fields[10]) else {
            throw TemplateError.invalidCSVRow(line)
        }

        return CSVRow(
            templateID: fields[0],
            category: fields[1],
            displayName: fields[2],
            sourceName: fields[3],
            videoURL: fields[4],
            dayLabel: fields[5],
            sequence: sequence,
            exerciseCode: fields[7],
            sets: sets,
            repsMin: repsMin,
            repsMax: repsMax
        )
    }
}

// MARK: - Errors

public enum TemplateError: Error {
    case invalidCSVHeader
    case invalidCSVRow(String)
}
