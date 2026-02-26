//
//  PalFieldWidgetsBundle.swift
//  PalFieldWidgets
//
//  Created by Andrew Stewart on 2/2/26.
//

import WidgetKit
import SwiftUI

@main
struct PalFieldWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WeekEarningsWidget()
        DashboardWidget()
        TodayJobsWidget()
    }
}
