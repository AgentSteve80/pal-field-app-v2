//
//  LocalSearchService.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation
import SwiftData
import PDFKit

struct SearchResult: Identifiable {
    let id = UUID()
    let source: SearchSource
    let title: String
    let snippet: String
    let date: Date?
    let relevanceScore: Int
}

enum SearchSource {
    case email
    case blueprint
    case knowledge

    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .blueprint: return "doc.fill"
        case .knowledge: return "book.fill"
        }
    }

    var label: String {
        switch self {
        case .email: return "Email"
        case .blueprint: return "Blueprint"
        case .knowledge: return "Knowledge"
        }
    }
}

class LocalSearchService {
    static let shared = LocalSearchService()

    private var indexedBlueprints: [IndexedDocument] = []

    private init() {
        loadIndexedBlueprints()
    }

    // MARK: - Email Search

    func searchEmails(query: String, in emails: [CachedEmail], limit: Int = 5) -> [SearchResult] {
        let keywords = query.lowercased().split(separator: " ").map(String.init)
        var results: [SearchResult] = []

        for email in emails {
            let searchText = "\(email.subject) \(email.bodyText) \(email.snippet)".lowercased()
            var score = 0

            for keyword in keywords {
                if keyword.count < 3 { continue } // Skip short words
                if searchText.contains(keyword) {
                    score += 1
                    // Bonus for subject match
                    if email.subject.lowercased().contains(keyword) {
                        score += 2
                    }
                }
            }

            if score > 0 {
                // Extract relevant snippet
                let snippet = extractRelevantSnippet(from: email.bodyText, keywords: keywords)

                results.append(SearchResult(
                    source: .email,
                    title: email.subject,
                    snippet: snippet,
                    date: email.date,
                    relevanceScore: score
                ))
            }
        }

        // Sort by relevance, then date
        return results
            .sorted { ($0.relevanceScore, $0.date ?? .distantPast) > ($1.relevanceScore, $1.date ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    private func extractRelevantSnippet(from text: String, keywords: [String], maxLength: Int = 200) -> String {
        let lowerText = text.lowercased()

        // Find first keyword occurrence
        for keyword in keywords {
            if let range = lowerText.range(of: keyword) {
                let startIndex = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
                let endIndex = text.index(range.upperBound, offsetBy: 150, limitedBy: text.endIndex) ?? text.endIndex
                var snippet = String(text[startIndex..<endIndex])
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)

                if startIndex != text.startIndex {
                    snippet = "..." + snippet
                }
                if endIndex != text.endIndex {
                    snippet = snippet + "..."
                }
                return snippet
            }
        }

        // Fallback to first part of text
        let endIndex = text.index(text.startIndex, offsetBy: min(maxLength, text.count), limitedBy: text.endIndex) ?? text.endIndex
        return String(text[..<endIndex]).replacingOccurrences(of: "\n", with: " ") + "..."
    }

    // MARK: - Blueprint/PDF Search

    struct IndexedDocument: Codable {
        let id: UUID
        let filename: String
        let text: String
        let dateIndexed: Date
    }

    func indexBlueprint(url: URL) -> Bool {
        guard let text = extractTextFromPDF(url: url) else { return false }

        let doc = IndexedDocument(
            id: UUID(),
            filename: url.lastPathComponent,
            text: text,
            dateIndexed: Date()
        )

        indexedBlueprints.append(doc)
        saveIndexedBlueprints()
        return true
    }

    func extractTextFromPDF(url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }

        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        return fullText.isEmpty ? nil : fullText
    }

    func searchBlueprints(query: String, limit: Int = 3) -> [SearchResult] {
        let keywords = query.lowercased().split(separator: " ").map(String.init)
        var results: [SearchResult] = []

        for doc in indexedBlueprints {
            let searchText = doc.text.lowercased()
            var score = 0

            for keyword in keywords {
                if keyword.count < 3 { continue }
                if searchText.contains(keyword) {
                    score += 1
                }
            }

            if score > 0 {
                let snippet = extractRelevantSnippet(from: doc.text, keywords: keywords)

                results.append(SearchResult(
                    source: .blueprint,
                    title: doc.filename,
                    snippet: snippet,
                    date: doc.dateIndexed,
                    relevanceScore: score
                ))
            }
        }

        return results
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Persistence

    private var blueprintIndexURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("blueprint_index.json")
    }

    private func saveIndexedBlueprints() {
        do {
            let data = try JSONEncoder().encode(indexedBlueprints)
            try data.write(to: blueprintIndexURL)
        } catch {
            print("Failed to save blueprint index: \(error)")
        }
    }

    private func loadIndexedBlueprints() {
        do {
            let data = try Data(contentsOf: blueprintIndexURL)
            indexedBlueprints = try JSONDecoder().decode([IndexedDocument].self, from: data)
        } catch {
            indexedBlueprints = []
        }
    }

    var indexedBlueprintCount: Int {
        indexedBlueprints.count
    }

    func clearBlueprintIndex() {
        indexedBlueprints = []
        try? FileManager.default.removeItem(at: blueprintIndexURL)
    }
}
