//
//  SegmentResolverTests.swift
//  WEIGHTLIFTINGTests
//
//  Created by Claude on 2025-12-10.
//  V0.4: Tests for SegmentResolver per_week and group_variants resolution
//

#if os(watchOS)

import XCTest
@testable import WEIGHTLIFTING
@testable import WEIGHTLIFTING_Watch_App

final class SegmentResolverTests: XCTestCase {

    var resolver: SegmentResolver!

    override func setUp() {
        super.setUp()
        #if os(watchOS)
        resolver = SegmentResolver()
        #endif
    }

    override func tearDown() {
        resolver = nil
        super.tearDown()
    }

    // MARK: - Straight Segment Tests

    func testResolveStraightSegmentWithoutOverrides() {
        #if os(watchOS)
        let segment = PlanV03.StraightSegment(
            exerciseCode: "SQUAT.BB",
            altGroup: nil,
            sets: 3,
            reps: RepetitionRange(min: 5, max: 5, text: nil),
            restSec: 120,
            rpe: 8.0,
            intensifier: nil,
            timeSec: nil,
            tags: ["test"]
        )

        let plan = makeMockPlan()
        let resolved = resolver.resolveStraight(segment: segment, currentWeek: 1, selectedExercise: nil, plan: plan)

        XCTAssertEqual(resolved.sets, 3)
        XCTAssertEqual(resolved.reps?.min, 5)
        XCTAssertEqual(resolved.restSec, 120)
        XCTAssertEqual(resolved.rpe, 8.0)
        XCTAssertEqual(resolved.tags, ["test"])
        #endif
    }

    func testResolveStraightSegmentWithPerWeekOverlay() {
        #if os(watchOS)
        let perWeek: [String: PartialSegment] = [
            "2": PartialSegment(sets: 5, reps: RepetitionRange(min: 3, max: 3, text: nil), restSec: 180, rpe: nil, intensifier: nil, timeSec: nil)
        ]

        let segment = PlanV03.StraightSegment(
            exerciseCode: "SQUAT.BB",
            altGroup: nil,
            sets: 3,
            reps: RepetitionRange(min: 5, max: 5, text: nil),
            restSec: 120,
            rpe: 8.0,
            intensifier: nil,
            timeSec: nil,
            tags: nil,
            perWeek: perWeek,
            groupRole: nil,
            loadAxisTarget: nil
        )

        let plan = makeMockPlan()

        // Week 1: should use base values
        let resolved1 = resolver.resolveStraight(segment: segment, currentWeek: 1, selectedExercise: nil, plan: plan)
        XCTAssertEqual(resolved1.sets, 3)
        XCTAssertEqual(resolved1.reps?.min, 5)
        XCTAssertEqual(resolved1.restSec, 120)

        // Week 2: should use per_week overlay
        let resolved2 = resolver.resolveStraight(segment: segment, currentWeek: 2, selectedExercise: nil, plan: plan)
        XCTAssertEqual(resolved2.sets, 5)
        XCTAssertEqual(resolved2.reps?.min, 3)
        XCTAssertEqual(resolved2.restSec, 180)
        XCTAssertEqual(resolved2.rpe, 8.0) // RPE not overridden, uses base
        #endif
    }

    func testResolveStraightSegmentWithGroupVariants() {
        #if os(watchOS)
        let groupVariants: [String: [String: [String: GroupVariantConfig]]] = [
            "legs": [
                "heavy": [
                    "SQUAT.BB": GroupVariantConfig(sets: 5, reps: RepetitionRange(min: 3, max: 5, text: nil), restSec: 240, intensifier: nil)
                ]
            ]
        ]

        let segment = PlanV03.StraightSegment(
            exerciseCode: "SQUAT.BB",
            altGroup: "legs",
            sets: 3,
            reps: RepetitionRange(min: 8, max: 12, text: nil),
            restSec: 120,
            rpe: 8.0,
            intensifier: nil,
            timeSec: nil,
            tags: nil,
            perWeek: nil,
            groupRole: "heavy",
            loadAxisTarget: nil
        )

        let plan = makeMockPlan(groupVariants: groupVariants)
        let resolved = resolver.resolveStraight(segment: segment, currentWeek: 1, selectedExercise: "SQUAT.BB", plan: plan)

        XCTAssertEqual(resolved.sets, 5)
        XCTAssertEqual(resolved.reps?.min, 3)
        XCTAssertEqual(resolved.reps?.max, 5)
        XCTAssertEqual(resolved.restSec, 240)
        XCTAssertEqual(resolved.rpe, 8.0) // RPE not overridden by group_variants
        #endif
    }

    func testResolveStraightSegmentWithBothOverlays() {
        #if os(watchOS)
        // per_week applies first, then group_variants
        let perWeek: [String: PartialSegment] = [
            "1": PartialSegment(sets: 4, reps: nil, restSec: 150, rpe: nil, intensifier: nil, timeSec: nil)
        ]

        let groupVariants: [String: [String: [String: GroupVariantConfig]]] = [
            "legs": [
                "heavy": [
                    "SQUAT.BB": GroupVariantConfig(sets: 5, reps: RepetitionRange(min: 3, max: 5, text: nil), restSec: nil, intensifier: nil)
                ]
            ]
        ]

        let segment = PlanV03.StraightSegment(
            exerciseCode: "SQUAT.BB",
            altGroup: "legs",
            sets: 3,
            reps: RepetitionRange(min: 8, max: 12, text: nil),
            restSec: 120,
            rpe: 8.0,
            intensifier: nil,
            timeSec: nil,
            tags: nil,
            perWeek: perWeek,
            groupRole: "heavy",
            loadAxisTarget: nil
        )

        let plan = makeMockPlan(groupVariants: groupVariants)
        let resolved = resolver.resolveStraight(segment: segment, currentWeek: 1, selectedExercise: "SQUAT.BB", plan: plan)

        // per_week sets to 4, then group_variants overrides to 5
        XCTAssertEqual(resolved.sets, 5)
        // per_week doesn't override reps, group_variants sets it
        XCTAssertEqual(resolved.reps?.min, 3)
        XCTAssertEqual(resolved.reps?.max, 5)
        // per_week sets rest to 150, group_variants doesn't override
        XCTAssertEqual(resolved.restSec, 150)
        #endif
    }

    // MARK: - Percentage Segment Tests

    func testResolvePercentageSegmentWithoutOverlay() {
        #if os(watchOS)
        let basePrescriptions = [
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 5, max: 5, text: nil), pctRM: 0.65, intensifier: nil),
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 5, max: 5, text: nil), pctRM: 0.75, intensifier: nil),
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 5, max: 5, text: nil), pctRM: 0.85, intensifier: Intensifier(kind: .amrap, when: "last_set", dropPct: nil, steps: nil))
        ]

        let segment = PlanV03.PercentageSegment(
            exerciseCode: "SQUAT.BB",
            prescriptions: basePrescriptions,
            perWeek: nil
        )

        let resolved = resolver.resolvePercentage(segment: segment, currentWeek: 1)

        XCTAssertEqual(resolved.count, 3)
        XCTAssertEqual(resolved[0].pctRM, 0.65)
        XCTAssertEqual(resolved[2].intensifier?.kind, .amrap)
        #endif
    }

    func testResolvePercentageSegmentWithPerWeekReplacement() {
        #if os(watchOS)
        let basePrescriptions = [
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 5, max: 5, text: nil), pctRM: 0.65, intensifier: nil)
        ]

        let week2Prescriptions = [
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 3, max: 3, text: nil), pctRM: 0.70, intensifier: nil),
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 3, max: 3, text: nil), pctRM: 0.80, intensifier: nil),
            PercentagePrescription(sets: 1, reps: RepetitionRange(min: 3, max: 3, text: nil), pctRM: 0.90, intensifier: Intensifier(kind: .amrap, when: "last_set", dropPct: nil, steps: nil))
        ]

        let perWeek: [String: PercentageOverlay] = [
            "2": PercentageOverlay(prescriptions: week2Prescriptions)
        ]

        let segment = PlanV03.PercentageSegment(
            exerciseCode: "SQUAT.BB",
            prescriptions: basePrescriptions,
            perWeek: perWeek
        )

        // Week 1: use base prescriptions
        let resolved1 = resolver.resolvePercentage(segment: segment, currentWeek: 1)
        XCTAssertEqual(resolved1.count, 1)
        XCTAssertEqual(resolved1[0].pctRM, 0.65)

        // Week 2: REPLACE with per_week prescriptions
        let resolved2 = resolver.resolvePercentage(segment: segment, currentWeek: 2)
        XCTAssertEqual(resolved2.count, 3)
        XCTAssertEqual(resolved2[0].pctRM, 0.70)
        XCTAssertEqual(resolved2[1].pctRM, 0.80)
        XCTAssertEqual(resolved2[2].pctRM, 0.90)
        XCTAssertEqual(resolved2[2].intensifier?.kind, .amrap)
        #endif
    }

    // MARK: - Helper Methods

    private func makeMockPlan(groupVariants: [String: [String: [String: GroupVariantConfig]]]? = nil) -> PlanV03 {
        let day = PlanV03.Day(label: "Test Day", segments: [], dayNumber: nil)
        return PlanV03(
            planName: "Test Plan",
            unit: .pounds,
            exerciseNames: ["SQUAT.BB": "Back Squat"],
            altGroups: ["legs": ["SQUAT.BB", "PRESS.LEG"]],
            days: [day],
            scheduleOrder: ["Test Day"],
            groupVariants: groupVariants,
            phase: nil
        )
    }
}

#endif
