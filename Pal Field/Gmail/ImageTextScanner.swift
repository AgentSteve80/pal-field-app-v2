//
//  ImageTextScanner.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import UIKit
import Vision

/// Scans images for text using Apple's Vision framework
class ImageTextScanner {

    /// Scan an image for any addresses
    static func extractAddress(from imageURL: URL) async -> String? {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            return nil
        }

        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract all recognized text
                var allText: [String] = []
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    allText.append(topCandidate.string)
                }

                // Try to find an address
                if let address = findAddress(in: allText) {
                    continuation.resume(returning: address)
                } else {
                    continuation.resume(returning: nil)
                }
            }

            // Use accurate recognition level for better results
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    /// Find an address pattern in the recognized text lines
    private static func findAddress(in lines: [String]) -> String? {
        // Common street suffixes to look for
        let streetSuffixes = [
            "St", "Street", "Ave", "Avenue", "Way", "Circle", "Cir",
            "Rd", "Road", "Dr", "Drive", "Ln", "Lane", "Blvd", "Boulevard",
            "Ct", "Court", "Pl", "Place", "Pkwy", "Parkway", "Ter", "Terrace",
            "Trail", "Trl", "Path", "Run", "Pass", "Loop", "Crossing"
        ]

        let suffixPattern = streetSuffixes.joined(separator: "|")

        var potentialAddress: String?

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for: digits + street name + street suffix (e.g., "3222 Fawn Circle")
            let streetPattern = #"^\d+\s+[A-Za-z]+\s+("#  + suffixPattern + #")\b"#
            if trimmed.range(of: streetPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                // Found a real street address
                potentialAddress = trimmed

                // Try to include the next line if it looks like city/state/zip
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    // Check if next line has city, state, zip pattern
                    if nextLine.range(of: #"[A-Za-z]+,?\s+[A-Z]{2}\s+\d{5}"#, options: .regularExpression) != nil {
                        potentialAddress = "\(trimmed), \(nextLine)"
                    }
                }

                break
            }

            // Also check for full address in single line with street suffix
            let fullAddressPattern = #"\d+\s+[A-Za-z]+\s+("# + suffixPattern + #").*[A-Za-z]+,?\s+[A-Z]{2}\s+\d{5}"#
            if trimmed.range(of: fullAddressPattern, options: [.regularExpression, .caseInsensitive]) != nil {
                potentialAddress = trimmed
                break
            }
        }

        // If no address found yet, look for line after "Address" label
        if potentialAddress == nil {
            for (index, line) in lines.enumerated() {
                let lowerLine = line.lowercased()
                if lowerLine.contains("address") && index + 1 < lines.count {
                    let nextLine = lines[index + 1].trimmingCharacters(in: .whitespaces)
                    // Check if next line starts with a number (street address)
                    if nextLine.first?.isNumber == true {
                        potentialAddress = nextLine

                        // Try to get city/state/zip from following line
                        if index + 2 < lines.count {
                            let cityLine = lines[index + 2].trimmingCharacters(in: .whitespaces)
                            if cityLine.range(of: #"[A-Za-z]+,?\s+[A-Z]{2}\s+\d{5}"#, options: .regularExpression) != nil {
                                potentialAddress = "\(nextLine), \(cityLine)"
                            }
                        }
                        break
                    }
                }
            }
        }

        return potentialAddress
    }

    /// Extract Account# from an image (for prospect number)
    static func extractAccountNumber(from imageURL: URL) async -> String? {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            return nil
        }

        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Extract all recognized text
                var allText: [String] = []
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    allText.append(topCandidate.string)
                }

                // Try to find Account# pattern
                if let accountNum = findAccountNumber(in: allText) {
                    continuation.resume(returning: accountNum)
                } else {
                    continuation.resume(returning: nil)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    /// Find Account# or Prospect# pattern in the recognized text lines
    private static func findAccountNumber(in lines: [String]) -> String? {
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for "Account#", "Account #", "Prospect#", or "Prospect #" followed by digits
            let patterns = [
                #"Account\s*#?\s*:?\s*(\d+)"#,
                #"Prospect\s*#?\s*:?\s*(\d+)"#,
                #"Customer\s*#?\s*:?\s*(\d+)"#
            ]

            for pattern in patterns {
                if let range = trimmed.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                    let matched = trimmed[range]
                    // Extract just the numbers
                    let numberPattern = #"\d+"#
                    if let numRange = matched.range(of: numberPattern, options: .regularExpression) {
                        return String(matched[numRange])
                    }
                }
            }
        }
        return nil
    }

    /// Extract all text from an image (useful for debugging)
    static func extractAllText(from imageURL: URL) async -> String? {
        guard let image = UIImage(contentsOfFile: imageURL.path) else {
            return nil
        }

        guard let cgImage = image.cgImage else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                let allText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: allText.isEmpty ? nil : allText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
}
