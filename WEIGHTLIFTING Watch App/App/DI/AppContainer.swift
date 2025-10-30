//
//  AppContainer.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Combine
import Foundation

final class AppContainer: ObservableObject {
    let fileSystem: FileSystem
    let walLog: WalLog
    let globalCsv: GlobalCsv
    let indexService: IndexRepositorying
    let planRepository: PlanRepository
    let deckBuilder: DeckBuilder
    let sessionManager: SessionManager
    let exportService: ExportService
    let complicationService: ComplicationService
    let complicationController: ComplicationController

    let sessionStore: SessionStore
    let deckStore: DeckStore

    init(
        fileManager: FileManager = .default,
        userDefaults: UserDefaults = .standard
    ) {
        let fileSystem = FileSystem(fileManager: fileManager)
        self.fileSystem = fileSystem

        let seeder = ResourceSeeder(bundle: .main, fileSystem: fileSystem)
        seeder.seedPlanIfNeeded()
        seeder.seedGlobalCsvIfNeeded()

        self.walLog = WalLog(fileSystem: fileSystem)
        self.globalCsv = GlobalCsv(fileSystem: fileSystem)
        let indexDataStore = IndexRepository(fileSystem: fileSystem)
        self.indexService = IndexService(dataStore: indexDataStore, fileSystem: fileSystem)
        indexService.ensureValidAgainstCSV()
        self.planRepository = PlanRepository(fileSystem: fileSystem, bundle: .main)
        self.deckBuilder = DeckBuilder()

        let walReplay = WalReplay(fileSystem: fileSystem, globalCsv: globalCsv, indexRepository: indexService)
        walReplay.replayPendingSessions()

        self.complicationService = ComplicationService()
        self.complicationController = ComplicationController()

        self.sessionManager = SessionManager(
            fileSystem: fileSystem,
            planRepository: planRepository,
            deckBuilder: deckBuilder,
            walLog: walLog,
            globalCsv: globalCsv,
            indexRepository: indexService,
            complicationService: complicationService
        )
        self.exportService = ExportService(fileSystem: fileSystem, globalCsv: globalCsv)
//        self.complicationService = ComplicationService()

        let sessionStore = SessionStore(sessionManager: sessionManager)
        self.sessionStore = sessionStore
        self.deckStore = DeckStore(sessionManager: sessionManager, deckBuilder: deckBuilder)
    }
}
