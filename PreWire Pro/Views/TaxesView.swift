//
//  TaxesView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct TaxesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]
    @Query private var allExpenses: [Expense]
    @Query private var allMileageTrips: [MileageTrip]
    @EnvironmentObject var settings: Settings
    @State private var showingSettings = false
    @State private var showingCSVExport = false
    @State private var showingTaxPackageExport = false
    @State private var csvURL: URL?
    @State private var taxPackageURL: URL?

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var jobs: [Job] {
        allJobs.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var expenses: [Expense] {
        allExpenses.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var mileageTrips: [MileageTrip] {
        allMileageTrips.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    var yearStart: Date {
        let components = calendar.dateComponents([.year], from: .now)
        return calendar.startOfDay(for: calendar.date(from: components) ?? .now)
    }

    // Year-to-date data
    var yearJobs: [Job] {
        jobs.filter { $0.jobDate >= yearStart }
    }

    var yearExpenses: [Expense] {
        expenses.filter { $0.date >= yearStart }
    }

    var yearMileageTrips: [MileageTrip] {
        mileageTrips.filter { $0.startDate >= yearStart && !$0.isActive }
    }

    // Income
    var grossIncome: Double {
        yearJobs.reduce(0) { $0 + $1.total(settings: settings) }
    }

    // Deductions
    var jobMiles: Double {
        yearJobs.reduce(0) { $0 + $1.miles }
    }

    var tripMiles: Double {
        yearMileageTrips.reduce(0) { $0 + $1.miles }
    }

    var totalMiles: Double {
        jobMiles + tripMiles
    }

    var mileageDeduction: Double {
        totalMiles * 0.67 // 2025 IRS rate
    }

    var expenseDeductions: Double {
        yearExpenses.reduce(0) { $0 + $1.amount }
    }

    var totalDeductions: Double {
        mileageDeduction + expenseDeductions
    }

    var netIncome: Double {
        max(0, grossIncome - totalDeductions)
    }

    // Tax calculations
    var selfEmploymentTax: Double {
        netIncome * 0.9235 * 0.153 // 92.35% of net income × 15.3%
    }

    var adjustedGrossIncome: Double {
        max(0, netIncome - (selfEmploymentTax / 2)) // Deduct half of SE tax
    }

    var standardDeduction: Double {
        switch settings.taxFilingStatus {
        case .single, .marriedFilingSeparately:
            return 14600
        case .marriedFilingJointly:
            return 29200
        case .headOfHousehold:
            return 21900
        }
    }

    var taxableIncome: Double {
        max(0, adjustedGrossIncome - standardDeduction)
    }

    var federalIncomeTax: Double {
        var tax = 0.0

        // 2025 tax brackets based on filing status
        switch settings.taxFilingStatus {
        case .single, .marriedFilingSeparately:
            if taxableIncome <= 11600 {
                tax = taxableIncome * 0.10
            } else if taxableIncome <= 47150 {
                tax = 1160 + (taxableIncome - 11600) * 0.12
            } else if taxableIncome <= 100525 {
                tax = 5426 + (taxableIncome - 47150) * 0.22
            } else if taxableIncome <= 191950 {
                tax = 17168.50 + (taxableIncome - 100525) * 0.24
            } else if taxableIncome <= 243725 {
                tax = 39110.50 + (taxableIncome - 191950) * 0.32
            } else if taxableIncome <= 609350 {
                tax = 55678.50 + (taxableIncome - 243725) * 0.35
            } else {
                tax = 183647.25 + (taxableIncome - 609350) * 0.37
            }

        case .marriedFilingJointly:
            if taxableIncome <= 23200 {
                tax = taxableIncome * 0.10
            } else if taxableIncome <= 94300 {
                tax = 2320 + (taxableIncome - 23200) * 0.12
            } else if taxableIncome <= 201050 {
                tax = 10852 + (taxableIncome - 94300) * 0.22
            } else if taxableIncome <= 383900 {
                tax = 34337 + (taxableIncome - 201050) * 0.24
            } else if taxableIncome <= 487450 {
                tax = 78221 + (taxableIncome - 383900) * 0.32
            } else if taxableIncome <= 731200 {
                tax = 111357 + (taxableIncome - 487450) * 0.35
            } else {
                tax = 196669.50 + (taxableIncome - 731200) * 0.37
            }

        case .headOfHousehold:
            if taxableIncome <= 16550 {
                tax = taxableIncome * 0.10
            } else if taxableIncome <= 63100 {
                tax = 1655 + (taxableIncome - 16550) * 0.12
            } else if taxableIncome <= 100500 {
                tax = 7241 + (taxableIncome - 63100) * 0.22
            } else if taxableIncome <= 191950 {
                tax = 15469 + (taxableIncome - 100500) * 0.24
            } else if taxableIncome <= 243700 {
                tax = 37417 + (taxableIncome - 191950) * 0.32
            } else if taxableIncome <= 609350 {
                tax = 53977 + (taxableIncome - 243700) * 0.35
            } else {
                tax = 181954.50 + (taxableIncome - 609350) * 0.37
            }
        }

        return tax
    }

    var stateTax: Double {
        adjustedGrossIncome * settings.taxState.taxRate
    }

    var totalTaxLiability: Double {
        selfEmploymentTax + federalIncomeTax + stateTax
    }

    var quarterlyPayment: Double {
        totalTaxLiability / 4
    }

    var effectiveTaxRate: Double {
        grossIncome > 0 ? (totalTaxLiability / grossIncome) * 100 : 0
    }

    var taxSavingsFromDeductions: Double {
        let taxWithoutDeductions = grossIncome * (effectiveTaxRate / 100)
        return max(0, taxWithoutDeductions - totalTaxLiability)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Income Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Income Summary")
                            .font(.headline)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gross Income")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("$\(grossIncome, specifier: "%.2f")")
                                    .font(.title2.bold())
                                    .foregroundStyle(.green)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(yearJobs.count) jobs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Deductions Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Deductions")
                            .font(.headline)

                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mileage (\(totalMiles, specifier: "%.0f") mi)")
                                        .font(.subheadline)
                                    Text("Job: \(jobMiles, specifier: "%.0f") mi + Trips: \(tripMiles, specifier: "%.0f") mi")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("$\(mileageDeduction, specifier: "%.2f")")
                                    .font(.subheadline.bold())
                            }

                            Divider()

                            HStack {
                                Image(systemName: "receipt.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Business Expenses")
                                        .font(.subheadline)
                                    Text("\(yearExpenses.count) receipts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("$\(expenseDeductions, specifier: "%.2f")")
                                    .font(.subheadline.bold())
                            }

                            Divider()

                            HStack {
                                Text("Total Deductions")
                                    .font(.headline)
                                Spacer()
                                Text("$\(totalDeductions, specifier: "%.2f")")
                                    .font(.title3.bold())
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Tax Calculation
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tax Calculation")
                            .font(.headline)

                        VStack(spacing: 8) {
                            taxRow("Net Income", amount: netIncome, color: .primary)
                            taxRow("Self-Employment Tax (15.3%)", amount: selfEmploymentTax, color: .red)
                            taxRow("Federal Income Tax", amount: federalIncomeTax, color: .red)
                            taxRow("\(settings.taxState.rawValue) State Tax (\(String(format: "%.2f", settings.taxState.taxRate * 100))%)", amount: stateTax, color: .red)

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Tax Liability")
                                        .font(.headline)
                                    Text("Effective Rate: \(effectiveTaxRate, specifier: "%.1f")%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("$\(totalTaxLiability, specifier: "%.2f")")
                                    .font(.title2.bold())
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Tax Savings
                    if taxSavingsFromDeductions > 0 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tax Savings from Deductions")
                                    .font(.subheadline.bold())
                                Text("You saved $\(taxSavingsFromDeductions, specifier: "%.2f") by tracking expenses!")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Quarterly Payments
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quarterly Tax Payments")
                            .font(.headline)

                        VStack(spacing: 12) {
                            quarterCard(quarter: "Q1", deadline: "April 15", amount: quarterlyPayment)
                            quarterCard(quarter: "Q2", deadline: "June 15", amount: quarterlyPayment)
                            quarterCard(quarter: "Q3", deadline: "September 15", amount: quarterlyPayment)
                            quarterCard(quarter: "Q4", deadline: "January 15", amount: quarterlyPayment)
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Key Insights
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Insights")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            insightRow(icon: "chart.line.uptrend.xyaxis", text: "Keep tracking! Every mile and receipt reduces your taxes")
                            insightRow(icon: "calendar", text: "Make quarterly payments to avoid penalties")
                            insightRow(icon: "doc.text", text: "Save all receipts for 3 years (IRS requirement)")
                            insightRow(icon: "building.columns", text: "Consider working with a tax professional for optimization")
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Export & Reports
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Export & Reports")
                            .font(.headline)

                        VStack(spacing: 12) {
                            Button {
                                exportToCSV()
                            } label: {
                                HStack {
                                    Image(systemName: "tablecells")
                                        .foregroundStyle(.green)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Export to CSV for Accountant")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("Detailed breakdown of income & deductions")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }

                            Button {
                                exportYearEndPackage()
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(.orange)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Year-End Tax Package")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("Complete tax summary with all supporting data")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }

                            Button {
                                printTaxReport()
                            } label: {
                                HStack {
                                    Image(systemName: "printer.fill")
                                        .foregroundStyle(.blue)
                                        .frame(width: 24)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Print-Friendly Report")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text("Print or save as PDF")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Tax Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                TaxSettingsView()
                    .environmentObject(settings)
            }
            .sheet(isPresented: $showingCSVExport) {
                if let url = csvURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingTaxPackageExport) {
                if let url = taxPackageURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    @ViewBuilder
    private func taxRow(_ label: String, amount: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("$\(amount, specifier: "%.2f")")
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func quarterCard(quarter: String, deadline: String, amount: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(quarter)
                    .font(.headline)
                Text("Due: \(deadline)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("$\(amount, specifier: "%.2f")")
                .font(.title3.bold())
                .foregroundStyle(.purple)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func insightRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Export Functions

    private func exportToCSV() {
        var csv = "Tax Summary Export - \(String(settings.taxYear))\n\n"

        // Income Section
        csv += "INCOME\n"
        csv += "Category,Amount\n"
        csv += "Gross Income,\(grossIncome)\n"
        csv += "Total Jobs,\(yearJobs.count)\n\n"

        // Deductions Section
        csv += "DEDUCTIONS\n"
        csv += "Category,Amount,Details\n"
        csv += "Job Mileage,\(String(format: "%.2f", mileageDeduction)),\(String(format: "%.0f", totalMiles)) miles @ $0.67/mile\n"
        csv += "  - Job Miles,\(String(format: "%.2f", jobMiles * 0.67)),\(String(format: "%.0f", jobMiles)) miles\n"
        csv += "  - Trip Miles,\(String(format: "%.2f", tripMiles * 0.67)),\(String(format: "%.0f", tripMiles)) miles\n"
        csv += "Business Expenses,\(expenseDeductions),\(yearExpenses.count) receipts\n"
        csv += "Total Deductions,\(totalDeductions)\n\n"

        // Tax Calculations
        csv += "TAX CALCULATIONS\n"
        csv += "Category,Amount\n"
        csv += "Net Income,\(netIncome)\n"
        csv += "Self-Employment Tax,\(selfEmploymentTax)\n"
        csv += "Federal Income Tax,\(federalIncomeTax)\n"
        csv += "\(settings.taxState.rawValue) State Tax,\(stateTax)\n"
        csv += "Total Tax Liability,\(totalTaxLiability)\n"
        csv += "Quarterly Payment,\(quarterlyPayment)\n\n"

        // Detailed Jobs
        csv += "DETAILED JOB BREAKDOWN\n"
        csv += "Date,Job Number,Total Pay,Miles\n"
        for job in yearJobs {
            let dateStr = job.jobDate.formatted(date: .numeric, time: .omitted)
            csv += "\(dateStr),\(job.jobNumber),\(job.total(settings: settings)),\(job.miles)\n"
        }
        csv += "\n"

        // Detailed Expenses
        csv += "DETAILED EXPENSE BREAKDOWN\n"
        csv += "Date,Merchant,Amount,Category,Notes\n"
        for expense in yearExpenses {
            let dateStr = expense.date.formatted(date: .numeric, time: .omitted)
            let notes = expense.notes.isEmpty ? "-" : expense.notes.replacingOccurrences(of: ",", with: ";")
            csv += "\(dateStr),\(expense.merchant),\(expense.amount),\(expense.category),\(notes)\n"
        }
        csv += "\n"

        // Detailed Mileage Trips
        csv += "DETAILED MILEAGE TRIPS\n"
        csv += "Date,Miles,Purpose,Notes\n"
        for trip in yearMileageTrips {
            let dateStr = trip.startDate.formatted(date: .numeric, time: .omitted)
            let notes = trip.notes.isEmpty ? "-" : trip.notes.replacingOccurrences(of: ",", with: ";")
            csv += "\(dateStr),\(trip.miles),\(trip.purpose),\(notes)\n"
        }

        // Save to file
        let fileName = "TaxSummary_\(String(settings.taxYear)).csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try csv.write(to: path, atomically: true, encoding: .utf8)
            csvURL = path
            showingCSVExport = true
        } catch {
            print("Error saving CSV: \(error)")
        }
    }

    private func exportYearEndPackage() {
        var report = "YEAR-END TAX PACKAGE - \(String(settings.taxYear))\n"
        report += "Generated: \(Date().formatted(date: .long, time: .shortened))\n"
        report += "Prepared for: \(settings.workerName)\n"
        report += "Filing Status: \(settings.taxFilingStatus.rawValue)\n"
        report += "State: \(settings.taxState.rawValue)\n"
        report += String(repeating: "=", count: 60) + "\n\n"

        // Executive Summary
        report += "EXECUTIVE SUMMARY\n"
        report += String(repeating: "-", count: 60) + "\n"
        report += String(format: "Gross Income:               $%,.2f\n", grossIncome)
        report += String(format: "Total Deductions:           $%,.2f\n", totalDeductions)
        report += String(format: "Net Income:                 $%,.2f\n", netIncome)
        report += String(format: "Total Tax Liability:        $%,.2f\n", totalTaxLiability)
        report += String(format: "Effective Tax Rate:         %.1f%%\n", effectiveTaxRate)
        report += String(format: "Tax Savings from Tracking:  $%,.2f\n\n", taxSavingsFromDeductions)

        // Income Details
        report += "INCOME DETAILS\n"
        report += String(repeating: "-", count: 60) + "\n"
        report += String(format: "Total Jobs Completed:       %d\n", yearJobs.count)
        report += String(format: "Gross Income:               $%,.2f\n\n", grossIncome)

        // Deductions Breakdown
        report += "DEDUCTIONS BREAKDOWN\n"
        report += String(repeating: "-", count: 60) + "\n"
        report += "Mileage Deduction:\n"
        report += String(format: "  Job Miles:                %.0f miles x $0.67 = $%,.2f\n", jobMiles, jobMiles * 0.67)
        report += String(format: "  Trip Miles:               %.0f miles x $0.67 = $%,.2f\n", tripMiles, tripMiles * 0.67)
        report += String(format: "  Total Mileage:            %.0f miles = $%,.2f\n\n", totalMiles, mileageDeduction)
        report += String(format: "Business Expenses:          %d receipts = $%,.2f\n\n", yearExpenses.count, expenseDeductions)
        report += String(format: "TOTAL DEDUCTIONS:           $%,.2f\n\n", totalDeductions)

        // Tax Calculations
        report += "TAX CALCULATIONS\n"
        report += String(repeating: "-", count: 60) + "\n"
        report += String(format: "Net Income:                 $%,.2f\n", netIncome)
        report += String(format: "Self-Employment Tax:        $%,.2f (15.3%%)\n", selfEmploymentTax)
        report += String(format: "Adjusted Gross Income:      $%,.2f\n", adjustedGrossIncome)
        report += String(format: "Standard Deduction:         $%,.2f (%@)\n", standardDeduction, settings.taxFilingStatus.rawValue)
        report += String(format: "Taxable Income:             $%,.2f\n", taxableIncome)
        report += String(format: "Federal Income Tax:         $%,.2f\n", federalIncomeTax)
        report += String(format: "%@ State Tax:     $%,.2f (%.2f%%)\n\n", settings.taxState.rawValue, stateTax, settings.taxState.taxRate * 100)
        report += String(format: "TOTAL TAX LIABILITY:        $%,.2f\n\n", totalTaxLiability)

        // Quarterly Payments
        report += "QUARTERLY ESTIMATED PAYMENTS\n"
        report += String(repeating: "-", count: 60) + "\n"
        report += String(format: "Q1 (Due April 15):          $%,.2f\n", quarterlyPayment)
        report += String(format: "Q2 (Due June 15):           $%,.2f\n", quarterlyPayment)
        report += String(format: "Q3 (Due September 15):      $%,.2f\n", quarterlyPayment)
        report += String(format: "Q4 (Due January 15):        $%,.2f\n\n", quarterlyPayment)

        // Important Notes
        report += "IMPORTANT NOTES FOR YOUR ACCOUNTANT\n"
        report += String(repeating: "-", count: 60) + "\n"
        report += "• All mileage tracked using IRS standard mileage rate ($0.67/mile for \(String(settings.taxYear)))\n"
        report += "• Business expenses tracked with receipt documentation\n"
        report += "• Self-employed contractor - Schedule C filer\n"
        report += "• \(yearJobs.count) jobs completed in calendar year\n"
        report += "• \(yearExpenses.count) business expense receipts on file\n"
        report += "• \(yearMileageTrips.count) separate business mileage trips logged\n\n"

        report += "END OF REPORT\n"
        report += String(repeating: "=", count: 60) + "\n"

        // Save to file
        let fileName = "YearEndTaxPackage_\(String(settings.taxYear)).txt"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try report.write(to: path, atomically: true, encoding: .utf8)
            taxPackageURL = path
            showingTaxPackageExport = true
        } catch {
            print("Error saving tax package: \(error)")
        }
    }

    private func printTaxReport() {
        // For now, just export the year-end package which can be printed
        exportYearEndPackage()
    }
}
