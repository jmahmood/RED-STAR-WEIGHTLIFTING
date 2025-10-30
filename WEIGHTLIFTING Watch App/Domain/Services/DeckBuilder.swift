//
//  DeckBuilder.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

protocol DeckBuilding {
    func buildDeck(for day: PlanV03.Day, plan: PlanV03) -> [DeckItem]
}

struct DeckBuilder: DeckBuilding {
    func buildDeck(for day: PlanV03.Day, plan: PlanV03) -> [DeckItem] {
        var deck: [DeckItem] = []
        var sequence: UInt64 = 1

        for (segmentIndex, segment) in day.segments.enumerated() {
            switch segment {
            case .straight(let straight):
                let sets = max(straight.sets, 1)
                let exerciseName = plan.exerciseNames[straight.exerciseCode] ?? straight.exerciseCode
                let repsText = straight.reps?.displayText ?? ""
                let badges = makeBadges(intensifier: straight.intensifier, restSec: straight.restSec)
                let canSkip = straight.timeSec != nil

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
                            restSeconds: straight.restSec
                        )
                    )
                    sequence += 1
                }

            case .scheme(let scheme):
                let exerciseName = plan.exerciseNames[scheme.exerciseCode] ?? scheme.exerciseCode
                var setIndex = 1
                for entry in scheme.entries {
                    let sets = max(entry.sets, 1)
                    let repsText = entry.reps?.displayText ?? scheme.entries.first?.reps?.displayText ?? ""
                    let badges = makeBadges(intensifier: entry.intensifier ?? scheme.intensifier, restSec: entry.restSec ?? scheme.restSec)
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
                                restSeconds: entry.restSec ?? scheme.restSec
                            )
                        )
                        sequence += 1
                        setIndex += 1
                    }
                }

            case .superset(let superset):
                let supersetID = superset.label ?? "SS\(segmentIndex + 1)"
                let restSec = superset.restSec ?? superset.restBetweenRoundsSec
                for round in 1...max(superset.rounds, 1) {
                    for (itemIndex, item) in superset.items.enumerated() {
                        let kind: DeckItem.Kind = itemIndex == 0 ? .supersetA : .supersetB
                        let exerciseName = plan.exerciseNames[item.exerciseCode] ?? item.exerciseCode
                        let repsText = item.reps?.displayText ?? ""
                        let badges = makeBadges(intensifier: item.intensifier, restSec: item.restSec ?? restSec)
                        for setIndex in 1...max(item.sets, 1) {
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
                                    restSeconds: item.restSec ?? restSec
                                )
                            )
                            sequence += 1
                        }
                    }
                }

            case .unsupported:
                continue
            }
        }

        return deck
    }

    private func makeBadges(intensifier: PlanV03.Intensifier?, restSec: Int?) -> [String] {
        var badges: [String] = []
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

        if let restSec, restSec == 0 {
            badges.append("0 REST")
        }

        return badges
    }
}
