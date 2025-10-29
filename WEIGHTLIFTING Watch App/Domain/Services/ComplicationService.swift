//
//  ComplicationService.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import ClockKit
import Foundation

final class ComplicationService {
    func reloadComplications() {
        // TODO: S1-T24 trigger reload timeline.
        let server = CLKComplicationServer.sharedInstance()
        server.activeComplications?.forEach { server.reloadTimeline(for: $0) }
    }
}
