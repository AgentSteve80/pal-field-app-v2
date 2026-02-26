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
                    Button("Send") {
                        sendCloseout()
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

    private var addPartSheet: some View {
        NavigationStack {
            Form {
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
                            parts.append(CloseoutPart(name: newPartName, quantity: newPartQty.isEmpty ? "1" : newPartQty))
                        }
                        newPartName = ""
                        newPartQty = "1"
                        showingAddPart = false
                    }
                    .disabled(newPartName.isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
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

        try? modelContext.save()
    }

    private func sendCloseout() {
        isSending = true

        // Build email content
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
            body += "\nPAL: \(palNotes)"
        }

        if !superNotes.isEmpty {
            body += "\n\(superNotes)"
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

        let subject = "Re: (P) \(job.lotNumber) \(job.subdivision) \(job.prospect)"

        Task {
            do {
                try await GmailService().sendCloseoutEmail(
                    subject: subject,
                    body: body,
                    images: closeoutImages
                )

                await MainActor.run {
                    saveToJob()
                    isSending = false
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
