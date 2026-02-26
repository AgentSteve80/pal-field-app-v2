//
//  PDFImportView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 12/13/25.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct PDFImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    
    @State private var showingFilePicker = false
    @State private var importStatus: String = "Select a PDF invoice to import"
    @State private var isProcessing = false
    @State private var importedJobs: [Job] = []
    @State private var showingConfirmation = false
    @State private var showingVerification = false
    @State private var currentPDFDocument: PDFDocument?
    @State private var currentVerificationJob: Job?
    @State private var verificationIndex = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Upload Icon
                Image(systemName: "arrow.up.doc.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding()
                
                Text("Import Jobs from PDF")
                    .font(.title2.bold())
                
                Text(importStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if isProcessing {
                    ProgressView("Processing PDF...")
                        .padding()
                }
                
                if !importedJobs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Found \(importedJobs.count) job(s)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(importedJobs) { job in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(job.jobNumber)
                                                .font(.headline)
                                            Text("Lot \(job.lotNumber)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(job.jobDate, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("$\(job.total(settings: settings), specifier: "%.2f")")
                                            .font(.title3.bold())
                                            .foregroundStyle(.green)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                        
                        Button {
                            verifyAndImport()
                        } label: {
                            Label("Import \(importedJobs.count) Job(s)", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Select PDF File", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding()
                .disabled(isProcessing)
            }
            .navigationTitle("Import from PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Jobs?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Import") {
                    importJobs()
                }
            } message: {
                Text("This will add \(importedJobs.count) job(s) to your database.")
            }
            .sheet(isPresented: $showingVerification) {
                if let job = currentVerificationJob {
                    JobVerificationView(
                        job: job,
                        pdfDocument: currentPDFDocument,
                        settings: settings,
                        onConfirm: { verifiedJob in
                            importedJobs[verificationIndex] = verifiedJob
                            verificationIndex += 1
                            if verificationIndex < importedJobs.count {
                                currentVerificationJob = importedJobs[verificationIndex]
                            } else {
                                showingVerification = false
                                showingConfirmation = true
                            }
                        },
                        onSkip: {
                            showingVerification = false
                            showingConfirmation = true
                        }
                    )
                }
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let fileURL = try result.get().first else { return }

            // Start accessing a security-scoped resource
            guard fileURL.startAccessingSecurityScopedResource() else {
                importStatus = "Unable to access file"
                return
            }

            defer { fileURL.stopAccessingSecurityScopedResource() }

            isProcessing = true
            importStatus = "Processing PDF..."

            // Copy file to temporary location while we have access
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")

            do {
                // Copy the file
                try FileManager.default.copyItem(at: fileURL, to: tempURL)

                // Now process the temp file (we own this file, no security issues)
                Task {
                    await processPDF(at: tempURL)
                }
            } catch {
                importStatus = "Unable to read PDF file: \(error.localizedDescription)"
                isProcessing = false
            }
        } catch {
            importStatus = "Error selecting file: \(error.localizedDescription)"
        }
    }
    
    private func processPDF(at url: URL) async {
        guard let pdfDocument = PDFDocument(url: url) else {
            await MainActor.run {
                importStatus = "Unable to read PDF file"
                isProcessing = false
            }
            return
        }
        
        // Save PDF document for verification
        await MainActor.run {
            currentPDFDocument = pdfDocument
        }
        
        var extractedJobs: [Job] = []
        
        // Skip page 0 (summary page), process all detail pages starting from page 1
        print("=== Starting PDF Import ===")
        print("Total pages: \(pdfDocument.pageCount)")
        
        for pageIndex in 1..<pdfDocument.pageCount {
            print("\n=== Processing Page \(pageIndex + 1) ===")
            
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                
                if let detailJob = parseDetailPage(pageText) {
                    print("Successfully parsed job: \(detailJob.jobNumber)")
                    extractedJobs.append(detailJob)
                } else {
                    print("Failed to parse page \(pageIndex + 1)")
                }
            }
        }
        
        await MainActor.run {
            importedJobs = extractedJobs
            if extractedJobs.isEmpty {
                importStatus = "No valid jobs found in PDF. Check console for details."
            } else {
                importStatus = "Ready to import \(extractedJobs.count) job(s)"
            }
            isProcessing = false
        }
    }
    
    private func extractDateRange(from filename: String) -> (start: Date, end: Date)? {
        // Example: "7:28-7:30.pdf" or "7-28-7-30.pdf"
        let pattern = #"(\d+)[:\-](\d+)[:\-](\d+)[:\-](\d+)"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) else {
            return nil
        }
        
        // Extract month and day values
        let month1 = Int((filename as NSString).substring(with: match.range(at: 1))) ?? 1
        let day1 = Int((filename as NSString).substring(with: match.range(at: 2))) ?? 1
        let month2 = Int((filename as NSString).substring(with: match.range(at: 3))) ?? 1
        let day2 = Int((filename as NSString).substring(with: match.range(at: 4))) ?? 1
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)
        
        var components1 = DateComponents()
        components1.year = year
        components1.month = month1
        components1.day = day1
        
        var components2 = DateComponents()
        components2.year = year
        components2.month = month2
        components2.day = day2
        
        guard let startDate = calendar.date(from: components1),
              let endDate = calendar.date(from: components2) else {
            return nil
        }
        
        return (startDate, endDate)
    }
    
    private func extractJobNumber(from line: String) -> String? {
        // Try multiple patterns for job number
        let patterns = [
            #"JB\d+"#,           // JB12345
            #"JB\s*\d+"#,        // JB 12345
            #"Job\s*#?\s*(\d+)"# // Job # 12345 or Job 12345
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let matched = (line as NSString).substring(with: match.range)
                // Normalize to JB format
                let digits = matched.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if !digits.isEmpty {
                    return "JB\(digits)"
                }
            }
        }
        return nil
    }
    
    private func extractAmount(from line: String, orNextLines lines: [String], startingAt index: Int) -> Double {
        // Look for $XX.XX pattern
        let pattern = #"\$(\d+\.?\d*)"#
        
        // Check current line and next 2 lines
        for i in index...min(index + 2, lines.count - 1) {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lines[i], range: NSRange(lines[i].startIndex..., in: lines[i])) else {
                continue
            }
            let amountStr = (lines[i] as NSString).substring(with: match.range(at: 1))
            if let amount = Double(amountStr) {
                return amount
            }
        }
        return 0
    }
    
    private func extractDate(from line: String, orNextLines lines: [String], startingAt index: Int, fallbackRange: (start: Date, end: Date)?) -> Date? {
        // Look for date pattern MM/DD/YY or MM-DD-YY
        let pattern = #"(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})"#
        
        for i in index...min(index + 2, lines.count - 1) {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: lines[i], range: NSRange(lines[i].startIndex..., in: lines[i])) else {
                continue
            }
            
            let month = Int((lines[i] as NSString).substring(with: match.range(at: 1))) ?? 1
            let day = Int((lines[i] as NSString).substring(with: match.range(at: 2))) ?? 1
            var year = Int((lines[i] as NSString).substring(with: match.range(at: 3))) ?? 2025
            
            // Convert 2-digit year to 4-digit
            if year < 100 {
                year += 2000
            }
            
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            
            if let date = Calendar.current.date(from: components) {
                print("📅 Extracted date: \(month)/\(day)/\(year) from line: [\(lines[i])]")
                return date
            }
        }
        
        // Fallback to range start if available, otherwise return nil
        if let fallback = fallbackRange?.start {
            print("⚠️ Using fallback date from range")
            return fallback
        }
        
        print("❌ Failed to extract date")
        return nil
    }
    
    private func parseDetailPage(_ text: String) -> Job? {
        let lines = text.components(separatedBy: .newlines)

        // Debug: Print all lines to see what we're working with
        print("=== PDF Detail Page Content ===")
        for (i, line) in lines.enumerated() {
            print("\(i): [\(line)]")
        }
        print("=== End PDF Content ===")

        var jobNumber = ""
        var lotNumber = ""
        var addressProspect = "" // Combined field from PDF
        var jobDate = Date()
        var wireRuns = 0
        var enclosure = 0
        var flatPanelStud = 0
        var flatPanelWall = 0
        var flatPanelRemote = 0
        var flexTube = 0
        var mediaBox = 0
        var dryRun = 0
        var serviceRun = 0
        var miles = 0.0

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            let lowerLine = trimmedLine.lowercased()

            // Extract job number - look for JB pattern
            if jobNumber.isEmpty, let jb = extractJobNumber(from: trimmedLine) {
                jobNumber = jb
                print("✓ Found Job #: \(jobNumber)")
            }

            // Extract lot number - look for "Lot #" at the start of a line
            if lotNumber.isEmpty, lowerLine.hasPrefix("lot") {
                let patterns = [
                    #"lot\s*#?\s*:?\s*(\d+)"#,
                    #"lot\s*(\d+)"#
                ]

                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                       let match = regex.firstMatch(in: trimmedLine, range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
                        lotNumber = (trimmedLine as NSString).substring(with: match.range(at: 1))
                        print("✓ Found Lot #: \(lotNumber)")
                        break
                    }
                }
            }

            // Extract address/prospect - line starting with ADDRESS/PROSPECT:
            if addressProspect.isEmpty, lowerLine.hasPrefix("address") {
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    let value = trimmedLine[trimmedLine.index(after: colonIndex)...].trimmingCharacters(in: .whitespaces)
                    // Remove the case number if present (e.g., "IGA/ 50310096" -> "IGA")
                    let parts = value.components(separatedBy: "/")
                    addressProspect = parts[0].trimmingCharacters(in: .whitespaces)
                    if addressProspect.contains(",") {
                        // Has comma, keep everything before case number
                        let commaParts = value.components(separatedBy: ",")
                        addressProspect = commaParts[0].trimmingCharacters(in: .whitespaces)
                    }
                    print("✓ Found Address/Prospect: \(addressProspect)")
                }
            }

            // Extract date - line starting with Date
            if lowerLine.hasPrefix("date") {
                if let extractedDate = extractDate(from: trimmedLine, orNextLines: lines, startingAt: index, fallbackRange: nil) {
                    jobDate = extractedDate
                    print("✓ Found Date: \(jobDate)")
                } else {
                    print("⚠️ Could not extract date from line: [\(trimmedLine)]")
                }
            }

            // Now parse quantities from the structured lines 4-10
            // Line 4: Has all labels + first quantity numbers at the END
            // Lines 5-10: Have individual item quantities

            if index == 4 && lowerLine.contains("per wire run") {
                // Extract the last few numbers before the prices
                // Pattern: "...Media Box (17" wall-mount media box) 10 1 ($ ($ 9.00) $90.00)]"
                // We want: 10 (wire runs), 1 (enclosure)
                // The "17" is part of description, not a quantity

                // Remove the description text that has numbers in it
                let cleanedLine = trimmedLine.replacingOccurrences(of: "(17\"", with: "(XX\"")
                let numbers = extractAllNumbers(from: cleanedLine)
                print("📊 Found numbers in cleaned prewire line: \(numbers)")

                if numbers.count >= 2 {
                    // First meaningful numbers should be quantities
                    // Filter out obvious prices (> 50 usually means it's a price like 90.00)
                    let quantities = numbers.filter { $0 < 50 }
                    if quantities.count >= 1 {
                        wireRuns = quantities[0]
                        // DON'T set enclosure here - it picks up wrong values
                        print("✓ Extracted Wire Runs: \(wireRuns) from line 4")
                    }
                }
            }

            // Parse individual quantity lines 5-10
            // Format: "1 ($ 12.00) $12.00)]"
            if index >= 5 && index <= 10 {
                if let qty = extractLeadingQuantity(from: trimmedLine) {
                    switch index {
                    case 5:
                        enclosure = qty
                        print("✓ Line 5 - Enclosure: \(qty)")
                    case 6:
                        flatPanelStud = qty
                        print("✓ Line 6 - Flat Panel Stud: \(qty)")
                    case 7:
                        flatPanelWall = qty
                        print("✓ Line 7 - Flat Panel Wall: \(qty)")
                    case 8:
                        flatPanelRemote = qty
                        print("✓ Line 8 - Flat Panel Remote: \(qty)")
                    case 9:
                        flexTube = qty
                        print("✓ Line 9 - Flex Tube: \(qty)")
                    case 10:
                        mediaBox = qty
                        print("✓ Line 10 - Media Box: \(qty)")
                    default:
                        break
                    }
                }
            }

            // Miles line (line 24 in example): "Miles 10 ($ 0.75) $7.50)]"
            if lowerLine.contains("mile") && !lowerLine.contains("service") {
                let numbers = extractAllNumbers(from: trimmedLine)
                if let firstNum = numbers.first {
                    miles = Double(firstNum)
                    print("✓ Found Miles: \(miles)")
                }
            }

            // Dry run and Service run from Additional Items section (lines 20-21)
            if index == 20 && lowerLine.contains("dry") {
                if let qty = extractLeadingQuantity(from: trimmedLine) {
                    dryRun = qty
                    print("✓ Found Dry Run: \(dryRun)")
                }
            }
            if index == 21 && lowerLine.contains("service") {
                if let qty = extractLeadingQuantity(from: trimmedLine) {
                    serviceRun = qty
                    print("✓ Found Service Run: \(serviceRun)")
                }
            }
        }

        // Only create job if we have lot number
        guard !lotNumber.isEmpty else {
            print("❌ No lot number found - skipping page")
            return nil
        }

        // Job number will be assigned during import based on chronological order
        // For now, use a placeholder
        if jobNumber.isEmpty {
            jobNumber = "TEMP"
            print("⚠️ Job number will be assigned during import")
        }

        print("\n📋 Creating job:")
        print("  Job #: \(jobNumber)")
        print("  Lot: \(lotNumber)")
        print("  Address/Prospect: \(addressProspect.isEmpty ? "N/A" : addressProspect)")
        print("  Date: \(jobDate)")
        print("  Wire Runs: \(wireRuns)")
        print("  Enclosure: \(enclosure)")
        print("  FP Stud: \(flatPanelStud)")
        print("  FP Wall: \(flatPanelWall)")
        print("  FP Remote: \(flatPanelRemote)")
        print("  Flex Tube: \(flexTube)")
        print("  Media Box: \(mediaBox)")
        print("  Dry Run: \(dryRun)")
        print("  Service Run: \(serviceRun)")
        print("  Miles: \(miles)")

        let job = Job(
            jobNumber: jobNumber,
            jobDate: jobDate,
            lotNumber: lotNumber,
            address: "",
            prospect: addressProspect,
            wireRuns: wireRuns,
            enclosure: enclosure,
            flatPanelStud: flatPanelStud,
            flatPanelWall: flatPanelWall,
            flatPanelRemote: flatPanelRemote,
            flexTube: flexTube,
            mediaBox: mediaBox,
            dryRun: dryRun,
            serviceRun: serviceRun,
            miles: miles,
            payTierValue: settings.payTier.rawValue
        )
        // Set owner info
        job.ownerEmail = GmailAuthManager.shared.userEmail
        job.ownerName = settings.workerName
        return job
    }
    
    private func extractAllNumbers(from text: String) -> [Int] {
        var numbers: [Int] = []
        let pattern = #"\b(\d+)\b"#
        
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                let numStr = (text as NSString).substring(with: match.range(at: 1))
                if let num = Int(numStr), num < 1000 { // Exclude prices like 9.00 converted to 900
                    numbers.append(num)
                }
            }
        }
        return numbers
    }
    
    private func extractLeadingQuantity(from text: String) -> Int? {
        // Look for a number at the start of the line before "($"
        let pattern = #"^\s*(\d+)\s*\(\$"#
        
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let numStr = (text as NSString).substring(with: match.range(at: 1))
            return Int(numStr)
        }
        return nil
    }
    
    private func extractQuantity(from line: String, orNextLine nextLine: String) -> Int {
        // Try multiple patterns for quantity extraction
        let patterns = [
            #"(\d+)\s*\(\$"#,  // "11 ($9.00)"
            #"(\d+)\s*\("#,     // "11 ("
            #"^(\d+)\s*$"#      // Just a number on its own line
        ]
        
        // Check current line
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let qtyStr = (line as NSString).substring(with: match.range(at: 1))
                if let qty = Int(qtyStr) {
                    return qty
                }
            }
        }
        
        // Check next line (quantity might be on the line after the label)
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine)) {
                let qtyStr = (nextLine as NSString).substring(with: match.range(at: 1))
                if let qty = Int(qtyStr) {
                    return qty
                }
            }
        }
        
        return 0
    }
    
    private func extractMiles(from line: String, orNextLine nextLine: String) -> Double {
        // Look for pattern like "Miles 38" or just "38" on next line
        let patterns = [
            #"miles\s+(\d+\.?\d*)"#,
            #"(\d+\.?\d*)\s*\("#,
            #"^(\d+\.?\d*)\s*$"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                let milesStr = (line as NSString).substring(with: match.range(at: 1))
                if let m = Double(milesStr) {
                    return m
                }
            }
        }
        
        // Check next line
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine)) {
                let milesStr = (nextLine as NSString).substring(with: match.range(at: 1))
                if let m = Double(milesStr) {
                    return m
                }
            }
        }
        
        return 0.0
    }
    
    private func verifyAndImport() {
        // Skip verification and go straight to confirmation
        showingConfirmation = true
    }
    
    private func importJobs() {
        // Fetch existing jobs to check for duplicates
        let fetchDescriptor = FetchDescriptor<Job>()
        guard let existingJobs = try? modelContext.fetch(fetchDescriptor) else {
            // If we can't fetch, assign job numbers and import all
            assignJobNumbers(to: importedJobs, existingJobs: [])
            
            for job in importedJobs {
                modelContext.insert(job)
            }
            
            do {
                try modelContext.save()
                dismiss()
            } catch {
                importStatus = "Error saving jobs: \(error.localizedDescription)"
            }
            return
        }
        
        // Create a set of existing job identifiers (lot # + date)
        var existingIdentifiers = Set<String>()
        let calendar = Calendar.current
        for existingJob in existingJobs {
            let dateKey = calendar.startOfDay(for: existingJob.jobDate).timeIntervalSince1970
            let identifier = "\(existingJob.lotNumber)-\(dateKey)"
            existingIdentifiers.insert(identifier)
        }
        
        // Filter out duplicates
        var jobsToImport: [Job] = []
        var skippedCount = 0
        
        for job in importedJobs {
            let dateKey = calendar.startOfDay(for: job.jobDate).timeIntervalSince1970
            let identifier = "\(job.lotNumber)-\(dateKey)"
            
            if existingIdentifiers.contains(identifier) {
                skippedCount += 1
                print("⚠️ Skipping duplicate: Lot \(job.lotNumber) on \(job.jobDate)")
            } else {
                jobsToImport.append(job)
                existingIdentifiers.insert(identifier) // Prevent duplicates within import batch
            }
        }
        
        // Assign sequential job numbers to the jobs we're importing
        assignJobNumbers(to: jobsToImport, existingJobs: existingJobs)
        
        // Insert the jobs
        for job in jobsToImport {
            modelContext.insert(job)
        }
        
        do {
            try modelContext.save()
            
            if skippedCount > 0 {
                importStatus = "Imported \(jobsToImport.count) job(s), skipped \(skippedCount) duplicate(s)"
                // Delay dismiss to show the message
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            } else {
                dismiss()
            }
        } catch {
            importStatus = "Error saving jobs: \(error.localizedDescription)"
        }
    }
    
    /// Assign sequential job numbers to imported jobs
    /// Jobs are numbered based on their chronological order (oldest first)
    private func assignJobNumbers(to jobs: [Job], existingJobs: [Job]) {
        // Sort imported jobs by date (oldest first)
        let sortedJobs = jobs.sorted { $0.jobDate < $1.jobDate }
        
        // Get the starting job number (one after the highest existing number)
        let highestNumber = existingJobs.compactMap { $0.jobNumberValue }.max() ?? 0
        var nextNumber = highestNumber + 1
        
        // Assign sequential numbers
        for job in sortedJobs {
            job.jobNumber = "JB\(nextNumber)"
            print("📝 Assigned job number: JB\(nextNumber) to job dated \(job.jobDate)")
            nextNumber += 1
        }
    }
}

// MARK: - Job Verification View
struct JobVerificationView: View {
    @Environment(\.dismiss) private var dismiss
    let job: Job
    let pdfDocument: PDFDocument?
    let settings: Settings
    let onConfirm: (Job) -> Void
    let onSkip: () -> Void
    
    @State private var editedJob: Job
    @State private var showPDF = true
    
    init(job: Job, pdfDocument: PDFDocument?, settings: Settings, onConfirm: @escaping (Job) -> Void, onSkip: @escaping () -> Void) {
        self.job = job
        self.pdfDocument = pdfDocument
        self.settings = settings
        self.onConfirm = onConfirm
        self.onSkip = onSkip
        _editedJob = State(initialValue: job)
    }
    
    var pdfTotal: Double {
        // Calculate what the PDF says the total should be
        job.total(settings: settings)
    }
    
    var currentTotal: Double {
        editedJob.total(settings: settings)
    }
    
    var totalsMatch: Bool {
        abs(pdfTotal - currentTotal) < 0.01
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // PDF Preview (if available)
                if showPDF, let pdfDoc = pdfDocument {
                    PDFKitView(document: pdfDoc)
                        .frame(height: 300)
                        .border(Color.gray.opacity(0.3))
                    
                    Toggle("Show PDF", isOn: $showPDF)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                
                // Job Editor
                Form {
                    Section("Job Information") {
                        HStack {
                            Text("Job #:")
                            Spacer()
                            Text(editedJob.jobNumber)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Lot #:")
                            Spacer()
                            Text(editedJob.lotNumber.isEmpty ? "N/A" : editedJob.lotNumber)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Address/Prospect:")
                            Spacer()
                            Text(editedJob.prospect.isEmpty ? (editedJob.address.isEmpty ? "N/A" : editedJob.address) : editedJob.prospect)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section("Extracted Values - Verify & Adjust") {
                        Stepper("Wire Runs: \(editedJob.wireRuns)", value: $editedJob.wireRuns, in: 0...50)
                        Stepper("Enclosure: \(editedJob.enclosure)", value: $editedJob.enclosure, in: 0...10)
                        Stepper("Flat Panel Same Stud: \(editedJob.flatPanelStud)", value: $editedJob.flatPanelStud, in: 0...10)
                        Stepper("Flat Panel Same Wall: \(editedJob.flatPanelWall)", value: $editedJob.flatPanelWall, in: 0...10)
                        Stepper("Flat Panel Remote: \(editedJob.flatPanelRemote)", value: $editedJob.flatPanelRemote, in: 0...10)
                        Stepper("Flex Tube: \(editedJob.flexTube)", value: $editedJob.flexTube, in: 0...5)
                        Stepper("Media Box: \(editedJob.mediaBox)", value: $editedJob.mediaBox, in: 0...5)
                        Stepper("Dry Run: \(editedJob.dryRun)", value: $editedJob.dryRun, in: 0...3)
                        Stepper("Service Run: \(editedJob.serviceRun)", value: $editedJob.serviceRun, in: 0...10)
                    }
                    
                    Section("Total Verification") {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Current Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("$\(currentTotal, specifier: "%.2f")")
                                    .font(.title2.bold())
                                    .foregroundStyle(totalsMatch ? .green : .orange)
                            }
                            Spacer()
                            if totalsMatch {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.green)
                            } else {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        if !totalsMatch {
                            Text("Adjust the values above to match the PDF total of $\(pdfTotal, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Verify Job Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip All") {
                        onSkip()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm(editedJob)
                    }
                    .disabled(!totalsMatch)
                }
            }
        }
    }
}

// MARK: - PDFKit View Wrapper
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFKit.PDFView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFKit.PDFView, context: Context) {
        uiView.document = document
    }
}
