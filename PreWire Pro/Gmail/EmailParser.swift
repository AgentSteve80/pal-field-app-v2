//
//  EmailParser.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import Foundation

/// Parses plain text email content into job data
class EmailParser {

    // MARK: - Public Methods

    /// Parse email with subject line and body text
    static func parse(subject: String, bodyText: String, scannedAddress: String? = nil, scannedAccountNumber: String? = nil) -> ParsedJobData {
        var parsed = ParsedJobData()

        // Parse subject line first (format: "Lot# Subdivision ProspectNumber")
        parseSubjectLine(subject, into: &parsed)

        // If we have a scanned address, use it
        if let address = scannedAddress, !address.isEmpty {
            parsed.address = address
            print("✓ OCR Address: \(address)")
        }

        // If we have a scanned account number, use it as the prospect
        // (Guardian jobs won't have this passed in - handled by caller)
        if let accountNum = scannedAccountNumber, !accountNum.isEmpty {
            let oldProspect = parsed.prospect
            parsed.prospect = accountNum
            print("✓ OCR Account# (Prospect): \(accountNum) [replaced subject: \(oldProspect)]")
        }

        // Then parse body text
        let lines = bodyText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        print("=== Parsing Email ===")
        print("Subject: \(subject)")
        print("Lines: \(lines.count)")

        parseBodyText(lines, into: &parsed)

        print("=== Parsing Complete ===")
        print("Valid: \(parsed.isValid)")
        print("Final Prospect: \(parsed.prospect)")

        return parsed
    }

    /// Parse email body text into ParsedJobData (legacy method for compatibility)
    static func parse(_ emailBody: String) -> ParsedJobData {
        return parse(subject: "", bodyText: emailBody, scannedAddress: nil)
    }

    // MARK: - Subject Line Parsing

    /// Parse subject line in format: "(P) 127 Courtyards Russell 52260357"
    /// Format: (JobType) LotNumber Subdivision ProspectNumber
    /// Example: "(P) 127 Courtyards Russell 52260357"
    private static func parseSubjectLine(_ subject: String, into parsed: inout ParsedJobData) {
        let trimmed = subject.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return }

        var workingString = trimmed
        var startIndex = 0

        // Extract job type if present (e.g., "(P)", "(R)")
        if let jobTypeMatch = workingString.range(of: #"\([A-Z]\)"#, options: .regularExpression) {
            let jobTypeStr = String(workingString[jobTypeMatch])
            // Remove parentheses
            parsed.jobType = jobTypeStr.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
            print("✓ Job Type from subject: \(parsed.jobType)")
            // Remove job type from working string
            workingString = workingString.replacingCharacters(in: jobTypeMatch, with: "").trimmingCharacters(in: .whitespaces)
        }

        // Split remaining by spaces
        let parts = workingString.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return }

        // First part: Lot number (should be digits)
        if let lotNum = extractDigits(from: parts[0]) {
            parsed.lotNumber = lotNum
            print("✓ Lot # from subject: \(lotNum)")
            startIndex = 1
        }

        guard parts.count > startIndex else { return }

        // Last part: Prospect number (if it's all digits and >= 6 characters)
        if let lastPart = parts.last,
           let prospectNum = extractDigits(from: lastPart),
           prospectNum.count >= 6 { // Prospect numbers are usually longer
            parsed.prospect = prospectNum
            print("✓ Prospect from subject: \(prospectNum)")

            // Middle parts: Subdivision (words between lot and first number/prospect)
            // Stop at the first part that starts with a digit (street address)
            if parts.count > startIndex + 1 {
                var subdivisionParts: [String] = []
                for i in startIndex..<(parts.count - 1) {
                    let part = parts[i]
                    // Stop if this part starts with a digit (street address number)
                    if let firstChar = part.first, firstChar.isNumber {
                        break
                    }
                    subdivisionParts.append(part)
                }
                if !subdivisionParts.isEmpty {
                    parsed.subdivision = subdivisionParts.joined(separator: " ")
                    print("✓ Subdivision from subject: \(parsed.subdivision)")
                }
            }
        } else {
            // No prospect number, take words until first number
            var subdivisionParts: [String] = []
            for i in startIndex..<parts.count {
                let part = parts[i]
                // Stop if this part starts with a digit
                if let firstChar = part.first, firstChar.isNumber {
                    break
                }
                subdivisionParts.append(part)
            }
            if !subdivisionParts.isEmpty {
                parsed.subdivision = subdivisionParts.joined(separator: " ")
                print("✓ Subdivision from subject: \(parsed.subdivision)")
            }
        }
    }

    private static func extractDigits(from string: String) -> String? {
        let digits = string.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return digits.isEmpty ? nil : digits
    }

    // MARK: - Body Text Parsing

    private static func parseBodyText(_ lines: [String], into parsed: inout ParsedJobData) {
        for (index, line) in lines.enumerated() {
            let lowerLine = line.lowercased()

            // Extract builder company (Epcon, Beazer, Drees, Pulte, MI)
            if parsed.builderCompany.isEmpty {
                if let builder = extractBuilderCompany(from: line) {
                    parsed.builderCompany = builder
                    print("✓ Builder: \(builder)")
                }
            }

            // Extract job number
            if parsed.jobNumber.isEmpty {
                if let jobNum = extractJobNumber(from: line) {
                    parsed.jobNumber = jobNum
                    print("✓ Job #: \(jobNum)")
                }
            }

            // Extract lot number
            if parsed.lotNumber.isEmpty {
                if let lotNum = extractLotNumber(from: line) {
                    parsed.lotNumber = lotNum
                    print("✓ Lot #: \(lotNum)")
                }
            }

            // Extract address
            if parsed.address.isEmpty {
                if lowerLine.contains("address") || lowerLine.contains("location") {
                    if let value = extractValue(from: line, after: ":") {
                        parsed.address = value
                        print("✓ Address: \(value)")
                    } else if index + 1 < lines.count {
                        // Try next line
                        parsed.address = lines[index + 1]
                        print("✓ Address: \(lines[index + 1])")
                    }
                }
            }

            // Extract prospect/subdivision
            if parsed.prospect.isEmpty {
                if lowerLine.contains("prospect") || lowerLine.contains("subdivision") || lowerLine.contains("builder") {
                    if let value = extractValue(from: line, after: ":") {
                        parsed.prospect = value
                        print("✓ Prospect: \(value)")
                    } else if index + 1 < lines.count {
                        parsed.prospect = lines[index + 1]
                        print("✓ Prospect: \(lines[index + 1])")
                    }
                }
            }

            // Extract date
            if let date = extractDate(from: line) {
                parsed.jobDate = date
                print("✓ Date: \(date)")
            }

            // Extract quantities
            if lowerLine.contains("wire") && lowerLine.contains("run") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.wireRuns = value
                    print("✓ Wire Runs: \(value)")
                }
            }

            if lowerLine.contains("enclosure") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.enclosure = value
                    print("✓ Enclosure: \(value)")
                }
            }

            if (lowerLine.contains("flat") || lowerLine.contains("fp")) && lowerLine.contains("stud") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.flatPanelStud = value
                    print("✓ FP Stud: \(value)")
                }
            }

            if (lowerLine.contains("flat") || lowerLine.contains("fp")) && lowerLine.contains("wall") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.flatPanelWall = value
                    print("✓ FP Wall: \(value)")
                }
            }

            if (lowerLine.contains("flat") || lowerLine.contains("fp")) && lowerLine.contains("remote") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.flatPanelRemote = value
                    print("✓ FP Remote: \(value)")
                }
            }

            if lowerLine.contains("flex") || (lowerLine.contains("tube") && !lowerLine.contains("youtube")) {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.flexTube = value
                    print("✓ Flex Tube: \(value)")
                }
            }

            if lowerLine.contains("media") && lowerLine.contains("box") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.mediaBox = value
                    print("✓ Media Box: \(value)")
                }
            }

            if lowerLine.contains("dry") && lowerLine.contains("run") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.dryRun = value
                    print("✓ Dry Run: \(value)")
                }
            }

            if lowerLine.contains("service") && lowerLine.contains("run") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.serviceRun = value
                    print("✓ Service Run: \(value)")
                }
            }

            if lowerLine.contains("mile") {
                if let value = extractQuantity(from: line, nextLine: index + 1 < lines.count ? lines[index + 1] : "") {
                    parsed.miles = Double(value)
                    print("✓ Miles: \(value)")
                }
            }
        }
    }

    // MARK: - Private Helper Methods

    private static func extractJobNumber(from line: String) -> String? {
        let patterns = [
            #"JB\s*#?\s*:?\s*(\d+)"#,   // JB # : 123 or JB: 123 or JB 123
            #"(JB\d+)"#,                 // JB123
            #"Job\s*#?\s*:?\s*JB(\d+)"#, // Job #: JB123
            #"Job\s*#?\s*:?\s*(\d+)"#    // Job #: 123
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                // Check if we captured a group
                if match.numberOfRanges > 1 {
                    let captured = (line as NSString).substring(with: match.range(at: 1))
                    // If it's just digits, add JB prefix
                    if captured.range(of: #"^\d+$"#, options: .regularExpression) != nil {
                        return "JB\(captured)"
                    }
                    return captured.uppercased()
                } else {
                    // Return the whole match
                    return (line as NSString).substring(with: match.range).uppercased()
                }
            }
        }

        return nil
    }

    private static func extractLotNumber(from line: String) -> String? {
        let patterns = [
            #"Lot\s*#?\s*:?\s*(\d+)"#,  // Lot # : 123 or Lot: 123 or Lot 123
            #"Lot\s+(\d+)"#              // Lot 123
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1 {
                return (line as NSString).substring(with: match.range(at: 1))
            }
        }

        return nil
    }

    private static func extractValue(from line: String, after separator: String) -> String? {
        guard let separatorRange = line.range(of: separator) else {
            return nil
        }

        let value = String(line[separatorRange.upperBound...])
            .trimmingCharacters(in: .whitespaces)

        return value.isEmpty ? nil : value
    }

    private static func extractQuantity(from line: String, nextLine: String) -> Int? {
        let patterns = [
            #":?\s*(\d+)"#,              // : 12 or 12
            #"qty:?\s*(\d+)"#,           // qty: 12 or qty 12
            #"quantity:?\s*(\d+)"#,      // quantity: 12
            #"^(\d+)$"#                  // Just a number on its own line
        ]

        // Try current line first
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1 {
                let numStr = (line as NSString).substring(with: match.range(at: 1))
                if let num = Int(numStr) {
                    return num
                }
            }
        }

        // Try next line
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine)),
               match.numberOfRanges > 1 {
                let numStr = (nextLine as NSString).substring(with: match.range(at: 1))
                if let num = Int(numStr) {
                    return num
                }
            }
        }

        return nil
    }

    private static func extractDate(from line: String) -> Date? {
        let patterns = [
            #"(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})"#,  // MM/DD/YYYY or MM-DD-YY
            #"(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})"#      // YYYY-MM-DD
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {

                let comp1 = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
                let comp2 = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                let comp3 = Int((line as NSString).substring(with: match.range(at: 3))) ?? 0

                var year: Int
                var month: Int
                var day: Int

                // Determine format based on first component
                if comp1 > 31 {
                    // YYYY-MM-DD format
                    year = comp1
                    month = comp2
                    day = comp3
                } else {
                    // MM-DD-YYYY or DD-MM-YYYY format (assume MM-DD-YYYY for US)
                    month = comp1
                    day = comp2
                    year = comp3
                }

                // Convert 2-digit year to 4-digit
                if year < 100 {
                    year += 2000
                }

                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = day

                if let date = Calendar.current.date(from: components) {
                    return date
                }
            }
        }

        return nil
    }

    /// Extract builder company name from text
    /// Looks for: Epcon, Beazer, Drees, Pulte, MI (M/I Homes)
    private static func extractBuilderCompany(from line: String) -> String? {
        let lowerLine = line.lowercased()

        // Known builder names (case-insensitive matching, return canonical name)
        let builders: [(pattern: String, name: String)] = [
            ("epcon", "Epcon"),
            ("beazer", "Beazer"),
            ("drees", "Drees"),
            ("pulte", "Pulte"),
            ("m/i", "MI"),
            ("m i homes", "MI"),
            ("mi homes", "MI"),
            ("guardian", "Guardian"),
            ("guardian protection", "Guardian"),
        ]

        for (pattern, name) in builders {
            if lowerLine.contains(pattern) {
                return name
            }
        }

        return nil
    }
}
