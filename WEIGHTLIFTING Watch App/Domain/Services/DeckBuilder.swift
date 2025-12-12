//
//  DeckBuilder.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//  V0.4: Updated to use SegmentResolver for per_week and group_variants support
//

import Foundation

protocol DeckBuilding {
    func buildDeck(for day: PlanV03.Day, plan: PlanV03, currentWeek: Int) -> [DeckItem]
}

struct DeckBuilder: DeckBuilding {
    let resolver: SegmentResolving

    init(resolver: SegmentResolving = SegmentResolver()) {
        self.resolver = resolver
    }

    func buildDeck(for day: PlanV03.Day, plan: PlanV03, currentWeek: Int) -> [DeckItem] {
        var deck: [DeckItem] = []
        var sequence: UInt64 = 1

        for (segmentIndex, segment) in day.segments.enumerated() {
            switch segment {
            case .straight(let straight):
                // V0.4: Resolve segment with per_week and group_variants
                let resolved = resolver.resolveStraight(
                    segment: straight,
                    currentWeek: currentWeek,
                    selectedExercise: nil,
                    plan: plan
                )
                let sets = max(resolved.sets, 1)
                let exerciseName = plan.exerciseNames[straight.exerciseCode] ?? straight.exerciseCode
                let repsText = resolved.reps?.displayText ?? ""
                let badges = makeBadges(intensifier: resolved.intensifier, restSec: resolved.restSec, tags: resolved.tags)
                let canSkip = resolved.timeSec != nil

                for setIndex in 1...sets {
                    deck.append(
                        DeckItem(
                            id: UUID(),
                            kind: .straight,
                            supersetID: nil,
                            segmentID: segmentIndex + 1,
                            sequence: sequence,
                            setIndex: setIndex,
                            round: nil,
                            exerciseCode: straight.exerciseCode,
                            exerciseName: exerciseName,
                            altGroup: straight.altGroup,
                            targetReps: repsText,
                            unit: plan.unit,
                            isWarmup: false,
                            badges: badges,
                            canSkip: canSkip,
                            restSeconds: resolved.restSec,
                            weightPrescription: .flat,
                            loadAxisTarget: resolved.loadAxisTarget,
                            selectedAxisValue: nil
                        )
                    )
                    sequence += 1
                }

            case .scheme(let scheme):
                let exerciseName = plan.exerciseNames[scheme.exerciseCode] ?? scheme.exerciseCode
                var setIndex = 1
                for entry in scheme.entries {
                    // V0.4: Resolve each scheme entry with per_week and group_variants
                    let resolved = resolver.resolveScheme(
                        segment: scheme,
                        entry: entry,
                        currentWeek: currentWeek,
                        selectedExercise: nil,
                        plan: plan
                    )
                    let sets = max(resolved.sets, 1)
                    let repsText = resolved.reps?.displayText ?? ""
                    let badges = makeBadges(intensifier: resolved.intensifier, restSec: resolved.restSec, tags: resolved.tags)
                    for _ in 0..<sets {
                        deck.append(
                            DeckItem(
                                id: UUID(),
                                kind: .scheme,
                                supersetID: nil,
                                segmentID: segmentIndex + 1,
                                sequence: sequence,
                                setIndex: setIndex,
                                round: nil,
                                exerciseCode: scheme.exerciseCode,
                                exerciseName: exerciseName,
                                altGroup: scheme.altGroup,
                                targetReps: repsText,
                                unit: plan.unit,
                                isWarmup: false,
                                badges: badges,
                                canSkip: false,
                                restSeconds: resolved.restSec,
                                weightPrescription: .flat,
                                loadAxisTarget: resolved.loadAxisTarget,
                                selectedAxisValue: nil
                            )
                        )
                        sequence += 1
                        setIndex += 1
                    }
                }

            case .superset(let superset):
                let supersetID = superset.label ?? "SS\(segmentIndex + 1)"
                for round in 1...max(superset.rounds, 1) {
                    for (itemIndex, item) in superset.items.enumerated() {
                        // V0.4: Resolve each superset item with per_week and group_variants
                        let resolved = resolver.resolveSupersetItem(
                            item: item,
                            currentWeek: currentWeek,
                            selectedExercise: nil,
                            plan: plan
                        )
                        let kind: DeckItem.Kind = itemIndex == 0 ? .supersetA : .supersetB
                        let exerciseName = plan.exerciseNames[item.exerciseCode] ?? item.exerciseCode
                        let repsText = resolved.reps?.displayText ?? ""
                        let badges = makeBadges(intensifier: resolved.intensifier, restSec: resolved.restSec, tags: resolved.tags)
                        for setIndex in 1...max(resolved.sets, 1) {
                            deck.append(
                                DeckItem(
                                    id: UUID(),
                                    kind: kind,
                                    supersetID: supersetID,
                                    segmentID: segmentIndex + 1,
                                    sequence: sequence,
                                    setIndex: setIndex,
                                    round: round,
                                    exerciseCode: item.exerciseCode,
                                    exerciseName: exerciseName,
                                    altGroup: item.altGroup,
                                    targetReps: repsText,
                                    unit: plan.unit,
                                    isWarmup: false,
                                    badges: badges,
                                    canSkip: false,
                                    restSeconds: resolved.restSec,
                                    weightPrescription: .flat,
                                    loadAxisTarget: resolved.loadAxisTarget,
                                    selectedAxisValue: nil
                                )
                            )
                            sequence += 1
                        }
                    }
                }

            case .percentage(let percentage):
                // V0.4: Percentage segments for 5-3-1 style programs
                let prescriptions = resolver.resolvePercentage(
                    segment: percentage,
                    currentWeek: currentWeek
                )
                let exerciseName = plan.exerciseNames[percentage.exerciseCode] ?? percentage.exerciseCode

                for prescription in prescriptions {
                    let sets = max(prescription.sets, 1)
                    let repsText = prescription.reps.displayText
                    let badges = makeBadges(intensifier: prescription.intensifier, restSec: nil, tags: [])

                    for setIndex in 1...sets {
                        deck.append(
                            DeckItem(
                                id: UUID(),
                                kind: .straight,  // Use .straight kind for percentage-based sets
                                supersetID: nil,
                                segmentID: segmentIndex + 1,
                                sequence: sequence,
                                setIndex: setIndex,
                                round: nil,
                                exerciseCode: percentage.exerciseCode,
                                exerciseName: exerciseName,
                                altGroup: nil,
                                targetReps: repsText,
                                unit: plan.unit,
                                isWarmup: false,
                                badges: badges,
                                canSkip: false,
                                restSeconds: nil,
                                weightPrescription: .flat,  // TODO: Implement percentage-based weight prescription
                                loadAxisTarget: nil,
                                selectedAxisValue: nil
                            )
                        )
                        sequence += 1
                    }
                }

            case .unsupported:
                continue
            }
        }

        return deck
    }

    private func makeBadges(intensifier: PlanV03.Intensifier?, restSec: Int?, tags: [String]) -> [String] {
        var badges: [String] = []

        // Add intensifier badges
        if let intensifier {
            switch intensifier.kind {
            case .dropset:
                badges.append("DROP")
            case .amrap:
                badges.append("AMRAP")
            case .unknown:
                break
            }
        }

        // Add rest badge
        if let restSec, restSec == 0 {
            badges.append("0 REST")
        }

        // Add resolved tags from segment
        badges.append(contentsOf: tags)

        return badges
    }
}
