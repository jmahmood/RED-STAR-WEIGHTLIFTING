//
//  CommitWheel.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Codex on 2025-10-29.
//

import Foundation
import os.signpost

struct CommitWheelEntry {
    let deadline: Date
    let seq: Int
}

extension CommitWheelEntry: Sendable {}

final class CommitWheel {
    static let shared = CommitWheel()
    private let q = DispatchQueue(label: "commit.wheel", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var heap = MinHeap<CommitWheelEntry>(comparator: { $0.deadline < $1.deadline })
    private var handlers: [Int: () -> Void] = [:]

    func arm(seq: Int, deadline: Date, onFire: @escaping () -> Void) {
        q.async {
            self.handlers[seq] = onFire
            self.heap.insert(.init(deadline: deadline, seq: seq))
            self.rescheduleLocked()
        }
    }

    func cancel(seq: Int) {
        q.async {
            self.handlers[seq] = nil
            self.heap.removeAll { $0.seq == seq }
            self.rescheduleLocked()
        }
    }

    private func rescheduleLocked() {
        os_signpost(.event, log: .default, name: "commitwheel.reschedule")
        timer?.cancel()
        timer = nil
        guard let next = heap.peek() else { return }
        let t = DispatchSource.makeTimerSource(queue: q)
        let delta = max(0, next.deadline.timeIntervalSinceNow)
        t.schedule(deadline: .now() + delta)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            os_signpost(.event, log: .default, name: "commitwheel.fire")
            // pop all due
            let now = Date()
            while let head = self.heap.peek(), head.deadline <= now {
                _ = self.heap.popMin()
                if let h = self.handlers.removeValue(forKey: head.seq) { h() }
            }
            self.rescheduleLocked()
        }
        t.activate()
        timer = t
    }
}

// Simple min-heap implementation
struct MinHeap<Element> {
    private var elements: [Element] = []
    private let comparator: (Element, Element) -> Bool

    init(comparator: @escaping (Element, Element) -> Bool) {
        self.comparator = comparator
    }

    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }

    mutating func insert(_ element: Element) {
        elements.append(element)
        siftUp(from: elements.count - 1)
    }

    mutating func popMin() -> Element? {
        guard !isEmpty else { return nil }
        elements.swapAt(0, elements.count - 1)
        let min = elements.removeLast()
        if !isEmpty {
            siftDown(from: 0)
        }
        return min
    }

    func peek() -> Element? {
        elements.first
    }

    mutating func removeAll(where predicate: (Element) -> Bool) {
        elements.removeAll(where: predicate)
        // Rebuild heap after removals
        for i in stride(from: elements.count / 2 - 1, through: 0, by: -1) {
            siftDown(from: i)
        }
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2
        while child > 0 && comparator(elements[child], elements[parent]) {
            elements.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent

            if left < elements.count && comparator(elements[left], elements[candidate]) {
                candidate = left
            }
            if right < elements.count && comparator(elements[right], elements[candidate]) {
                candidate = right
            }
            if candidate == parent {
                return
            }
            elements.swapAt(parent, candidate)
            parent = candidate
        }
    }
}