//
//  PlanCapabilities.swift
//  Shared
//
//  Central definition of plan support policies.
//

import Foundation

public struct PlanCapabilities: Sendable {
    public let supportsStraight: Bool
    public let supportsScheme: Bool
    public let supportsSuperset: Bool
    public let supportsPercentage: Bool
    public let skipTimedSets: Bool

    public init(
        supportsStraight: Bool = true,
        supportsScheme: Bool = true,
        supportsSuperset: Bool = true,
        supportsPercentage: Bool = false,
        skipTimedSets: Bool = true
    ) {
        self.supportsStraight = supportsStraight
        self.supportsScheme = supportsScheme
        self.supportsSuperset = supportsSuperset
        self.supportsPercentage = supportsPercentage
        self.skipTimedSets = skipTimedSets
    }

    public static let v03MVP = PlanCapabilities(supportsPercentage: false, skipTimedSets: true)
    public static let v04Preview = PlanCapabilities(supportsPercentage: true, skipTimedSets: true)
}

