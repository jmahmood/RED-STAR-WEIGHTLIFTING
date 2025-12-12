//
//  SegmentResolver.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Claude on 2025-12-10.
//  V0.4: Resolves segment data by applying per_week overlays and group_variants
//

import Foundation

#if os(watchOS)

/// Resolved segment data after applying per_week and group_variants
struct ResolvedSegmentData {
    var sets: Int
    var reps: PlanV03.RepetitionRange?
    var restSec: Int?
    var rpe: Double?
    var intensifier: PlanV03.Intensifier?
    var timeSec: Int?
    var loadAxisTarget: PlanV03.LoadAxisTarget?
    var tags: [String]

    init(
        sets: Int,
        reps: PlanV03.RepetitionRange?,
        restSec: Int?,
        rpe: Double?,
        intensifier: PlanV03.Intensifier?,
        timeSec: Int?,
        loadAxisTarget: PlanV03.LoadAxisTarget?,
        tags: [String] = []
    ) {
        self.sets = sets
        self.reps = reps
        self.restSec = restSec
        self.rpe = rpe
        self.intensifier = intensifier
        self.timeSec = timeSec
        self.loadAxisTarget = loadAxisTarget
        self.tags = tags
    }
}

/// Protocol for segment resolution
protocol SegmentResolving {
    func resolveStraight(
        segment: PlanV03.StraightSegment,
        currentWeek: Int,
        selectedExercise: String?,
        plan: PlanV03
    ) -> ResolvedSegmentData

    func resolveScheme(
        segment: PlanV03.SchemeSegment,
        entry: PlanV03.SchemeSegment.Entry,
        currentWeek: Int,
        selectedExercise: String?,
        plan: PlanV03
    ) -> ResolvedSegmentData

    func resolveSupersetItem(
        item: PlanV03.SupersetSegment.Item,
        currentWeek: Int,
        selectedExercise: String?,
        plan: PlanV03
    ) -> ResolvedSegmentData

    func resolvePercentage(
        segment: PlanV03.PercentageSegment,
        currentWeek: Int
    ) -> [PlanV03.PercentagePrescription]
}

/// Segment resolver implementation
struct SegmentResolver: SegmentResolving {

    // MARK: - Straight Segment Resolution

    func resolveStraight(
        segment: PlanV03.StraightSegment,
        currentWeek: Int,
        selectedExercise: String?,
        plan: PlanV03
    ) -> ResolvedSegmentData {
        // Start with base segment values
        var resolved = ResolvedSegmentData(
            sets: segment.sets,
            reps: segment.reps,
            restSec: segment.restSec,
            rpe: segment.rpe,
            intensifier: segment.intensifier,
            timeSec: segment.timeSec,
            loadAxisTarget: segment.loadAxisTarget,
            tags: segment.tags ?? []
        )

        // Step 1: Apply per_week overlay (shallow merge)
        if let overlay = segment.perWeek?["\(currentWeek)"] {
            resolved.sets = overlay.sets ?? resolved.sets
            resolved.reps = overlay.reps ?? resolved.reps
            resolved.restSec = overlay.restSec ?? resolved.restSec
            resolved.rpe = overlay.rpe ?? resolved.rpe
            resolved.intensifier = overlay.intensifier ?? resolved.intensifier
            resolved.timeSec = overlay.timeSec ?? resolved.timeSec
        }

        // Step 2: Apply group_variants (shallow merge)
        // Note: group_variants do NOT override rpe, timeSec, loadAxisTarget
        if let role = segment.groupRole,
           let group = segment.altGroup,
           let exerciseCode = selectedExercise,
           let variant = plan.groupVariants[group]?[role]?[exerciseCode] {
            resolved.sets = variant.sets ?? resolved.sets
            resolved.reps = variant.reps ?? resolved.reps
            resolved.restSec = variant.restSec ?? resolved.restSec
            resolved.intensifier = variant.intensifier ?? resolved.intensifier
        }

        return resolved
    }

    // MARK: - Scheme Segment Resolution

    func resolveScheme(
        segment: PlanV03.SchemeSegment,
        entry: PlanV03.SchemeSegment.Entry,
        currentWeek: Int,
        selectedExercise: String?,
        plan: PlanV03
    ) -> ResolvedSegmentData {
        // Start with base entry values, falling back to segment defaults
        var resolved = ResolvedSegmentData(
            sets: entry.sets,
            reps: entry.reps,
            restSec: entry.restSec ?? segment.restSec,
            rpe: nil, // Scheme doesn't have RPE
            intensifier: entry.intensifier ?? segment.intensifier,
            timeSec: nil, // Scheme doesn't have timeSec
            loadAxisTarget: segment.loadAxisTarget,
            tags: []
        )

        // Step 1: Apply per_week overlay (shallow merge)
        if let overlay = segment.perWeek?["\(currentWeek)"] {
            resolved.sets = overlay.sets ?? resolved.sets
            resolved.reps = overlay.reps ?? resolved.reps
            resolved.restSec = overlay.restSec ?? resolved.restSec
            resolved.intensifier = overlay.intensifier ?? resolved.intensifier
        }

        // Step 2: Apply group_variants (shallow merge)
        if let role = segment.groupRole,
           let group = segment.altGroup,
           let exerciseCode = selectedExercise,
           let variant = plan.groupVariants[group]?[role]?[exerciseCode] {
            resolved.sets = variant.sets ?? resolved.sets
            resolved.reps = variant.reps ?? resolved.reps
            resolved.restSec = variant.restSec ?? resolved.restSec
            resolved.intensifier = variant.intensifier ?? resolved.intensifier
        }

        return resolved
    }

    // MARK: - Superset Item Resolution

    func resolveSupersetItem(
        item: PlanV03.SupersetSegment.Item,
        currentWeek: Int,
        selectedExercise: String?,
        plan: PlanV03
    ) -> ResolvedSegmentData {
        // Start with base item values
        var resolved = ResolvedSegmentData(
            sets: item.sets,
            reps: item.reps,
            restSec: item.restSec,
            rpe: nil, // Superset items don't have RPE
            intensifier: item.intensifier,
            timeSec: nil, // Superset items don't have timeSec
            loadAxisTarget: item.loadAxisTarget,
            tags: []
        )

        // Step 1: Apply per_week overlay (shallow merge)
        if let overlay = item.perWeek?["\(currentWeek)"] {
            resolved.sets = overlay.sets ?? resolved.sets
            resolved.reps = overlay.reps ?? resolved.reps
            resolved.restSec = overlay.restSec ?? resolved.restSec
            resolved.intensifier = overlay.intensifier ?? resolved.intensifier
        }

        // Step 2: Apply group_variants (shallow merge)
        if let role = item.groupRole,
           let group = item.altGroup,
           let exerciseCode = selectedExercise,
           let variant = plan.groupVariants[group]?[role]?[exerciseCode] {
            resolved.sets = variant.sets ?? resolved.sets
            resolved.reps = variant.reps ?? resolved.reps
            resolved.restSec = variant.restSec ?? resolved.restSec
            resolved.intensifier = variant.intensifier ?? resolved.intensifier
        }

        return resolved
    }

    // MARK: - Percentage Segment Resolution

    func resolvePercentage(
        segment: PlanV03.PercentageSegment,
        currentWeek: Int
    ) -> [PlanV03.PercentagePrescription] {
        // Step 1: Check per_week overlay
        // IMPORTANT: For percentage segments, per_week REPLACES entire prescriptions array
        if let overlay = segment.perWeek?["\(currentWeek)"],
           let weekPrescriptions = overlay.prescriptions {
            return weekPrescriptions
        }

        // Step 2: Use base prescriptions
        return segment.prescriptions
    }
}

#endif
