//
//  TavilyService.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import Foundation

struct TavilySearchResult: Codable {
    let title: String
    let url: String
    let content: String
    let score: Double?
}

struct TavilyResponse: Codable {
    let query: String
    let results: [TavilySearchResult]
    let answer: String?
}

class TavilyService {
    static let shared = TavilyService()

    private let baseURL = "https://api.tavily.com/search"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "tavilyAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "tavilyAPIKey") }
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    private init() {
        // Set default API key if not already set
        if apiKey.isEmpty {
            apiKey = "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"
        }
    }

    // MARK: - Search

    func search(query: String, maxResults: Int = 5) async throws -> [TavilySearchResult] {
        guard isConfigured else {
            print("❌ Tavily not configured")
            throw TavilyError.notConfigured
        }

        guard let url = URL(string: baseURL) else {
            throw TavilyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        // Enhance query for low-voltage/prewire context
        let enhancedQuery = "\(query) low voltage electrical wiring"
        print("🔍 Tavily searching: \(enhancedQuery)")

        let body: [String: Any] = [
            "api_key": apiKey,
            "query": enhancedQuery,
            "search_depth": "basic",
            "max_results": maxResults,
            "include_answer": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TavilyError.invalidResponse
        }

        print("🔍 Tavily response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 429 {
            throw TavilyError.rateLimited
        }

        if httpResponse.statusCode != 200 {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ Tavily error: \(errorBody)")
            }
            throw TavilyError.apiError(statusCode: httpResponse.statusCode)
        }

        let tavilyResponse = try JSONDecoder().decode(TavilyResponse.self, from: data)
        print("✅ Tavily found \(tavilyResponse.results.count) results")
        return tavilyResponse.results
    }

    /// Format search results for inclusion in AI prompt
    func formatResultsForPrompt(_ results: [TavilySearchResult]) -> String {
        guard !results.isEmpty else { return "" }

        var formatted = "\n\n=== WEB RESEARCH RESULTS (USE THIS TO ANSWER) ===\n"
        formatted += "The following is current information from the web. USE THIS DATA in your response:\n"

        for (index, result) in results.prefix(4).enumerated() {
            formatted += "\n📄 SOURCE \(index + 1): \(result.title)\n"
            formatted += "URL: \(result.url)\n"
            formatted += "Content: \(result.content.prefix(600))\n"
        }

        formatted += "\n=== END OF RESEARCH ===\n"
        formatted += "INSTRUCTION: Base your answer on the research above. Start with 'Based on my research...' and mention specific findings."

        return formatted
    }
}

// MARK: - Errors

enum TavilyError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case rateLimited
    case apiError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Tavily API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimited:
            return "Rate limited - try again later"
        case .apiError(let code):
            return "API error (status \(code))"
        }
    }
}
