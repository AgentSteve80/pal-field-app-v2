//
//  WeeklyInvoiceView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct WeeklyInvoiceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Job.jobDate) var allJobs: [Job]
    @EnvironmentObject var settings: Settings
    @State private var selectedWeekStart: Date = .now
    @State private var showingShare = false
    @State private var pdfURL: URL?
    @State private var showingSaveConfirmation = false
    @State private var selectedJobIDs: Set<PersistentIdentifier> = []

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var jobs: [Job] {
        allJobs.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday (1 = Sunday, 2 = Monday)
        return cal
    }

    var weekStart: Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedWeekStart)
        return calendar.date(from: components) ?? selectedWeekStart
    }

    var weekEnd: Date {
        let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        // Set to end of day (23:59:59) to include jobs on the last day
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
    }

    // Jobs within the selected week (Monday to Sunday)
    var weekJobs: [Job] {
        jobs.filter { job in
            let jobDayStart = calendar.startOfDay(for: job.jobDate)
            let weekDayStart = calendar.startOfDay(for: weekStart)
            let weekDayEnd = calendar.startOfDay(for: weekEnd)
            return jobDayStart >= weekDayStart && jobDayStart <= weekDayEnd
        }
        .sorted { $0.jobDate < $1.jobDate }
    }

    // Only selected jobs
    var selectedJobs: [Job] {
        weekJobs.filter { job in
            selectedJobIDs.contains(job.persistentModelID)
        }
    }

    var total: Double {
        selectedJobs.reduce(0) { $0 + $1.total(settings: settings) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Invoice Period") {
                    HStack {
                        Text("Week Beginning:")
                            .font(.subheadline)
                        Spacer()
                        Text(weekStart.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Week Ending:")
                            .font(.subheadline)
                        Spacer()
                        Text(weekEnd.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    DatePicker("Select Week", selection: $selectedWeekStart, displayedComponents: .date)
                        .onChange(of: selectedWeekStart) { _, _ in
                            selectedWeekStart = weekStart
                        }
                }

                Section {
                    Text("Total jobs available: \(weekJobs.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if weekJobs.isEmpty {
                    ContentUnavailableView("No Jobs", systemImage: "doc.badge.plus", description: Text("Add jobs for this week to generate an invoice"))
                } else {
                    Section {
                        HStack {
                            Text("Select Jobs (\(selectedJobs.count) selected)")
                                .font(.headline)

                            Spacer()

                            Button {
                                if selectedJobIDs.count == weekJobs.count {
                                    selectedJobIDs.removeAll()
                                } else {
                                    selectedJobIDs = Set(weekJobs.map { $0.persistentModelID })
                                }
                            } label: {
                                Text(selectedJobIDs.count == weekJobs.count ? "Deselect All" : "Select All")
                                    .font(.subheadline)
                            }
                        }
                    }

                    Section {
                        ForEach(weekJobs) { job in
                            HStack {
                                Button {
                                    toggleSelection(for: job)
                                } label: {
                                    Image(systemName: selectedJobIDs.contains(job.persistentModelID) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(selectedJobIDs.contains(job.persistentModelID) ? .blue : .gray)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(job.jobNumber.isEmpty ? "JB?" : job.jobNumber)
                                        .font(.headline)
                                    HStack {
                                        Text("Lot \(job.lotNumber)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("•")
                                            .foregroundStyle(.secondary)
                                        Text(job.jobDate, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("$\(job.total(settings: settings), specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                toggleSelection(for: job)
                            }
                        }
                    }

                    Section {
                        HStack {
                            Text("Invoice Total")
                                .font(.headline)
                            Spacer()
                            Text("$\(total, specifier: "%.2f")")
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                        }
                    }
                }

                Button("Generate & Save Invoice") {
                    generateFullPDF()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(selectedJobs.isEmpty)
            }
            .navigationTitle("Weekly Invoice")
            .sheet(isPresented: $showingShare) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Invoice Saved", isPresented: $showingSaveConfirmation) {
                Button("View Invoices", role: .none) {
                    // Will be handled by navigation
                }
                Button("Share", role: .none) {
                    showingShare = true
                }
                Button("OK", role: .cancel) { }
            } message: {
                Text("Invoice has been saved and can be viewed in the Invoices tab.")
            }
            .onAppear {
                // Auto-select all jobs for the current week when view appears
                if selectedJobIDs.isEmpty {
                    selectedJobIDs = Set(weekJobs.map { $0.persistentModelID })
                }

                // Debug info
                print("📊 Invoice View Debug:")
                print("  Total jobs in database: \(jobs.count)")
                print("  Week start: \(weekStart)")
                print("  Week end: \(weekEnd)")
                print("  Week jobs: \(weekJobs.count)")
                print("  Selected jobs: \(selectedJobs.count)")

                for job in jobs.prefix(5) {
                    print("  Job: \(job.jobNumber) - Date: \(job.jobDate)")
                }
            }
        }
    }

    // MARK: - Job Selection

    private func toggleSelection(for job: Job) {
        if selectedJobIDs.contains(job.persistentModelID) {
            selectedJobIDs.remove(job.persistentModelID)
        } else {
            selectedJobIDs.insert(job.persistentModelID)
        }
    }

    private func generateFullPDF() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        let fileName = "Invoice_\(formatter.string(from: weekStart))_to_\(formatter.string(from: weekEnd))-\(calendar.component(.year, from: weekStart)).pdf"

        print("🔵 Starting PDF generation with \(selectedJobs.count) jobs")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter
        let data = renderer.pdfData { ctx in
            print("🔵 Drawing summary page")
            // MARK: - Page 1 – Summary
            ctx.beginPage()
            drawSummaryPage(cgContext: ctx.cgContext, jobs: selectedJobs, total: total, weekStart: weekStart)

            // MARK: - Detail pages (one per real job)
            for job in selectedJobs where job.total(settings: settings) > 0 {
                print("🔵 Drawing detail page for job \(job.jobNumber)")
                ctx.beginPage()
                drawDetailPage(cgContext: ctx.cgContext, job: job)
            }
        }

        print("🔵 PDF data size: \(data.count) bytes")

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: tempURL)
            print("✅ PDF written to: \(tempURL)")
        } catch {
            print("❌ Failed to write PDF: \(error)")
        }
        pdfURL = tempURL

        // Save invoice to database
        let invoice = Invoice(
            weekStart: weekStart,
            weekEnd: weekEnd,
            total: total,
            jobCount: selectedJobs.count,
            pdfData: data
        )

        // Set owner info from current user
        invoice.ownerEmail = GmailAuthManager.shared.userEmail
        invoice.ownerName = settings.workerName

        modelContext.insert(invoice)
        try? modelContext.save()

        // Show confirmation
        showingSaveConfirmation = true
    }

    // MARK: - Summary Page
    private func drawSummaryPage(cgContext cg: CGContext, jobs: [Job], total: Double, weekStart: Date) {
        let orange = UIColor.orange
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let headerFont = UIFont.boldSystemFont(ofSize: 14)
        let bodyFont = UIFont.systemFont(ofSize: 12)

        // White background for entire page
        cg.setFillColor(UIColor.white.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: 612, height: 792))

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
        "Invoice Summary".draw(at: CGPoint(x: 306 - 120, y: 40), withAttributes: titleAttrs)

        // Company info
        let blackAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.black]
        let boldBlack: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.black]

        "Company:".draw(at: CGPoint(x: 50, y: 90), withAttributes: boldBlack)
        settings.companyName.draw(at: CGPoint(x: 140, y: 90), withAttributes: blackAttrs)

        "Name:".draw(at: CGPoint(x: 50, y: 110), withAttributes: boldBlack)
        settings.workerName.draw(at: CGPoint(x: 140, y: 110), withAttributes: blackAttrs)

        "Address:".draw(at: CGPoint(x: 50, y: 130), withAttributes: boldBlack)
        settings.homeAddress.draw(at: CGPoint(x: 140, y: 130), withAttributes: blackAttrs)

        "Phone:".draw(at: CGPoint(x: 50, y: 150), withAttributes: boldBlack)
        settings.phoneNumber.draw(at: CGPoint(x: 140, y: 150), withAttributes: blackAttrs)

        // Invoice date
        let dateStr = weekStart.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year())
        "Invoice Date \(dateStr)".draw(at: CGPoint(x: 380, y: 150), withAttributes: blackAttrs)

        // Table headers
        let headerAttrs: [NSAttributedString.Key: Any] = [.font: headerFont, .foregroundColor: UIColor.black]
        "Job #".draw(at: CGPoint(x: 60, y: 210), withAttributes: headerAttrs)
        "Amount".draw(at: CGPoint(x: 210, y: 210), withAttributes: headerAttrs)
        "Job Date".draw(at: CGPoint(x: 360, y: 210), withAttributes: headerAttrs)

        // Only selected jobs (no blank rows)
        var y: CGFloat = 240
        for (i, job) in jobs.enumerated() {
            let jb = !job.jobNumber.isEmpty ? job.jobNumber : "JB\(i + 1)"
            let jobTotal = job.total(settings: settings)
            let amount = String(format: "$%.2f", jobTotal)
            let dateStr = job.jobDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year())

            jb.draw(at: CGPoint(x: 60, y: y), withAttributes: [.font: bodyFont])
            amount.draw(at: CGPoint(x: 210, y: y), withAttributes: [.font: bodyFont])
            dateStr.draw(at: CGPoint(x: 360, y: y), withAttributes: [.font: bodyFont])

            y += 20
        }

        // Total bar
        y += 10
        cg.setFillColor(orange.cgColor)
        cg.fill(CGRect(x: 0, y: y, width: 612, height: 50))

        let totalAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.black]
        String(format: "Total Amount: $%.2f", total).draw(at: CGPoint(x: 306 - 150, y: y + 10), withAttributes: totalAttrs)
    }

    // MARK: - Detail Page
    private func drawDetailPage(cgContext cg: CGContext, job: Job) {
        let body = UIFont.systemFont(ofSize: 12)
        let bold = UIFont.boldSystemFont(ofSize: 12)
        let header = UIFont.boldSystemFont(ofSize: 14)

        // White background for entire page
        cg.setFillColor(UIColor.white.cgColor)
        cg.fill(CGRect(x: 0, y: 0, width: 612, height: 792))

        var y: CGFloat = 60

        // Header info
        "Lot #".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.black])
        job.lotNumber.draw(at: CGPoint(x: 120, y: y), withAttributes: [.font: body, .foregroundColor: UIColor.black])
        y += 30

        "ADDRESS/PROSPECT:".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.black])
        (!job.address.isEmpty ? job.address : job.prospect).draw(at: CGPoint(x: 220, y: y), withAttributes: [.font: body, .foregroundColor: UIColor.black])
        y += 30

        "Date".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.black])
        job.jobDate.formatted(.dateTime.month(.twoDigits).day(.twoDigits).year()).draw(at: CGPoint(x: 120, y: y), withAttributes: [.font: body, .foregroundColor: UIColor.black])
        y += 30

        "CASE REASON: PREWIRE".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.black])
        y += 40

        // PREWIRE table header with black background
        cg.setFillColor(UIColor.black.cgColor)
        cg.fill(CGRect(x: 50, y: y - 5, width: 512, height: 25))

        "PREWIRE".draw(at: CGPoint(x: 55, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.white])
        "UNIT".draw(at: CGPoint(x: 320, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.white])
        "UNIT TOTAL".draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.white])
        y += 25

        func line(_ name: String, qty: Int, price: Double) {
            let total = Double(qty) * price
            if qty > 0 {
                name.draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: body])
                String(format: "%d ($%.2f)", qty, price).draw(at: CGPoint(x: 320, y: y), withAttributes: [.font: body])
                String(format: "$%.2f", total).draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: body])
                y += 20
            }
        }

        line("Per wire run", qty: job.wireRuns, price: settings.priceForWireRun())
        line("Enclosure", qty: job.enclosure, price: settings.priceForEnclosure())
        line("Flat panel prewire same stud", qty: job.flatPanelStud, price: settings.priceForFlatPanelStud())
        line("Flat panel prewire same wall", qty: job.flatPanelWall, price: settings.priceForFlatPanelWall())
        line("Flat panel prewire remote", qty: job.flatPanelRemote, price: settings.priceForFlatPanelRemote())
        line("Flex Tube Feeds", qty: job.flexTube, price: settings.priceForFlexTube())
        line("Media Box", qty: job.mediaBox, price: settings.priceForMediaBox())
        line("Dry Run", qty: job.dryRun, price: settings.priceForDryRun())
        line("Service Run 30min", qty: job.serviceRun, price: settings.priceForServiceRun())

        // TOTAL ROUGH-IN
        "TOTAL ROUGH-IN".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: bold])
        String(format: "$%.2f", job.itemsSubtotal(settings: settings)).draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: bold])
        y += 50

        // TRIM with black background
        cg.setFillColor(UIColor.black.cgColor)
        cg.fill(CGRect(x: 50, y: y - 5, width: 512, height: 25))

        "TRIM".draw(at: CGPoint(x: 55, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.white])
        y += 60
        "TOTAL FINISH $0.00".draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: body, .foregroundColor: UIColor.black])
        y += 50

        // Additional Items with black background
        cg.setFillColor(UIColor.black.cgColor)
        cg.fill(CGRect(x: 50, y: y - 5, width: 512, height: 25))

        "Additional Items".draw(at: CGPoint(x: 55, y: y), withAttributes: [.font: header, .foregroundColor: UIColor.white])
        y += 30
        "Dry run ($25.00)".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: body])
        "$0.00".draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: body])
        y += 20
        "Service 1st 30 minutes ($20.00)".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: body])
        "$0.00".draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: body])
        y += 30

        // Miles not shown on contractor invoice (tracked internally for reimbursement)

        y += 30
        "TOTAL".draw(at: CGPoint(x: 50, y: y), withAttributes: [.font: bold])
        String(format: "$%.2f", job.total(settings: settings)).draw(at: CGPoint(x: 450, y: y), withAttributes: [.font: bold])
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
