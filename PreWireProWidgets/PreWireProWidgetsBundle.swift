//
//  PreWireProWidgetsBundle.swift
//  PreWireProWidgets
//
//  Created by Andrew Stewart on 2/2/26.
//

import WidgetKit
import SwiftUI

@main
struct PreWireProWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WeekEarningsWidget()
        DashboardWidget()
        TodayJobsWidget()
    }
}
