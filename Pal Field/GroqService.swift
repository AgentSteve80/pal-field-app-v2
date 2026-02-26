//
//  GroqService.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import Foundation

class GroqService {
    static let shared = GroqService()

    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let model = "mistralai/mistral-7b-instruct"

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "openrouterAPIKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openrouterAPIKey") }
    }

    var isConfigured: Bool {
        true  // Always configured - will use web search even without LLM
    }

    private init() {
        // OpenRouter API key
        let currentKey = ""
        if apiKey != currentKey {
            apiKey = currentKey
        }
    }

    // MARK: - Builder Context

    private let builderContext = """
    You are a helpful assistant for Pal Field, an app for low-voltage palfield technicians. Answer questions about builder installation standards and app features.

    BUILDER STANDARDS:

    ## MI HOMES - "5 wires Minimum"
    DMARK: Flex tube and 1 coax, single outlet jblock, flash sides and top, coil wires inside and blank plate
    WIRING: Data Only, dual ports in family room and owner's bedroom, 1 WAP, 1 hub keypad per print (if not marked, 4" above garage entry light switch), all exterior wall outlets in BLUE boxes, 9" from corner or door frame
    ENCLOSURE: 30" OnQ per print, contact super for location questions, scab 2x4 horizontally to corners if not attached to stud on both sides
    FPP: 2 HDMI and pass through cat 6, closet OnQs at 56" AFF from top of OnQ
    3 Story Townhomes: Tube ran to garage ceiling, 1 coax and 1 data ran to side of unit

    ## PULTE HOMES - "Flex tube only"
    DMARK: Flex tube only (NO coax), jblock and flash on sides and top, brick exterior: install jblock 8" above brick line or even with bottom of electric meter
    WIRING: Dual port in family room
    ENCLOSURE: 30" OnQ behind laundry door (unless basement), if basement exists enclosure must be there, scab 2x4 to corners, closet OnQs at 56" AFF from top
    FPP: 2 HDMI, pass through cat 6, tube
    MODEL: Office data lines homerun to office kiosk, kiosk gets its own dmark run + 1 coax 1 data from kiosk to enclosure
    Stellar Floorplan: 52" to bottom of enclosure

    ## BEAZER HOMES - "Flex tape"
    DMARK: Flex tube and 1 coax, flash card, jblock, FLEX TAPE on sides and top, add bubble box at trim
    WIRING: Dual ports in family room, owner's bedroom, AND loft, ALL wires in BLUE boxes only
    ENCLOSURE: 30" OnQ marked on prints (usually laundry or owner's bedroom closet), scab 2x4 to corners, closet OnQs at 56" AFF from top
    FPP: TUBE ONLY, use special enclosed nail in conduit box
    MODEL: Wires ran to enclosure, office wires homerun in office to termination point, 1 coax + 1 data ran to dmark AND to enclosure from office homerun location

    ## DREES HOMES - "Flextape on jblock"
    DMARK: Flex tube and 1 coax, flash card, jblock and flash sides and top, brick exterior: 8" above brick line, bubble box at trim, FLEXTAPE on jblock
    WIRING: 4 wires any configuration, 1 WAP
    ENCLOSURE: 30" OnQ in owner's bedroom closet (if basement: under basement stairs), scab 2x4 to corners, closet OnQs at 56" AFF from top
    FPP: 2 HDMI and pass through cat 6, OR flex tube only (check contract)
    MODEL: All wires ran to enclosure

    ## EPCON HOMES - "Blue flash card"
    DMARK: Per contract (can be tube, wires, or both), blue flash card, zip tape flashing on sides and top
    WIRING: 2-3 data marked on print, ALL wires in BLUE boxes (except FPPs)
    ENCLOSURE: 30" OnQ in closet, centered in rear, max 68" to top, CAN NOT BE ON EXTERIOR WALL OR WALL SHARED WITH GARAGE, scab 2x4 to corners, closet OnQs at 56" AFF from top
    FPP: 2 HDMIs, pass through cat 6, tube (can be tube only, check contract)
    MODEL: All wires ran to enclosure
    Courtyards Westfield: Dmark must be tube + 1 coax + 1 data

    BLUE BOX REQUIREMENTS:
    - MI Homes: Exterior walls only
    - Beazer: ALL wires
    - Epcon: ALL wires (except FPPs)
    - Pulte: Standard boxes OK
    - Drees: Not specified

    IMPORTANT INSTRUCTIONS:
    - Keep answers concise and practical (2-4 sentences max)
    - DO NOT use markdown formatting (no #, *, **, ```, etc.)
    - Use plain text only with simple dashes (-) for lists
    - When web research results are provided below, use them to answer
    - You can answer ANY question about low-voltage, electrical, palfield, wiring
    """

    private let tavilyService = TavilyService.shared

    // MARK: - API Call

    func ask(question: String, includeWebSearch: Bool = true, useLLM: Bool = true) async throws -> String {
        // Perform web search if enabled
        var searchResults: [TavilySearchResult] = []
        print("🔍 Settings - Web: \(includeWebSearch), LLM: \(useLLM)")

        if includeWebSearch {
            print("🔍 Starting web search for: \(question)")
            do {
                searchResults = try await tavilyService.search(query: question, maxResults: 4)
                print("✅ Got \(searchResults.count) search results")
            } catch {
                print("❌ Web search failed: \(error)")
            }
        }

        // If LLM enabled and we have an API key, try using it
        if useLLM && !apiKey.isEmpty {
            do {
                let response = try await callLLM(question: question, searchResults: searchResults)
                return response
            } catch {
                print("❌ LLM failed: \(error), using web results directly")
            }
        }

        // Fallback: Format web search results directly
        if !searchResults.isEmpty {
            return formatSearchResultsAsAnswer(question: question, results: searchResults)
        }

        // No results - throw to trigger local assistant
        throw GroqError.notConfigured
    }

    private func callLLM(question: String, searchResults: [TavilySearchResult]) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw GroqError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://palfield.pro", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Pal Field", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = 45

        let researchContext = tavilyService.formatResultsForPrompt(searchResults)
        let fullContext = builderContext + researchContext

        let messages: [[String: String]] = [
            ["role": "system", "content": fullContext],
            ["role": "user", "content": question]
        ]

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.4,
            "max_tokens": 800
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw GroqError.rateLimited
        }

        if httpResponse.statusCode != 200 {
            if let errorBody = String(data: data, encoding: .utf8) {
                print("❌ LLM error response: \(errorBody)")
            }
            throw GroqError.apiError(statusCode: httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Format search results as a readable answer when LLM is unavailable
    private func formatSearchResultsAsAnswer(question: String, results: [TavilySearchResult]) -> String {
        var answer = "Based on my web research:\n\n"

        for result in results.prefix(3) {
            // Extract key info from content
            let content = String(result.content.prefix(300))
            answer += "**\(result.title)**\n"
            answer += "\(content)...\n\n"
        }

        answer += "_Sources: \(results.prefix(3).map { $0.url.components(separatedBy: "/").dropFirst(2).first ?? "" }.joined(separator: ", "))_"

        return answer
    }
}

// MARK: - Errors

enum GroqError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case rateLimited
    case apiError(statusCode: Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Groq API key not configured"
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .rateLimited:
            return "Rate limited - try again in a moment"
        case .apiError(let code):
            return "API error (status \(code))"
        case .parseError:
            return "Failed to parse response"
        }
    }
}
