//
//  CycleManagerTests.swift
//  WEIGHTLIFTINGTests
//
//  Created by Claude on 2025-12-10.
//  V0.4: Tests for CycleManager week advancement and cycle tracking
//

#if os(watchOS)

import XCTest
@testable import WEIGHTLIFTING
@testable import WEIGHTLIFTING_Watch_App

final class CycleManagerTests: XCTestCase {

    var cycleManager: CycleManager!

    override func setUp() {
        super.setUp()
        #if os(watchOS)
        cycleManager = CycleManager()
        #endif
    }

    override func tearDown() {
        cycleManager = nil
        super.tearDown()
    }

    // MARK: - Week Advancement Detection Tests

    func testShouldAdvanceWeekWhenAllDaysCompleted() {
        #if os(watchOS)
        let meta = SessionMeta(
            sessionId: "test",
            planName: "Test Plan",
            dayLabel: "Day C",
            deckHash: "hash",
            switchHistory: ["Day A", "Day B", "Day C"],
            sessionCompleted: true,
            cycleWeek: 1,
            cycleId: "2025-W50"
        )

        let plan = makeMockPlan(scheduleOrder: ["Day A", "Day B", "Day C"])

        let shouldAdvance = cycleManager.shouldAdvanceWeek(meta: meta, plan: plan)
        XCTAssertTrue(shouldAdvance, "Should advance when all days completed")
        #endif
    }

    func testShouldNotAdvanceWeekWhenNotAllDaysCompleted() {
        #if os(watchOS)
        let meta = SessionMeta(
            sessionId: "test",
            planName: "Test Plan",
            dayLabel: "Day B",
            deckHash: "hash",
            switchHistory: ["Day A", "Day B"],
            sessionCompleted: true,
            cycleWeek: 1,
            cycleId: "2025-W50"
        )

        let plan = makeMockPlan(scheduleOrder: ["Day A", "Day B", "Day C"])

        let shouldAdvance = cycleManager.shouldAdvanceWeek(meta: meta, plan: plan)
        XCTAssertFalse(shouldAdvance, "Should not advance when not all days completed")
        #endif
    }

    func testShouldNotAdvanceWeekWhenSessionNotCompleted() {
        #if os(watchOS)
        let meta = SessionMeta(
            sessionId: "test",
            planName: "Test Plan",
            dayLabel: "Day C",
            deckHash: "hash",
            switchHistory: ["Day A", "Day B", "Day C"],
            sessionCompleted: false, // Not completed
            cycleWeek: 1,
            cycleId: "2025-W50"
        )

        let plan = makeMockPlan(scheduleOrder: ["Day A", "Day B", "Day C"])

        let shouldAdvance = cycleManager.shouldAdvanceWeek(meta: meta, plan: plan)
        XCTAssertFalse(shouldAdvance, "Should not advance when session not completed")
        #endif
    }

    // MARK: - Week Advancement Tests

    func testAdvanceWeekIncrementsWeek() {
        #if os(watchOS)
        let meta = SessionMeta(
            sessionId: "test",
            planName: "Test Plan",
            dayLabel: "Day C",
            deckHash: "hash",
            switchHistory: ["Day A", "Day B", "Day C"],
            sessionCompleted: true,
            cycleWeek: 1,
            cycleId: "2025-W50"
        )

        let plan = makeMockPlanWithPhase(weeks: [1, 2, 3])

        let (newWeek, newCycleId) = cycleManager.advanceWeek(meta: meta, plan: plan)

        XCTAssertEqual(newWeek, 2, "Week should increment from 1 to 2")
        XCTAssertFalse(newCycleId.isEmpty, "Cycle ID should not be empty")
        XCTAssertTrue(newCycleId.starts(with: "2025-W"), "Cycle ID should be in YYYY-Www format")
        #endif
    }

    func testAdvanceWeekWrapsAround() {
        #if os(watchOS)
        let meta = SessionMeta(
            sessionId: "test",
            planName: "Test Plan",
            dayLabel: "Day C",
            deckHash: "hash",
            switchHistory: ["Day A", "Day B", "Day C"],
            sessionCompleted: true,
            cycleWeek: 3, // Last week
            cycleId: "2025-W50"
        )

        let plan = makeMockPlanWithPhase(weeks: [1, 2, 3])

        let (newWeek, _) = cycleManager.advanceWeek(meta: meta, plan: plan)

        XCTAssertEqual(newWeek, 1, "Week should wrap around from 3 to 1")
        #endif
    }

    // MARK: - Max Week Detection Tests

    func testDetectMaxWeekFromPhase() {
        #if os(watchOS)
        let plan = makeMockPlanWithPhase(weeks: [1, 2, 3, 4])

        let maxWeek = cycleManager.detectMaxWeek(plan: plan)

        XCTAssertEqual(maxWeek, 4, "Max week should be detected from phase.weeks")
        #endif
    }

    func testDetectMaxWeekFromPerWeekKeys() {
        #if os(watchOS)
        // Plan with per_week overlays but no phase
        let perWeek: [String: PartialSegment] = [
            "1": PartialSegment(sets: 3, reps: nil, restSec: nil, rpe: nil, intensifier: nil, timeSec: nil),
            "2": PartialSegment(sets: 4, reps: nil, restSec: nil, rpe: nil, intensifier: nil, timeSec: nil),
            "3": PartialSegment(sets: 5, reps: nil, restSec: nil, rpe: nil, intensifier: nil, timeSec: nil)
        ]

        let segment = PlanV03.StraightSegment(
            exerciseCode: "SQUAT.BB",
            altGroup: nil,
            sets: 3,
            reps: nil,
            restSec: nil,
            rpe: nil,
            intensifier: nil,
            timeSec: nil,
            tags: nil,
            perWeek: perWeek,
            groupRole: nil,
            loadAxisTarget: nil
        )

        let day = PlanV03.Day(label: "Test Day", segments: [.straight(segment)], dayNumber: nil)
        let plan = PlanV03(
            planName: "Test Plan",
            unit: .pounds,
            exerciseNames: [:],
            altGroups: [:],
            days: [day],
            scheduleOrder: ["Test Day"],
            phase: nil,
            groupVariants: nil
        )

        let maxWeek = cycleManager.detectMaxWeek(plan: plan)

        XCTAssertEqual(maxWeek, 3, "Max week should be detected from per_week keys")
        #endif
    }

    func testDetectMaxWeekDefaultsToOne() {
        #if os(watchOS)
        let plan = makeMockPlan(scheduleOrder: ["Day A"])

        let maxWeek = cycleManager.detectMaxWeek(plan: plan)

        XCTAssertEqual(maxWeek, 1, "Max week should default to 1 when no phase or per_week")
        #endif
    }

    // MARK: - Cycle ID Generation Tests

    func testComputeCycleIdFormat() {
        #if os(watchOS)
        let date = Date() // Current date
        let cycleId = cycleManager.computeCycleId(week: 1, startDate: date)

        XCTAssertTrue(cycleId.starts(with: "2025-W"), "Cycle ID should start with year-W")
        XCTAssertTrue(cycleId.count >= 8, "Cycle ID should be at least 8 characters (YYYY-Www)")

        // Extract week number
        let components = cycleId.split(separator: "-")
        XCTAssertEqual(components.count, 2, "Cycle ID should have two components")
        XCTAssertTrue(components[1].starts(with: "W"), "Second component should start with W")
        #endif
    }

    // MARK: - Helper Methods

    private func makeMockPlan(scheduleOrder: [String]) -> PlanV03 {
        let days = scheduleOrder.map { label in
            PlanV03.Day(label: label, segments: [], dayNumber: nil)
        }

        return PlanV03(
            planName: "Test Plan",
            unit: .pounds,
            exerciseNames: [:],
            altGroups: [:],
            days: days,
            scheduleOrder: scheduleOrder,
            phase: nil,
            groupVariants: nil
        )
    }

    private func makeMockPlanWithPhase(weeks: [Int]) -> PlanV03 {
        let phase = Phase(index: 1, weeks: weeks)
        let day = PlanV03.Day(label: "Test Day", segments: [], dayNumber: nil)

        return PlanV03(
            planName: "Test Plan",
            unit: .pounds,
            exerciseNames: [:],
            altGroups: [:],
            days: [day],
            scheduleOrder: ["Test Day"],
            phase: phase,
            groupVariants: nil
        )
    }
}

#endif
