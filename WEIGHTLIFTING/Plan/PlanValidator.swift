//
//  PlanValidator.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-31.
//

import CryptoKit
import Foundation

struct PlanSummary: Equatable {
    let planName: String
    let unit: WeightUnit
    let dayCount: Int
    let scheduleOrder: [String]
    let unsupportedSegmentTypes: [String]
    let warnings: [String]
    let sha256: String
}

enum PlanValidationError: Error {
    case emptyData
    case decodingFailed(Error)
    case missingDays
}

struct PlanValidationResult {
    let summary: PlanSummary
    let plan: PlanV03
}

enum PlanValidator {
    static func validate(data: Data) throws -> PlanValidationResult {
        guard !data.isEmpty else { throw PlanValidationError.emptyData }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let plan: PlanV03
        do {
            plan = try decoder.decode(PlanV03.self, from: data)
        } catch {
            throw PlanValidationError.decodingFailed(error)
        }

        guard !plan.days.isEmpty else { throw PlanValidationError.missingDays }

        var unsupportedTypes = Set<String>()
        var totalSegments = 0
        for day in plan.days {
            for segment in day.segments {
                totalSegments += 1
                if case let .unsupported(rawType) = segment {
                    unsupportedTypes.insert(rawType)
                }
            }
        }

        var warnings: [String] = []
        if totalSegments == 0 {
            warnings.append("No segments detected in the schedule.")
        }

        if !unsupportedTypes.isEmpty {
            let sorted = unsupportedTypes.sorted()
            let segments = sorted.joined(separator: ",")
            warnings.append("Unsupported segment types: \(segments).")
        }

        let sha256 = Self.digest(for: data)
        let summary = PlanSummary(
            planName: plan.planName,
            unit: plan.unit,
            dayCount: plan.days.count,
            scheduleOrder: plan.scheduleOrder,
            unsupportedSegmentTypes: unsupportedTypes.sorted(),
            warnings: warnings,
            sha256: sha256
        )

        return PlanValidationResult(summary: summary, plan: plan)
    }

    private static func digest(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
