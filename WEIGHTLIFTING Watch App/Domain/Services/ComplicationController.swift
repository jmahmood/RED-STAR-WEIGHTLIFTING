//
//  ComplicationController.swift
//  WEIGHTLIFTING Watch App
//
//  Created by Auto on 2025-10-28.
//

import ClockKit
import Foundation

final class ComplicationController: NSObject, CLKComplicationDataSource {
    private let userDefaults: UserDefaults

    override init() {
        self.userDefaults = .standard
        super.init()
    }

    private func getNextUpData() -> ComplicationSnapshot? {
        ComplicationSnapshot(userDefaults: userDefaults)
    }

    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }

    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        guard let data = getNextUpData() else {
            handler(nil)
            return
        }

        guard let template = template(for: complication.family, nextUp: data) else {
            handler(nil)
            return
        }

        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }

    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        handler(nil)
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        handler(nil)
    }

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptor = CLKComplicationDescriptor(
            identifier: "nextUp",
            displayName: "Next Up",
            supportedFamilies: [.modularLarge, .graphicRectangular]
        )
        handler([descriptor])
    }

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let sample = ComplicationSnapshot(
            exerciseName: "Bench Press",
            detail: "135lb × 8",
            footer: "••• +2",
            sessionID: "",
            deckIndex: 0
        )

        handler(template(for: complication.family, nextUp: sample))
    }

    private func template(for family: CLKComplicationFamily, nextUp data: ComplicationSnapshot) -> CLKComplicationTemplate? {
        let footerText = data.footer.isEmpty ? data.detail : "\(data.detail) \(data.footer)"

        switch family {
        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Next Up"),
                body1TextProvider: CLKSimpleTextProvider(text: data.exerciseName),
                body2TextProvider: CLKSimpleTextProvider(text: footerText)
            )
            return template
        case .graphicRectangular:
            let template = CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Next Up"),
                body1TextProvider: CLKSimpleTextProvider(text: data.exerciseName),
                body2TextProvider: CLKSimpleTextProvider(text: footerText)
            )
            return template
        default:
            return nil
        }
    }
}
