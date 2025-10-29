//
//  ActivityView.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-30.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    var activities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: activities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
