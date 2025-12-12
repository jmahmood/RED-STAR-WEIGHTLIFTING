//
//  PlanRepository.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Foundation

struct PlanRepository {
    enum Error: Swift.Error {
        case missingPlanFixture
    }

    private let fileSystem: FileSystem
    private let bundle: Bundle
    private let resourceName: String

    init(fileSystem: FileSystem, bundle: Bundle = .main, resourceName: String = "minimalist_4x_plan_block_1") {
        self.fileSystem = fileSystem
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func loadActivePlan() throws -> PlanV03 {
        // 1. Try PlanStore first (new location)
        if let plan = try? PlanStore.shared.loadActivePlan() {
            return plan
        }

        // 2. Fallback to old location (migration path)
        let planURL = try fileSystem.planURL(named: "active_plan.json")
        if fileSystem.fileExists(at: planURL) {
            let data = try Data(contentsOf: planURL)
            let plan = try decodePlan(from: data)

            // Migrate to PlanStore
            let planID = PlanStore.generatePlanID(from: plan.planName)
            try? PlanStore.shared.savePlan(plan, id: planID)
            try? PlanStore.shared.setActivePlan(id: planID)

            return plan
        }

        // 3. Fallback to bundled fixture
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw Error.missingPlanFixture
        }

        let data = try Data(contentsOf: url)
        return try decodePlan(from: data)
    }

    private func decodePlan(from data: Data) throws -> PlanV03 {
        let validation = try PlanValidator.validate(data: data)
        return validation.plan
    }
}
