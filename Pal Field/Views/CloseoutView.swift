//
//  CloseoutView.swift
//  Pal Field
//
//  Closeout form for documenting completed jobs
//

import SwiftUI
import SwiftData
import PhotosUI

struct CloseoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings

    @Bindable var job: Job

    // Form state
    @State private var payNumber: String = ""
    @State private var completionPercentage: Int = 100
    @State private var doorbellType: String = "18/2"
    @State private var hasWhip: Bool = true
    @State private var tradesOnsite: String = ""
    @State private var jobNotes: String = ""
    @State private var palNotes: String = ""
    @State private var superNotes: String = ""
    @State private var parts: [CloseoutPart] = []

    // Photo state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var closeoutImages: [UIImage] = []
    @State private var showingCamera = false

    // Sending state
    @State private var isSending = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingPreview = false
    @State private var previewSubject = ""
    @State private var previewBody = ""

    // Add part sheet
    @State private var showingAddPart = false
    @State private var newPartName = ""
    @State private var newPartQty = "1"

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            Form {
                jobInfoSection
                completionSection
                siteNotesSection
                partsSection
                billingSection
                photosSection
            }
            .navigationTitle("Closeout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Preview") {
                        buildEmailContent()
                        showingPreview = true
                    }
                    .disabled(isSending)
                }
            }
            .onAppear {
                loadFromJob()
            }
            .onChange(of: selectedPhotos) { _, newItems in
                loadSelectedPhotos(newItems)
            }
            .sheet(isPresented: $showingAddPart) {
                addPartSheet
            }
            .sheet(isPresented: $showingCamera) {
                CloseoutCameraView(images: $closeoutImages)
            }
            .sheet(isPresented: $showingPreview) {
                CloseoutPreviewView(
                    subject: previewSubject,
                    emailBody: previewBody,
                    images: closeoutImages,
                    isSending: $isSending,
                    onSend: { sendCloseout() },
                    onEdit: { showingPreview = false }
                )
            }
            .alert("Closeout Sent", isPresented: $showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your closeout has been sent to scheduling.")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Sections

    private var jobInfoSection: some View {
        Section("Job Info") {
            LabeledContent("Lot") {
                Text("\(job.lotNumber) \(job.subdivision)")
            }
            LabeledContent("Prospect") {
                Text(job.prospect)
            }
            LabeledContent("Builder") {
                Text(job.builderCompany.isEmpty ? "Unknown" : "\(job.builderCompany) pw")
            }
            LabeledContent("Address") {
                Text(job.address)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var completionSection: some View {
        Section("Completion Details") {
            HStack {
                Text("Pay Number")
                Spacer()
                TextField("PLV013", text: $payNumber)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.characters)
                    .frame(width: 100)
            }

            Stepper("Completion: \(completionPercentage)%", value: $completionPercentage, in: 0...100, step: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text("Door Bell Wire Type")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Door Bell", selection: $doorbellType) {
                    Text("18/2").tag("18/2")
                    Text("cat5e").tag("cat5e")
                    Text("Not Ran").tag("not ran")
                }
                .pickerStyle(.segmented)
            }

            Toggle("Electrical Whip", isOn: $hasWhip)
        }
    }

    private var siteNotesSection: some View {
        Section("Site Notes") {
            HStack {
                Text("Trades Onsite")
                Spacer()
                TextField("framers, electricians", text: $tradesOnsite)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Job Notes")
                TextField("Notes about the job...", text: $jobNotes, axis: .vertical)
                    .lineLimit(2...4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("PAL Notes")
                TextField("Notes for PAL scheduling...", text: $palNotes, axis: .vertical)
                    .lineLimit(2...4)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Super Notes")
                TextField("Super approved onQ location...", text: $superNotes, axis: .vertical)
                    .lineLimit(2...4)
            }
        }
    }

    private var partsSection: some View {
        Section {
            ForEach(parts) { part in
                HStack {
                    Text("\(part.quantity)x")
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Text(part.name)
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        parts.removeAll { $0.id == part.id }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                showingAddPart = true
            } label: {
                Label("Add Part", systemImage: "plus.circle.fill")
            }
        } header: {
            Text("Parts Used")
        } footer: {
            Text("Swipe left to remove a part")
        }
    }

    private var billingSection: some View {
        Section("Billing Summary") {
            if job.enclosure > 0 {
                LabeledContent("Enclosure") { Text("\(job.enclosure)") }
            }
            if job.flexTube > 0 {
                LabeledContent("FTDM") { Text("\(job.flexTube)") }
            }
            if job.wireRuns > 0 {
                LabeledContent("Wires") { Text("\(job.wireRuns)") }
            }
            if job.flatPanelStud > 0 {
                LabeledContent("SSFPP") { Text("\(job.flatPanelStud)") }
            }
            if job.flatPanelWall > 0 {
                LabeledContent("SWFPP") { Text("\(job.flatPanelWall)") }
            }
            if job.flatPanelRemote > 0 {
                LabeledContent("RFPP") { Text("\(job.flatPanelRemote)") }
            }
            if job.mediaBox > 0 {
                LabeledContent("Mediabox") { Text("\(job.mediaBox)") }
            }
        }
    }

    private var photosSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Camera button
                    Button {
                        showingCamera = true
                    } label: {
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                            Text("Camera")
                                .font(.caption2)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Photo picker
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                            Text("Gallery")
                                .font(.caption2)
                        }
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    // Display selected photos
                    ForEach(Array(closeoutImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button {
                                closeoutImages.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.white, .red)
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            HStack {
                Text("Photos")
                Spacer()
                Text("\(closeoutImages.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            Text("Add photos of your completed work")
        }
    }

    /// Recently used parts sorted by frequency
    private var recentParts: [String] {
        let dict = UserDefaults.standard.dictionary(forKey: "closeoutPartsFrequency") as? [String: Int] ?? [:]
        return dict.sorted { $0.value > $1.value }.map { $0.key }
    }

    private func trackPartUsage(_ name: String) {
        var dict = UserDefaults.standard.dictionary(forKey: "closeoutPartsFrequency") as? [String: Int] ?? [:]
        dict[name, default: 0] += 1
        UserDefaults.standard.set(dict, forKey: "closeoutPartsFrequency")
    }

    private func addPart(_ name: String, qty: String = "1") {
        let part = CloseoutPart(name: name, quantity: qty)
        parts.append(part)
        trackPartUsage(name)
    }

    private var addPartSheet: some View {
        NavigationStack {
            Form {
                // Quick-pick from recent parts
                if !recentParts.isEmpty {
                    Section("Recent Parts") {
                        let columns = [GridItem(.adaptive(minimum: 100))]
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(recentParts.prefix(12), id: \.self) { partName in
                                Button {
                                    addPart(partName)
                                    showingAddPart = false
                                } label: {
                                    Text(partName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity)
                                        .background(brandGreen.opacity(0.15))
                                        .foregroundStyle(brandGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }

                Section("Custom Part") {
                    TextField("Part Name", text: $newPartName)
                        .textInputAutocapitalization(.characters)

                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", text: $newPartQty)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }
            }
            .navigationTitle("Add Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newPartName = ""
                        newPartQty = "1"
                        showingAddPart = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if !newPartName.isEmpty {
                            addPart(newPartName, qty: newPartQty.isEmpty ? "1" : newPartQty)
                        }
                        newPartName = ""
                        newPartQty = "1"
                        showingAddPart = false
                    }
                    .disabled(newPartName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func loadFromJob() {
        payNumber = settings.payNumber
        completionPercentage = job.completionPercentage
        doorbellType = job.doorbellType
        hasWhip = job.hasWhip
        tradesOnsite = job.tradesOnsite
        jobNotes = job.wapUpstairs  // Repurpose wapUpstairs as jobNotes
        palNotes = job.wapDownstairs  // Repurpose wapDownstairs as palNotes
        superNotes = job.superNotes
        parts = job.closeoutParts
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        closeoutImages.append(image)
                    }
                }
            }
            await MainActor.run {
                selectedPhotos = []
            }
        }
    }

    private func saveToJob() {
        job.completionPercentage = completionPercentage
        job.doorbellType = doorbellType
        job.hasWhip = hasWhip
        job.tradesOnsite = tradesOnsite
        job.wapUpstairs = jobNotes  // Store jobNotes in wapUpstairs field
        job.wapDownstairs = palNotes  // Store palNotes in wapDownstairs field
        job.superNotes = superNotes
        job.closeoutParts = parts
        job.isCloseoutComplete = true
        job.closeoutDate = Date()
        job.updatedAt = Date()
        job.syncStatusRaw = 1  // Mark for re-sync

        try? modelContext.save()
    }

    private func buildEmailContent() {
        let whipStatus = hasWhip ? "whip" : "no whip"

        var body = """
        \(job.lotNumber) \(job.subdivision)
        \(job.prospect)
        \(job.builderCompany.isEmpty ? "Builder" : job.builderCompany) pw

        \(payNumber), \(completionPercentage)% completed, db \(doorbellType), \(whipStatus)\(tradesOnsite.isEmpty ? "" : ", \(tradesOnsite) onsite")
        """

        if !jobNotes.isEmpty {
            body += "\n\(jobNotes)"
        }

        if !palNotes.isEmpty {
            body += "\nPAL Notes: \(palNotes)"
        }

        if !superNotes.isEmpty {
            body += "\nSuper Noted: \(superNotes)"
        }

        body += "\n\nParts\n"
        for part in parts {
            body += "\(part.quantity) \(part.name)\n"
        }

        body += "\nBilling\n"
        if job.enclosure > 0 { body += "Enclosure-\(job.enclosure)\n" }
        if job.flexTube > 0 { body += "Ftdm-\(job.flexTube)\n" }
        if job.wireRuns > 0 { body += "Wires-\(job.wireRuns)\n" }
        if job.flatPanelStud > 0 { body += "Ssfpp-\(job.flatPanelStud)\n" }
        if job.flatPanelWall > 0 { body += "Swfpp-\(job.flatPanelWall)\n" }
        if job.flatPanelRemote > 0 { body += "Rfpp-\(job.flatPanelRemote)\n" }

        previewSubject = "Re: (P) \(job.lotNumber) \(job.subdivision) \(job.prospect)"
        previewBody = body
    }

    private func sendCloseout() {
        isSending = true

        // Ensure email content is built
        if previewSubject.isEmpty { buildEmailContent() }

        Task {
            do {
                // Save closeout photos to disk
                let photoPaths = Self.saveCloseoutPhotos(closeoutImages, jobId: job.id)

                try await GmailService().sendCloseoutEmail(
                    subject: previewSubject,
                    body: previewBody,
                    images: closeoutImages,
                    threadId: job.sourceEmailThreadId,
                    inReplyTo: job.sourceEmailMessageId
                )

                await MainActor.run {
                    // Save closeout data to job
                    saveToJob()
                    job.closeoutEmailSubject = previewSubject
                    job.closeoutEmailBody = previewBody
                    job.closeoutPhotoPaths = photoPaths
                    try? modelContext.save()

                    isSending = false
                    showingPreview = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    /// Save closeout photos to Documents/CloseoutPhotos/<jobId>/
    static func saveCloseoutPhotos(_ images: [UIImage], jobId: UUID) -> [String] {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloseoutPhotos", isDirectory: true)
            .appendingPathComponent(jobId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var paths: [String] = []
        for (index, image) in images.enumerated() {
            guard let data = image.jpegData(compressionQuality: 0.7) else { continue }
            let url = dir.appendingPathComponent("photo_\(index).jpg")
            try? data.write(to: url)
            paths.append(url.path)
        }
        return paths
    }
}

// MARK: - Closeout Email Preview

struct CloseoutPreviewView: View {
    let subject: String
    let emailBody: String
    let images: [UIImage]
    @Binding var isSending: Bool
    var onSend: () -> Void
    var onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Subject
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subject")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(subject)
                            .font(.headline)
                    }
                    .padding(.horizontal)

                    Divider()

                    // Body
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(emailBody)
                            .font(.body)
                            .monospaced()
                    }
                    .padding(.horizontal)

                    // Photos
                    if !images.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attachments (\(images.count) photos)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Preview Closeout Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Edit") { onEdit() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSend()
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isSending)
                }
            }
        }
    }
}

// MARK: - Camera View for Closeout

struct CloseoutCameraView: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CloseoutCameraView

        init(_ parent: CloseoutCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.images.append(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
