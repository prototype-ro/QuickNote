//
//  QuickNoteLiveActivityIntent.swift
//  QuickNoteLiveActivityIntent
//
//  Created by Rodrigo Lage da Costa on 15/06/26.
//

import AppIntents

struct QuickNoteLiveActivityIntent: AppIntent {
    static var title: LocalizedStringResource { "QuickNoteLiveActivityIntent" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
