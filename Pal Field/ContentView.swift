//
//  ContentView.swift
//  Pal Field - Technical Blueprint Redesign
//
//  REDESIGNED: New Technical Blueprint design system applied
//

import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var settings: Settings

    // Brand colors matching splash screen
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]
    @Query private var allInvoices: [Invoice]
    @Query private var allExpenses: [Expense]
    @Query private var cachedEmails: [CachedEmail]
    @Query private var allMileageTrips: [MileageTrip]
    @Query private var chatUsers: [ChatUser]
    @ObservedObject private var gmailAuth = GmailAuthManager.shared

    // Filter data by current user's email
    // Records with empty ownerEmail are treated as belonging to current user (legacy data)
    private var currentUserEmail: String {
        gmailAuth.userEmail.lowercased()
    }

    private var jobs: [Job] {
        allJobs.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var invoices: [Invoice] {
        allInvoices.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var expenses: [Expense] {
        allExpenses.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var mileageTrips: [MileageTrip] {
        allMileageTrips.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }
    @State private var showingAccessDenied = false
    @State private var showingAddJob = false
    @State private var showingWeeklyInvoice = false
    @State private var showingSettings = false
    @ObservedObject private var tripManager = TripTrackingManager.shared
    @State private var showingTripTracking = false
    @State private var navigateToAllJobs = false
    @State private var showingProfileSetup = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    var weekStart: Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return calendar.startOfDay(for: calendar.date(from: components) ?? .now)
    }

    var weekEnd: Date {
        let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? .now
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
    }

    var yearStart: Date {
        let components = calendar.dateComponents([.year], from: .now)
        return calendar.startOfDay(for: calendar.date(from: components) ?? .now)
    }

    // Week stats
    var weekJobs: [Job] {
        jobs.filter { job in
            let jobDay = calendar.startOfDay(for: job.jobDate)
            return jobDay >= weekStart && jobDay <= calendar.startOfDay(for: weekEnd)
        }
    }

    var weekJobCount: Int { weekJobs.count }
    var weekTotalPay: Double { weekJobs.reduce(0) { $0 + $1.total(settings: settings) } }

    // Week mileage from tracked trips
    var weekMileageTrips: [MileageTrip] {
        mileageTrips.filter { trip in
            let tripDay = calendar.startOfDay(for: trip.startDate)
            return tripDay >= weekStart && tripDay <= calendar.startOfDay(for: weekEnd) && !trip.isActive
        }
    }
    var weekTotalMiles: Double { weekMileageTrips.reduce(0) { $0 + $1.miles } }

    // Year stats
    var yearJobs: [Job] { jobs.filter { $0.jobDate >= yearStart } }
    var yearJobCount: Int { yearJobs.count }
    var yearTotalPay: Double { yearJobs.reduce(0) { $0 + $1.total(settings: settings) } }
    var yearTotalMiles: Double { yearMileageTrips.reduce(0) { $0 + $1.miles } }

    var yearExpenses: [Expense] { expenses.filter { $0.date >= yearStart } }
    var yearMileageTrips: [MileageTrip] {
        mileageTrips.filter { $0.startDate >= yearStart && !$0.isActive }
    }

    // Tax calculations
    var jobMileage: Double { yearTotalMiles * 0.67 }
    var tripMileage: Double { yearMileageTrips.reduce(0) { $0 + $1.miles } * 0.67 }
    var expenseDeductions: Double { yearExpenses.reduce(0) { $0 + $1.amount } }
    var totalDeductions: Double { jobMileage + tripMileage + expenseDeductions }
    var netIncome: Double { max(0, yearTotalPay - totalDeductions) }
    var totalTaxEstimate: Double {
        let selfEmploymentTax = netIncome * 0.9235 * 0.153
        let adjustedIncome = max(0, netIncome - (selfEmploymentTax / 2))
        let taxableIncome = max(0, adjustedIncome - 14600)
        let federalTax = calculateFederalTax(taxableIncome)
        let stateTax = adjustedIncome * 0.0315
        return selfEmploymentTax + federalTax + stateTax
    }

    func calculateFederalTax(_ income: Double) -> Double {
        if income <= 11600 { return income * 0.10 }
        else if income <= 47150 { return 1160 + (income - 11600) * 0.12 }
        else if income <= 100525 { return 5426 + (income - 47150) * 0.22 }
        else if income <= 191950 { return 17168.50 + (income - 100525) * 0.24 }
        else if income <= 243725 { return 39110.50 + (income - 191950) * 0.32 }
        else if income <= 609350 { return 55678.50 + (income - 243725) * 0.35 }
        else { return 183647.25 + (income - 609350) * 0.37 }
    }

    /// Update widget cache with current data
    func updateWidgetCache() {
        // Calculate today's stats
        let todayStart = calendar.startOfDay(for: Date())
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        let todayJobs = jobs.filter { $0.jobDate >= todayStart && $0.jobDate < todayEnd }
        let todayTotalPay = todayJobs.reduce(0) { $0 + $1.total(settings: settings) }

        // Build individual job summaries for the widget
        let jobSummaries = todayJobs.map { job in
            CachedJobSummary(
                jobNumber: job.jobNumber,
                address: job.address,
                total: job.total(settings: settings)
            )
        }

        // Save to shared UserDefaults for widget
        WidgetDataCache.save(
            weekEarnings: weekTotalPay,
            weekJobCount: weekJobCount,
            todayEarnings: todayTotalPay,
            todayJobCount: todayJobs.count,
            todayJobs: jobSummaries
        )
    }

    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Trip Tracking Button
                    tripTrackingButton
                        .padding(.horizontal)

                    // AI Assistant Chat Bar
                    AssistantChatBar()
                        .padding(.horizontal)

                    // Quick Stats Grid
                    statsGridSection

                    // Tax Overview Card
                    taxOverviewCard

                    // Navigation Grid
                    navigationGrid

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .refreshable {
                // Pull to refresh - give CloudKit a moment to sync
                isRefreshing = true
                try? await Task.sleep(for: .seconds(1))
                updateWidgetCache()
                isRefreshing = false
            }
            .background(
                ZStack {
                    // Dark background
                    Color.black

                    // Logo watermark in background
                    WatermarkLogo()
                        .opacity(0.15)
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Pal Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingAddJob) {
                AddJobView()
            }
            .sheet(isPresented: $showingWeeklyInvoice) {
                WeeklyInvoiceView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingTripTracking) {
                TripTrackingView(tripManager: tripManager)
            }
            .sheet(isPresented: $showingProfileSetup) {
                ProfileSetupSheet()
                    .environmentObject(settings)
            }
            .navigationDestination(isPresented: $navigateToAllJobs) {
                AllJobsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToAllJobs)) { _ in
                navigateToAllJobs = true
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                switch newPhase {
                case .background:
                    // Force save when app backgrounds
                    if tripManager.isTracking {
                        Task {
                            try? modelContext.save()
                        }
                    }
                case .active:
                    print("App active - tracking: \(tripManager.isTracking)")
                default:
                    break
                }
            }
            .onAppear {
                // Initialize trip manager with model container
                let container = modelContext.container
                tripManager.setModelContainer(container)

                // Clean up any orphaned trips from previous sessions
                Task {
                    await tripManager.cleanupOrphanedTrips(from: container)
                }

                // Update widget cache
                updateWidgetCache()

                // Check access for restored sessions (external emails)
                if gmailAuth.pendingAccessCheck && gmailAuth.isSignedIn {
                    let authorizedEmails = chatUsers.map { $0.email }
                    if gmailAuth.isEmailAllowed(gmailAuth.userEmail, authorizedEmails: authorizedEmails) {
                        gmailAuth.confirmAccess()
                    } else {
                        gmailAuth.denyAccess()
                        showingAccessDenied = true
                    }
                }

                // Show profile setup sheet if user hasn't completed it yet
                if !UserDefaults.standard.bool(forKey: "hasCompletedProfileSetup") {
                    // Small delay to let the view appear first
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingProfileSetup = true
                    }
                }
            }
            .onChange(of: jobs.count) { _, _ in
                updateWidgetCache()
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onReceive(NotificationCenter.default.publisher(for: .jobDataDidChange)) { _ in
                updateWidgetCache()
                WidgetCenter.shared.reloadAllTimelines()
            }
            .alert("Access Denied", isPresented: $showingAccessDenied) {
                Button("OK") {
                    gmailAuth.clearAccessDenied()
                }
            } message: {
                Text("Your email is not authorized to use this app. Please contact an administrator to request access.")
            }
        }
    }

    // MARK: - View Components

    private var statsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            compactStatCard(
                title: "Week",
                value: String(format: "$%.0f", weekTotalPay),
                subtitle: "\(weekJobCount) jobs",
                icon: "calendar",
                color: .blue
            )

            compactStatCard(
                title: "Year",
                value: String(format: "$%.0f", yearTotalPay),
                subtitle: "\(yearJobCount) jobs",
                icon: "chart.line.uptrend.xyaxis",
                color: brandGreen
            )

            compactStatCard(
                title: "Week Miles",
                value: String(format: "%.0f", weekTotalMiles),
                subtitle: "miles",
                icon: "car.fill",
                color: .orange
            )

            compactStatCard(
                title: "Year Miles",
                value: String(format: "%.0f", yearTotalMiles),
                subtitle: "miles",
                icon: "map.fill",
                color: .purple
            )
        }
    }

    private var taxOverviewCard: some View {
        NavigationLink {
            TaxesView()
        } label: {
            VStack(spacing: 12) {
                HStack {
                    Text("Tax Summary YTD")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }

                HStack(spacing: 12) {
                    taxQuickStat("Gross", value: yearTotalPay, color: .blue)
                    taxQuickStat("Net", value: netIncome, color: brandGreen)
                    taxQuickStat("Tax Est", value: totalTaxEstimate, color: .red)
                }
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var navigationGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            gridNavButton(icon: "point.bottomleft.forward.to.point.topright.scurvepath", title: "Mileage", color: .blue, destination: MileageTripsView())
            gridNavButton(icon: "envelope.fill", title: "Messages", color: .blue, destination: MessagesView())
            gridNavButton(icon: "shippingbox.fill", title: "Inventory", color: .orange, destination: InventoryView())
            gridNavButton(icon: "cloud.sun.fill", title: "Weather", color: .cyan, destination: WeatherView())
            gridNavButton(icon: "doc.text.fill", title: "Invoices", color: brandGreen, destination: InvoicesView())
            gridNavButton(icon: "receipt.fill", title: "Expenses", color: .red, destination: ExpensesView())
            gridNavButton(icon: "list.bullet.rectangle", title: "All Jobs", color: .purple, destination: AllJobsView())
            gridNavButton(icon: "building.2.fill", title: "Builders", color: .indigo, destination: BuilderInfoView())

            // Admin tabs - only visible when admin mode is enabled
            if settings.adminModeEnabled && settings.userRole.canViewAllUsers {
                gridNavButton(icon: "person.3.fill", title: "All Jobs", color: .purple.opacity(0.8), destination: AdminJobsView())
                gridNavButton(icon: "doc.text.fill", title: "All Invoices", color: brandGreen.opacity(0.8), destination: AdminInvoicesView())
                gridNavButton(icon: "shippingbox.fill", title: "All Inventory", color: .orange.opacity(0.8), destination: AdminInventoryView())
            }
        }
    }

    @ViewBuilder
    private func compactStatCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func taxQuickStat(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
            Text(String(format: "$%.0f", value))
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func gridNavButton<Destination: View>(icon: String, title: String, color: Color, destination: Destination) -> some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(.white)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(color.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private var tripTrackingButton: some View {
        Button {
            // Always show tracking view - whether starting or viewing current trip
            showingTripTracking = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tripManager.isTracking ? "location.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tripManager.isTracking ? "Trip in Progress" : "Track Mileage")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if tripManager.isTracking {
                        Text("\(String(format: "%.1f", tripManager.totalMiles)) mi • Tap to view")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }

                Spacer()

                if tripManager.isTracking {
                    // Pulsing indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                .scaleEffect(1.5)
                        )
                }
            }
            .padding()
            .background(tripManager.isTracking ? Color.orange.gradient : brandGreen.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 16) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                        .foregroundStyle(.white)
                }

                ChatButton()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    showingWeeklyInvoice = true
                } label: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(.white)
                }

                Button {
                    showingAddJob = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(brandGreen)
                }
            }
        }
    }
}

// MARK: - Watermark Logo for Background

struct WatermarkLogo: View {
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        ZStack {
            // Arc 3 (outermost)
            WatermarkArc(startAngle: -145, endAngle: -35)
                .stroke(brandGreen, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 200, height: 200)
                .offset(y: -75)

            // Arc 2 (middle)
            WatermarkArc(startAngle: -145, endAngle: -35)
                .stroke(brandGreen, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: 140, height: 140)
                .offset(y: -45)

            // Arc 1 (innermost)
            WatermarkArc(startAngle: -145, endAngle: -35)
                .stroke(brandGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 80, height: 80)
                .offset(y: -15)

            // Center dot
            Ellipse()
                .fill(brandGreen)
                .frame(width: 30, height: 38)
                .offset(y: 30)

            // Bottom smile
            WatermarkArc(startAngle: 35, endAngle: 145)
                .stroke(brandGreen, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 80, height: 80)
                .offset(y: 75)
        }
        .frame(width: 250, height: 300)
    }
}

struct WatermarkArc: Shape {
    var startAngle: Double
    var endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )

        return path
    }
}
