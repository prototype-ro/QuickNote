//
//  QuickNoteLiveActivityBundle.swift
//  QuickNoteLiveActivity
//
//  Created by Rodrigo Lage da Costa on 15/06/26.
//

import WidgetKit
import SwiftUI

@main
struct QuickNoteLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        QuickNoteLiveActivity()
        QuickNoteLiveActivityControl()
        QuickNoteLiveActivityLiveActivity()
    }
}
