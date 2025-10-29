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
        let planURL = try fileSystem.planURL(named: "active_plan.json")
        if fileSystem.fileExists(at: planURL) {
            let data = try Data(contentsOf: planURL)
            return try decodePlan(from: data)
        }

        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw Error.missingPlanFixture
        }

        let data = try Data(contentsOf: url)
        return try decodePlan(from: data)
    }

    private func decodePlan(from data: Data) throws -> PlanV03 {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PlanV03.self, from: data)
    }
}
