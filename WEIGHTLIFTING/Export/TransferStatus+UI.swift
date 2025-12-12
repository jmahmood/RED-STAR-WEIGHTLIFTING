//
//  TransferStatus+UI.swift
//  WEIGHTLIFTING
//
//  Shared UI-facing helpers for TransferStatus.
//

import SwiftUI

extension TransferStatus.Phase {
    var displayText: String {
        switch self {
        case .idle: return "Idle"
        case .preparing: return "Preparing"
        case .queued: return "Queued"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    var isBusy: Bool {
        switch self {
        case .preparing, .queued, .inProgress:
            return true
        default:
            return false
        }
    }

    var tint: Color {
        switch self {
        case .idle: return .gray
        case .preparing, .queued: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

