//
//  ContentView_Redesigned.swift
//  PreWire Pro - Technical Blueprint Redesign
//
//  INSTRUCTIONS: Replace your current ContentView.swift with this code
//  to apply the new Technical Blueprint design system
//

import SwiftUI
import SwiftData

struct ContentView_Redesigned: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @Query(sort: \Job.jobDate, order: .reverse) private var jobs: [Job]
    @Query private var invoices: [Invoice]
    @Query private var expenses: [Expense]
    @Query private var cachedEmails: [CachedEmail]
    @Query private var mileageTrips: [MileageTrip]
    @State private var showingAddJob = false
    @State private var showingWeeklyInvoice = false
    @State private var showingSettings = false
    @State private var showingPDFImport = false

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
    var weekTotalMiles: Double { weekJobs.reduce(0) { $0 + $1.miles } }

    // Year stats
    var yearJobs: [Job] { jobs.filter { $0.jobDate >= yearStart } }
    var yearJobCount: Int { yearJobs.count }
    var yearTotalPay: Double { yearJobs.reduce(0) { $0 + $1.total(settings: settings) } }
    var yearTotalMiles: Double { yearJobs.reduce(0) { $0 + $1.miles } }

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

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundView

                ScrollView {
                    VStack(spacing: 20) {
                        performanceSection
                        taxSummarySection
                        quickAccessSection

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("PreWire Pro")
            .navigationBarTitleDisplayMode(.large)
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
            .sheet(isPresented: $showingPDFImport) {
                PDFImportView()
            }
        }
    }

    // MARK: - View Components

    private var backgroundView: some View {
        ZStack {
            Color.paperWhite.ignoresSafeArea()
            BlueprintGridBackground()
                .opacity(0.5)
                .ignoresSafeArea()
        }
    }

    private var performanceSection: some View {
        VStack(spacing: 12) {
            TechnicalSectionHeader("PERFORMANCE", count: nil)

            HStack(spacing: 12) {
                TechnicalStatCard(
                    title: "WEEK",
                    value: String(format: "$%.0f", weekTotalPay),
                    unit: "USD",
                    subtitle: "\(weekJobCount) jobs · \(String(format: "%.0f", weekTotalMiles)) mi",
                    accentColor: .blueprintBlue,
                    icon: "calendar.badge.clock"
                )

                TechnicalStatCard(
                    title: "YEAR",
                    value: String(format: "$%.0f", yearTotalPay),
                    unit: "USD",
                    subtitle: "\(yearJobCount) jobs · \(String(format: "%.0f", yearTotalMiles)) mi",
                    accentColor: .successGreen,
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .padding(.horizontal)
        }
    }

    private var taxSummarySection: some View {
        VStack(spacing: 12) {
            TechnicalSectionHeader("TAX SUMMARY YTD")

            NavigationLink {
                TaxesView()
            } label: {
                taxSummaryCard
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }

    private var taxSummaryCard: some View {
        VStack(spacing: 0) {
            // Metric Grid
            HStack(spacing: 0) {
                taxMetric("GROSS", value: yearTotalPay, color: .blueprintBlue)
                Divider().frame(height: 60)
                taxMetric("DEDUCT", value: totalDeductions, color: .constructionOrange)
            }

            Divider()

            HStack(spacing: 0) {
                taxMetric("NET", value: netIncome, color: .successGreen)
                Divider().frame(height: 60)
                taxMetric("TAX EST", value: totalTaxEstimate, color: .steelGray)
            }

            // Action footer
            HStack {
                Text("DETAILED BREAKDOWN")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.blueprintBlue)
                    .tracking(1)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.blueprintBlue)
            }
            .padding(12)
            .background(Color.blueprintBlue.opacity(0.05))
        }
        .background(Color.paperWhite)
        .overlay(TechnicalCorners().padding(6))
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var quickAccessSection: some View {
        VStack(spacing: 12) {
            TechnicalSectionHeader("QUICK ACCESS")

            VStack(spacing: 12) {
                navCard(icon: "point.bottomleft.forward.to.point.topright.scurvepath", title: "Mileage Tracking", description: "Business miles for tax deductions", accentColor: .blueprintBlue, destination: MileageTripsView())

                navCard(icon: "envelope.fill", title: "Messages", description: "Gmail integration & images", accentColor: .blueprintBlue, destination: MessagesView())

                navCard(icon: "shippingbox.fill", title: "Inventory", description: "Supplies, tools & materials", accentColor: .constructionOrange, destination: InventoryView())

                navCard(icon: "cloud.sun.fill", title: "Weather", description: "Forecast & alerts", accentColor: .blueprintBlue, destination: WeatherView())

                navCard(icon: "doc.text.fill", title: "Invoices", description: "Weekly billing & statements", accentColor: .successGreen, destination: InvoicesView())

                navCard(icon: "receipt.fill", title: "Expenses", description: "Track business expenses", accentColor: .constructionOrange, destination: ExpensesView())

                navCard(icon: "list.bullet.rectangle", title: "All Jobs", description: "Complete job history", accentColor: .steelGray, destination: AllJobsView())
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func navCard<Destination: View>(icon: String, title: String, description: String, accentColor: Color, destination: Destination) -> some View {
        NavigationLink {
            destination
        } label: {
            TechnicalNavCard(
                icon: icon,
                title: title,
                description: description,
                accentColor: accentColor
            )
        }
        .buttonStyle(.plain)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingPDFImport = true
            } label: {
                Image(systemName: "doc.badge.plus")
                    .foregroundStyle(Color.blueprintBlue)
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    showingWeeklyInvoice = true
                } label: {
                    Image(systemName: "doc.text")
                        .foregroundStyle(Color.blueprintBlue)
                }

                Button {
                    showingAddJob = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.blueprintBlue)
                }

                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.steelGray)
                }
            }
        }
    }

    // MARK: - Tax Metric Component

    @ViewBuilder
    private func taxMetric(_ label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            Text("$\(value, specifier: "%.0f")")
                .font(.technicalMono)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
