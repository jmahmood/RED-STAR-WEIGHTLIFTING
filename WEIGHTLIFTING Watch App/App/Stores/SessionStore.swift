//
//  SessionStore.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Combine
import Foundation

final class SessionStore: ObservableObject {
    @Published private(set) var session: SessionState = .idle

    private let sessionManager: SessionManaging
    private var cancellables = Set<AnyCancellable>()

    init(sessionManager: SessionManaging) {
        self.sessionManager = sessionManager
        bind()
    }

    func loadInitialSession() {
        sessionManager.loadInitialSession()
    }

    private func bind() {
        sessionManager.sessionPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$session)
    }
}
