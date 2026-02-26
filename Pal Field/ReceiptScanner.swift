//
//  ReceiptScanner.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import UIKit
import Vision
import CoreImage

/// Scans receipts for amount, merchant, and date using OCR
class ReceiptScanner {

    struct ReceiptData {
        var amount: Double?
        var merchant: String?
        var date: Date?
    }

    // MARK: - Auto Crop Receipt

    /// Automatically detect and crop receipt from image
    static func removeBackground(from image: UIImage) async -> UIImage {
        // DISABLED: Auto-crop causing app freeze
        // Just return original image for now
        print("ℹ️ Auto-crop disabled, using original image")
        return image

        /* DISABLED CODE:
        guard let cgImage = image.cgImage else {
            return image
        }

        // Try rectangle detection first
        if let croppedImage = await detectAndCropRectangle(image: image, cgImage: cgImage) {
            print("✅ Receipt cropped using rectangle detection")
            return croppedImage
        }

        print("⚠️ No receipt detected, using original image")
        return image
        */
    }

    /// Detect rectangle and crop
    private static func detectAndCropRectangle(image: UIImage, cgImage: CGImage) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRectangleObservation],
                      !observations.isEmpty else {
                    print("⚠️ No rectangles detected")
                    continuation.resume(returning: nil)
                    return
                }

                // Try to find the best rectangle (largest area that's not the whole image)
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                var bestObservation: VNRectangleObservation?
                var bestArea: CGFloat = 0

                for observation in observations {
                    let area = observation.boundingBox.width * observation.boundingBox.height

                    // Skip if it's basically the whole image (area > 0.95)
                    if area > 0.95 { continue }

                    // Skip if too small (area < 0.1)
                    if area < 0.1 { continue }

                    if area > bestArea {
                        bestArea = area
                        bestObservation = observation
                    }
                }

                guard let observation = bestObservation else {
                    print("⚠️ No suitable rectangles found")
                    continuation.resume(returning: nil)
                    return
                }

                print("✅ Receipt rectangle detected (area: \(String(format: "%.2f", bestArea)))")

                // Convert normalized coordinates to image coordinates
                // Vision coordinates are flipped, need to convert
                let topLeft = CGPoint(
                    x: observation.topLeft.x * imageSize.width,
                    y: (1 - observation.topLeft.y) * imageSize.height
                )
                let topRight = CGPoint(
                    x: observation.topRight.x * imageSize.width,
                    y: (1 - observation.topRight.y) * imageSize.height
                )
                let bottomLeft = CGPoint(
                    x: observation.bottomLeft.x * imageSize.width,
                    y: (1 - observation.bottomLeft.y) * imageSize.height
                )
                let bottomRight = CGPoint(
                    x: observation.bottomRight.x * imageSize.width,
                    y: (1 - observation.bottomRight.y) * imageSize.height
                )

                // Apply perspective correction
                guard let croppedImage = perspectiveCorrect(
                    image: CIImage(cgImage: cgImage),
                    topLeft: topLeft,
                    topRight: topRight,
                    bottomLeft: bottomLeft,
                    bottomRight: bottomRight
                ) else {
                    print("⚠️ Perspective correction failed")
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: croppedImage)
            }

            // Configure request for better receipt detection
            // Receipts can be tall and narrow or wider
            request.minimumAspectRatio = 0.1  // Very narrow (tall receipt)
            request.maximumAspectRatio = 2.0  // Can be wider
            request.minimumSize = 0.05  // Even smaller minimum
            request.minimumConfidence = 0.3  // Lower confidence threshold
            request.maximumObservations = 5  // Get multiple candidates

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("❌ Rectangle detection error: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    /// Apply perspective correction to crop and straighten the receipt
    private static func perspectiveCorrect(
        image: CIImage,
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint
    ) -> UIImage? {
        // Calculate the dimensions of the output rectangle
        let widthTop = distance(topLeft, topRight)
        let widthBottom = distance(bottomLeft, bottomRight)
        _ = max(widthTop, widthBottom)

        let heightLeft = distance(topLeft, bottomLeft)
        let heightRight = distance(topRight, bottomRight)
        _ = max(heightLeft, heightRight)

        // Create perspective transform filter
        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }

        perspectiveFilter.setValue(image, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let outputImage = perspectiveFilter.outputImage else {
            return nil
        }

        // Render to UIImage
        let context = CIContext()
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Calculate distance between two points
    private static func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point2.x - point1.x
        let dy = point2.y - point1.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - OCR Scanning

    /// Scan receipt image for amount, merchant, and date
    static func scanReceipt(_ image: UIImage) async -> ReceiptData {
        guard let cgImage = image.cgImage else {
            return ReceiptData()
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ReceiptData())
                    return
                }

                // Extract text lines
                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

                print("📄 Scanned \(lines.count) text lines from receipt")

                // Extract data
                let amount = extractAmount(from: lines)
                let merchant = extractMerchant(from: lines)
                let date = extractDate(from: lines)

                if let amount = amount {
                    print("💰 Found amount: $\(amount)")
                }
                if let merchant = merchant {
                    print("🏪 Found merchant: \(merchant)")
                }
                if let date = date {
                    print("📅 Found date: \(date)")
                }

                let data = ReceiptData(amount: amount, merchant: merchant, date: date)
                continuation.resume(returning: data)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("❌ OCR error: \(error)")
                continuation.resume(returning: ReceiptData())
            }
        }
    }

    // MARK: - Data Extraction

    private static func extractAmount(from lines: [String]) -> Double? {
        // Look for patterns like "TOTAL: $12.34", "AMOUNT: 12.34", etc.
        let patterns = [
            "TOTAL.*?([0-9]+\\.[0-9]{2})",
            "AMOUNT.*?([0-9]+\\.[0-9]{2})",
            "BALANCE.*?([0-9]+\\.[0-9]{2})",
            "\\$([0-9]+\\.[0-9]{2})"
        ]

        // Reverse lines to prioritize amounts at the bottom (totals)
        for line in lines.reversed() {
            let upperLine = line.uppercased()

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: upperLine, options: [], range: NSRange(upperLine.startIndex..., in: upperLine)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: upperLine) {
                    let amountString = String(upperLine[range])
                    if let amount = Double(amountString) {
                        return amount
                    }
                }
            }
        }

        return nil
    }

    private static func extractMerchant(from lines: [String]) -> String? {
        // Merchant is usually in the first few lines
        // Look for keywords or just use first non-empty line
        let keywords = ["STORE", "SHOP", "MARKET", "PHARMACY", "GAS", "STATION"]

        for line in lines.prefix(5) {
            let cleanedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedLine.isEmpty else { continue }

            // Check if line contains merchant keywords
            let upperLine = cleanedLine.uppercased()
            if keywords.contains(where: { upperLine.contains($0) }) {
                return cleanedLine
            }

            // If line is substantial (not just numbers/symbols), use it
            if cleanedLine.count > 3 && cleanedLine.rangeOfCharacter(from: .letters) != nil {
                return cleanedLine
            }
        }

        return nil
    }

    private static func extractDate(from lines: [String]) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        // Formats to try for full line matching
        let formats = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MM/dd/yy",
            "MM-dd-yy",
            "yyyy-MM-dd",
            "MMM dd, yyyy",
            "MMMM dd, yyyy",
            "dd/MM/yyyy"
        ]

        for line in lines {
            for format in formats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: line) {
                    return adjustYearIfNeeded(date)
                }
            }

            // Try finding date pattern within line
            if let regex = try? NSRegularExpression(pattern: "\\d{1,2}[/-]\\d{1,2}[/-]\\d{2,4}"),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range, in: line) {
                let dateString = String(line[range])

                // Try 4-digit year first, then 2-digit
                let tryFormats = ["MM/dd/yyyy", "MM-dd-yyyy", "MM/dd/yy", "MM-dd-yy"]
                for format in tryFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        return adjustYearIfNeeded(date)
                    }
                }
            }
        }

        return nil
    }

    /// Adjust year if it's in the past (e.g., 0026 should be 2026)
    private static func adjustYearIfNeeded(_ date: Date) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)

        // If year is less than 100, assume it's 20XX
        if year < 100 {
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.year = 2000 + year
            return calendar.date(from: components) ?? date
        }

        return date
    }
}
