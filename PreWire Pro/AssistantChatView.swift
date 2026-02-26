//
//  AssistantChatView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
import Vision

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let relatedTopics: [String]
    var emailResults: [SearchResult]
    var blueprintResults: [SearchResult]
    let query: String?  // Store original query for email search
    let image: UIImage?  // Attached image
    let timestamp: Date = Date()

    init(text: String, isUser: Bool, relatedTopics: [String], emailResults: [SearchResult] = [], blueprintResults: [SearchResult] = [], query: String? = nil, image: UIImage? = nil) {
        self.text = text
        self.isUser = isUser
        self.relatedTopics = relatedTopics
        self.emailResults = emailResults
        self.blueprintResults = blueprintResults
        self.query = query
        self.image = image
    }
}

struct AssistantChatBar: View {
    @State private var showingChat = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        Button {
            showingChat = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(brandGreen)

                Text("Ask about builders, app features...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingChat) {
            AssistantChatView()
        }
    }
}

struct AssistantChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var cachedEmails: [CachedEmail]
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var showingBlueprintImporter = false
    @State private var showingSettings = false
    @State private var isTyping = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingCamera = false
    @FocusState private var isInputFocused: Bool

    // Feature toggles
    @AppStorage("assistantWebSearchEnabled") private var webSearchEnabled = false
    @AppStorage("assistantLLMEnabled") private var llmEnabled = true
    @AppStorage("assistantLocalAIEnabled") private var localAIEnabled = true

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)
    private let assistant = PreWireAssistant.shared
    private let searchService = LocalSearchService.shared
    private let groqService = GroqService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome message if empty
                            if messages.isEmpty {
                                WelcomeMessage()
                                    .padding(.top, 20)
                            }

                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                MessageBubble(
                                    message: message,
                                    onTopicTap: { topic in
                                        askQuestion(topic)
                                    },
                                    onSearchEmails: {
                                        searchEmailsForMessage(at: index)
                                    }
                                )
                                .id(message.id)
                            }

                            // Typing indicator
                            if isTyping {
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.caption)
                                            .foregroundStyle(brandGreen)
                                        TypingIndicator()
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Spacer()
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Quick suggestions
                if messages.isEmpty || messages.count < 3 {
                    QuickSuggestions(onTap: askQuestion)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // Selected image preview
                if let image = selectedImage {
                    HStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Button {
                                    selectedImage = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.white, .red)
                                }
                                .offset(x: 8, y: -8),
                                alignment: .topTrailing
                            )
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }

                // Input bar
                HStack(spacing: 8) {
                    // Photo picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "photo")
                            .font(.title3)
                            .foregroundStyle(brandGreen)
                    }

                    TextField("Ask a question...", text: $inputText)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(inputText.isEmpty && selectedImage == nil ? .gray : brandGreen)
                    }
                    .disabled(inputText.isEmpty && selectedImage == nil)
                }
                .padding()
                .background(Color.black)
            }
            .background(Color.black)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            selectedImage = image
                        }
                    }
                }
            }
            .navigationTitle("PreWire Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 16) {
                        Button {
                            showingBlueprintImporter = true
                        } label: {
                            Image(systemName: "doc.badge.plus")
                                .foregroundStyle(brandGreen)
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundStyle(brandGreen)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(brandGreen)
                }
            }
            .sheet(isPresented: $showingSettings) {
                AssistantSettingsView(
                    webSearchEnabled: $webSearchEnabled,
                    llmEnabled: $llmEnabled,
                    localAIEnabled: $localAIEnabled
                )
            }
            .fileImporter(
                isPresented: $showingBlueprintImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        if url.startAccessingSecurityScopedResource() {
                            defer { url.stopAccessingSecurityScopedResource() }
                            if searchService.indexBlueprint(url: url) {
                                let systemMessage = ChatMessage(
                                    text: "Indexed blueprint: \(url.lastPathComponent)",
                                    isUser: false,
                                    relatedTopics: []
                                )
                                messages.append(systemMessage)
                            }
                        }
                    }
                case .failure(let error):
                    print("Blueprint import failed: \(error)")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sendMessage() {
        let hasText = !inputText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasImage = selectedImage != nil

        guard hasText || hasImage else { return }

        let messageText = hasText ? inputText : "What's in this image?"
        let attachedImage = selectedImage

        let userMessage = ChatMessage(
            text: messageText,
            isUser: true,
            relatedTopics: [],
            image: attachedImage
        )
        messages.append(userMessage)

        let question = inputText
        inputText = ""
        selectedImage = nil
        selectedPhoto = nil
        isTyping = true

        // If there's an image, extract text with OCR
        Task {
            var fullQuestion = question

            if let image = attachedImage {
                let extractedText = await extractTextFromImage(image)
                if !extractedText.isEmpty {
                    fullQuestion = question.isEmpty
                        ? "I'm sharing a photo. Here's the text I can see in it:\n\n\(extractedText)\n\nWhat can you tell me about this?"
                        : "\(question)\n\n[Text from photo: \(extractedText)]"
                }
            }

            do {
                // Use AI service with web search (respects feature toggles)
                print("🤖 Calling AI with question: \(fullQuestion)")
                print("🔧 Settings - Web Search: \(webSearchEnabled), LLM: \(llmEnabled)")
                let aiResponse = try await groqService.ask(
                    question: fullQuestion,
                    includeWebSearch: webSearchEnabled,
                    useLLM: llmEnabled
                )
                print("🤖 Got AI response: \(aiResponse.prefix(100))...")

                await MainActor.run {
                    isTyping = false
                    let assistantMessage = ChatMessage(
                        text: aiResponse,
                        isUser: false,
                        relatedTopics: [],
                        query: question.isEmpty ? nil : question
                    )
                    messages.append(assistantMessage)
                }
            } catch {
                // Fall back to built-in assistant if enabled
                print("❌ AI service failed: \(error.localizedDescription)")
                await MainActor.run {
                    isTyping = false
                    if localAIEnabled {
                        print("📚 Using local knowledge base")
                        let response = assistant.answer(question: fullQuestion, emails: [])
                        let assistantMessage = ChatMessage(
                            text: response.text,
                            isUser: false,
                            relatedTopics: response.relatedTopics,
                            query: question.isEmpty ? nil : question
                        )
                        messages.append(assistantMessage)
                    } else {
                        let assistantMessage = ChatMessage(
                            text: "I couldn't find an answer. Try enabling Web Research or Local AI in settings.",
                            isUser: false,
                            relatedTopics: [],
                            query: nil
                        )
                        messages.append(assistantMessage)
                    }
                }
            }
        }
    }

    private func extractTextFromImage(_ image: UIImage) async -> String {
        guard let cgImage = image.cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private func searchEmailsForMessage(at index: Int) {
        guard index < messages.count,
              let query = messages[index].query else { return }

        let results = searchService.searchEmails(query: query, in: Array(cachedEmails), limit: 3)
        messages[index].emailResults = results
    }

    private func askQuestion(_ question: String) {
        inputText = question
        sendMessage()
    }
}

struct WelcomeMessage: View {
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)
    private let searchService = LocalSearchService.shared
    private let groqService = GroqService.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(brandGreen)

            Text("PreWire Assistant")
                .font(.title2.bold())
                .foregroundStyle(.white)

            // AI Badge
            if groqService.isConfigured {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("AI + Web Research")
                        .font(.caption2)
                }
                .foregroundStyle(.cyan)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.cyan.opacity(0.2))
                .clipShape(Capsule())
            }

            Text("Ask me anything about low-voltage, prewire, wiring, or builder standards. I'll research the web to find answers.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Search capabilities
            HStack(spacing: 16) {
                VStack {
                    Image(systemName: "globe")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                    Text("Web Search")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack {
                    Image(systemName: "book.fill")
                        .font(.title3)
                        .foregroundStyle(brandGreen)
                    Text("5 Builders")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack {
                    Image(systemName: "envelope.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                    Text("Emails")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                VStack {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    Text("Photos")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
}

struct QuickSuggestions: View {
    let onTap: (String) -> Void

    private let suggestions = [
        "MI Homes wire minimum?",
        "Pulte DMARK specs?",
        "Which builders need blue boxes?",
        "How do I track mileage?"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onTap(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage
    let onTopicTap: (String) -> Void
    let onSearchEmails: () -> Void

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Image if attached
                if let image = message.image {
                    HStack {
                        if message.isUser { Spacer() }
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        if !message.isUser { Spacer() }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    if !message.isUser {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundStyle(brandGreen)
                            .frame(width: 24, height: 24)
                            .background(brandGreen.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(message.isUser ? brandGreen : Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Search Emails button (show if query exists and no results yet)
                if !message.isUser && message.query != nil && message.emailResults.isEmpty {
                    Button {
                        onSearchEmails()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "envelope.fill")
                                .font(.caption)
                            Text("Search Emails")
                                .font(.caption)
                        }
                        .foregroundStyle(brandGreen)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(brandGreen.opacity(0.15))
                        .clipShape(Capsule())
                    }
                    .padding(.leading, 32)
                }

                // Email search results
                if !message.emailResults.isEmpty && !message.isUser {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                            Text("From your emails:")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.leading, 32)

                        ForEach(message.emailResults) { result in
                            SearchResultCard(result: result)
                                .padding(.leading, 32)
                        }
                    }
                }

                // Blueprint search results
                if !message.blueprintResults.isEmpty && !message.isUser {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("From blueprints:")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.leading, 32)

                        ForEach(message.blueprintResults) { result in
                            SearchResultCard(result: result)
                                .padding(.leading, 32)
                        }
                    }
                }

                // Related topics
                if !message.relatedTopics.isEmpty && !message.isUser {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(message.relatedTopics, id: \.self) { topic in
                                Button {
                                    onTopicTap(topic)
                                } label: {
                                    Text(topic)
                                        .font(.caption2)
                                        .foregroundStyle(brandGreen)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(brandGreen.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.leading, 32)
                    }
                }
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

struct SearchResultCard: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.source.icon)
                    .font(.caption2)
                    .foregroundStyle(result.source == .email ? .blue : .orange)
                Text(result.title)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Text(result.snippet)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(3)

            if let date = result.date {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TypingIndicator: View {
    @State private var animationOffset = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(y: animationOffset == index ? -4 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                animationOffset = 2
            }
        }
    }
}

// MARK: - Assistant Settings

struct AssistantSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var webSearchEnabled: Bool
    @Binding var llmEnabled: Bool
    @Binding var localAIEnabled: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $webSearchEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.title2)
                                .foregroundStyle(.cyan)
                                .frame(width: 32)
                            VStack(alignment: .leading) {
                                Text("Web Research")
                                    .font(.subheadline.bold())
                                Text("Search the web via Tavily")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(brandGreen)

                    Toggle(isOn: $llmEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "cpu")
                                .font(.title2)
                                .foregroundStyle(.purple)
                                .frame(width: 32)
                            VStack(alignment: .leading) {
                                Text("AI Processing")
                                    .font(.subheadline.bold())
                                Text("Use OpenRouter LLM")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(brandGreen)

                    Toggle(isOn: $localAIEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "book.fill")
                                .font(.title2)
                                .foregroundStyle(brandGreen)
                                .frame(width: 32)
                            VStack(alignment: .leading) {
                                Text("Local Knowledge")
                                    .font(.subheadline.bold())
                                Text("Builder standards & app help")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .tint(brandGreen)
                } header: {
                    Text("Features")
                } footer: {
                    Text("Enable at least one feature for the assistant to work.")
                }

                Section {
                    HStack {
                        Text("Web Search")
                        Spacer()
                        Text("Tavily API")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("AI Model")
                        Spacer()
                        Text("Llama 3.1 8B")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Local Knowledge")
                        Spacer()
                        Text("5 Builders")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Current Configuration")
                }
            }
            .navigationTitle("Assistant Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(brandGreen)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    AssistantChatView()
}
