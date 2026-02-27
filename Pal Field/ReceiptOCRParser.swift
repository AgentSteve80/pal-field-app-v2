//
//  ReceiptOCRParser.swift
//  Pal Field
//
//  Enhanced receipt OCR parsing with category guessing and structured extraction.
//

import Foundation
import Vision
import UIKit

struct ReceiptOCRResult {
    var vendorName: String?
    var totalAmount: Double?
    var date: Date?
    var suggestedCategory: String?  // Maps to ExpenseCategory.rawValue
}

class ReceiptOCRParser {

    // MARK: - Main Parse

    /// Run OCR on image and parse structured receipt data
    static func parseReceipt(image: UIImage) async -> ReceiptOCRResult {
        guard let cgImage = image.cgImage else {
            return ReceiptOCRResult()
        }

        let lines = await recognizeText(cgImage: cgImage)
        guard !lines.isEmpty else { return ReceiptOCRResult() }

        print("📄 OCR found \(lines.count) lines")

        let vendor = extractVendor(from: lines)
        let amount = extractTotal(from: lines)
        let date = extractDate(from: lines)
        let category = guessCategory(vendor: vendor)

        return ReceiptOCRResult(
            vendorName: vendor,
            totalAmount: amount,
            date: date,
            suggestedCategory: category
        )
    }

    // MARK: - OCR

    private static func recognizeText(cgImage: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("❌ OCR error: \(error)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Vendor Extraction

    private static func extractVendor(from lines: [String]) -> String? {
        // First few lines typically contain vendor name
        for line in lines.prefix(5) {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count > 2 else { continue }

            let upper = cleaned.uppercased()
            // Skip lines that are just numbers, dates, or addresses
            if upper.allSatisfy({ $0.isNumber || $0 == "/" || $0 == "-" || $0 == "." || $0 == " " }) { continue }
            if upper.contains("RECEIPT") || upper.contains("INVOICE") { continue }
            if upper.range(of: "\\d{3,}", options: .regularExpression) != nil && cleaned.count < 15 { continue }

            // Known vendor keywords
            let knownVendors = ["HOME DEPOT", "LOWE", "MENARD", "WALMART", "SHELL", "BP", "MARATHON",
                                "SPEEDWAY", "KROGER", "MCDONALD", "SUBWAY", "CHICK-FIL-A", "WENDY",
                                "TACO BELL", "AUTOZONE", "O'REILLY", "ACE HARDWARE", "HARBOR FREIGHT",
                                "COSTCO", "SAM'S CLUB", "TARGET", "AMAZON", "GRAINGER", "FASTENAL"]

            for vendor in knownVendors {
                if upper.contains(vendor) {
                    return cleaned
                }
            }

            // If line has letters and is substantial, likely vendor
            if cleaned.rangeOfCharacter(from: .letters) != nil && cleaned.count > 3 {
                return cleaned
            }
        }
        return nil
    }

    // MARK: - Total Extraction

    private static func extractTotal(from lines: [String]) -> Double? {
        // Scan from bottom up — total is usually near the end
        let totalPatterns = ["TOTAL", "AMOUNT DUE", "BALANCE DUE", "GRAND TOTAL", "AMOUNT", "DUE"]
        let amountRegex = try? NSRegularExpression(pattern: "\\$?([0-9]+\\.[0-9]{2})")

        // First pass: look for lines with "TOTAL" keyword + amount
        for line in lines.reversed() {
            let upper = line.uppercased()
            for keyword in totalPatterns {
                if upper.contains(keyword) {
                    if let match = amountRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                       match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: line),
                       let amount = Double(String(line[range])) {
                        // Skip subtotals (look for "SUB" prefix)
                        if upper.contains("SUB") { continue }
                        return amount
                    }
                }
            }
        }

        // Second pass: find largest dollar amount (likely the total)
        var largestAmount: Double = 0
        for line in lines {
            if let match = amountRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: line),
               let amount = Double(String(line[range])) {
                if amount > largestAmount && amount < 10000 { // Sanity check
                    largestAmount = amount
                }
            }
        }

        return largestAmount > 0 ? largestAmount : nil
    }

    // MARK: - Date Extraction

    private static func extractDate(from lines: [String]) -> Date? {
        let dateRegex = try? NSRegularExpression(pattern: "(\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4})")
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for line in lines {
            guard let match = dateRegex?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let range = Range(match.range(at: 1), in: line) else { continue }

            let dateStr = String(line[range])
            for format in ["MM/dd/yyyy", "MM-dd-yyyy", "MM/dd/yy", "MM-dd-yy"] {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateStr) {
                    // Fix 2-digit years
                    let cal = Calendar.current
                    let year = cal.component(.year, from: date)
                    if year < 100 {
                        var comps = cal.dateComponents([.year, .month, .day], from: date)
                        comps.year = 2000 + year
                        return cal.date(from: comps) ?? date
                    }
                    return date
                }
            }
        }
        return nil
    }

    // MARK: - Category Guessing

    static func guessCategory(vendor: String?) -> String? {
        guard let vendor = vendor?.uppercased() else { return nil }

        let categoryMap: [(keywords: [String], category: String)] = [
            (["SHELL", "BP", "MARATHON", "SPEEDWAY", "SUNOCO", "EXXON", "MOBIL",
              "CHEVRON", "CIRCLE K", "PILOT", "CASEY", "GAS", "FUEL", "PETRO"],
             "Gas"),

            (["HOME DEPOT", "LOWE", "MENARD", "ACE HARDWARE", "HARBOR FREIGHT",
              "GRAINGER", "FASTENAL", "SUPPLY", "LUMBER", "ELECTRIC", "PLUMB"],
             "Supplies"),

            (["MCDONALD", "BURGER", "WENDY", "TACO BELL", "SUBWAY", "CHICK-FIL-A",
              "CHIPOTLE", "PIZZA", "RESTAURANT", "DINER", "CAFE", "COFFEE",
              "STARBUCKS", "DUNKIN", "PANERA", "ARBY"],
             "Meals"),
        ]

        for (keywords, category) in categoryMap {
            if keywords.contains(where: { vendor.contains($0) }) {
                return category
            }
        }

        return nil
    }
}
