//
//  DeckStore.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import Combine
import Foundation

final class DeckStore: ObservableObject {
    @Published private(set) var deck: DeckState = .empty

    private let sessionManager: SessionManaging
    private let deckBuilder: DeckBuilding
    private var cancellables = Set<AnyCancellable>()

    init(sessionManager: SessionManaging, deckBuilder: DeckBuilding) {
        self.sessionManager = sessionManager
        self.deckBuilder = deckBuilder
        bind()
    }

    private func bind() {
        sessionManager.sessionPublisher
            .map { session in
                switch session {
                case .active(let context):
                    return .loaded(context.deck)
                case .idle, .error:
                    return .empty
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$deck)
    }
}
