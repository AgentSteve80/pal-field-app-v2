//
//  EmailDetailView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct EmailDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]

    let email: EmailMessage
    @State private var parsedData: ParsedJobData
    @State private var isCreatingJob = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateJob: Job?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var scannedAddress: String?
    @State private var isScanningImages = false

    // On-Site photo states
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var isSendingOnsite = false
    @State private var onsiteSent = false
    @State private var showingOnsiteOverride = false

    // Onsite photo path (saved for job thumbnail)
    @State private var savedOnsitePhotoPath: String?

    // Post-creation states
    @State private var createdJob: Job?
    @State private var showingNextActionSheet = false
    @State private var showingCloseout = false

    private let gmailService = GmailService()

    // Key for storing onsite sent status
    private var onsiteSentKey: String {
        "onsiteSent_\(email.id)"
    }

    init(email: EmailMessage) {
        self.email = email
        // Parse email on initialization - will be updated after OCR
        var parsed = EmailParser.parse(subject: email.subject, bodyText: email.bodyText)
        // Store Gmail threading info for closeout email replies
        parsed.sourceEmailThreadId = email.threadId
        parsed.sourceEmailMessageId = email.rfc2822MessageId
        _parsedData = State(initialValue: parsed)
    }

    private var calculatedTotal: Double {
        let tempJob = parsedData.toJob(settings: settings)
        return tempJob.total(settings: settings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                emailHeaderSection
                addressSection
                imageGallerySection
                emailBodySection
                jobInformationForm
                createJobButton
                validationMessage
            }
            .padding(.vertical)
        }
        .navigationTitle("Review Job")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                onsiteButton
            }
        }
        .confirmationDialog("Send On-Site Email", isPresented: $showingPhotoOptions) {
            Button("Take Photos") {
                showingCamera = true
            }
            Button("Select from Library") {
                showingPhotoPicker = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose 1-2 photos to verify you're at the job site")
        }
        .sheet(isPresented: $showingCamera) {
            OnsiteCameraView(images: $capturedImages) {
                if !capturedImages.isEmpty {
                    sendOnsiteEmail()
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 2, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                await loadSelectedPhotos(newItems)
                if !capturedImages.isEmpty {
                    sendOnsiteEmail()
                }
            }
        }
        .alert("Duplicate Job Found", isPresented: $showingDuplicateAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Create Anyway") {
                saveJob()
            }
        } message: {
            if let duplicate = duplicateJob {
                Text("A job for Lot \(duplicate.lotNumber) on \(duplicate.jobDate.formatted(date: .abbreviated, time: .omitted)) already exists. Create this job anyway?")
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .alert("Override Onsite", isPresented: $showingOnsiteOverride) {
            Button("Yes") {
                onsiteSent = true
                UserDefaults.standard.set(true, forKey: onsiteSentKey)
            }
            Button("No") {
                showingPhotoOptions = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you sent Onsite Pictures?")
        }
        .confirmationDialog("Job Created!", isPresented: $showingNextActionSheet, titleVisibility: .visible) {
            Button("Submit Closeout") {
                showingCloseout = true
            }
            Button("Go to All Jobs") {
                NotificationCenter.default.post(name: .navigateToAllJobs, object: nil)
                dismiss()
            }
            Button("Go to Messages") {
                dismiss()
            }
        } message: {
            Text("What would you like to do next?")
        }
        .sheet(isPresented: $showingCloseout, onDismiss: {
            dismiss()
        }) {
            if let job = createdJob {
                CloseoutView(job: job)
            }
        }
        .onAppear {
            if parsedData.jobNumber.isEmpty {
                parsedData.jobNumber = Job.generateNextJobNumber(existingJobs: allJobs)
            }
            // Check if onsite was already sent for this email
            onsiteSent = UserDefaults.standard.bool(forKey: onsiteSentKey)
        }
        .task {
            await scanAttachmentsForAddress()
        }
    }
    
    // MARK: - View Components
    
    private var emailHeaderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(email.subject)
                .font(.title3.bold())

            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue)
                Text(email.from)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.green)
                Text(email.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("•")
                    .foregroundStyle(.secondary)
                Text(email.date, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var addressSection: some View {
        if let address = scannedAddress, !address.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.headline)
                    .padding(.horizontal)

                Button {
                    openInMaps(address: address)
                } label: {
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.blue)
                        Text(address)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
        } else if isScanningImages {
            HStack {
                ProgressView()
                Text("Scanning images for address...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var imageGallerySection: some View {
        if !email.attachments.isEmpty {
            EmailImageGallery(attachments: email.attachments)
        }
    }
    
    @ViewBuilder
    private var emailBodySection: some View {
        if !email.bodyText.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Content")
                    .font(.headline)
                    .padding(.horizontal)

                Text(email.bodyText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
    }
    
    private var jobInformationForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Job Information")
                    .font(.headline)
                Spacer()
                if !onsiteSent {
                    Button {
                        showingOnsiteOverride = true
                    } label: {
                        Text("Send Onsite first")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .underline()
                    }
                }
            }
            .padding(.horizontal)

            Form {
                basicInfoSection
                wireEquipmentSection
                additionalSection
                totalSection
            }
            .frame(height: 600)
            .disabled(!onsiteSent)
            .opacity(onsiteSent ? 1.0 : 0.5)
        }
    }
    
    private var basicInfoSection: some View {
        Section("Basic Info") {
            HStack {
                Text("Job #")
                Spacer()
                TextField("Job Number", text: $parsedData.jobNumber)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Lot #")
                Spacer()
                TextField("Lot Number", text: $parsedData.lotNumber)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Address")
                Spacer()
                TextField("Address", text: $parsedData.address)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Subdivision")
                Spacer()
                TextField("Subdivision", text: $parsedData.subdivision)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Prospect")
                Spacer()
                TextField("Prospect", text: $parsedData.prospect)
                    .multilineTextAlignment(.trailing)
            }

            DatePicker("Job Date", selection: $parsedData.jobDate, displayedComponents: .date)
        }
    }
    
    private var wireEquipmentSection: some View {
        Section("Wire & Equipment") {
            Stepper("Wire Runs: \(parsedData.wireRuns)", value: $parsedData.wireRuns, in: 0...50)
            Stepper("Enclosure: \(parsedData.enclosure)", value: $parsedData.enclosure, in: 0...10)
            Stepper("FTDM: \(parsedData.flexTube)", value: $parsedData.flexTube, in: 0...5)
            Stepper("Flat Panel Stud: \(parsedData.flatPanelStud)", value: $parsedData.flatPanelStud, in: 0...10)
            Stepper("Flat Panel Wall: \(parsedData.flatPanelWall)", value: $parsedData.flatPanelWall, in: 0...10)
            Stepper("Flat Panel Remote: \(parsedData.flatPanelRemote)", value: $parsedData.flatPanelRemote, in: 0...10)
            Stepper("Media Box: \(parsedData.mediaBox)", value: $parsedData.mediaBox, in: 0...5)
        }
    }
    
    private var additionalSection: some View {
        Section("Additional") {
            Stepper("Dry Run: \(parsedData.dryRun)", value: $parsedData.dryRun, in: 0...3)
            Stepper("Service Run: \(parsedData.serviceRun)", value: $parsedData.serviceRun, in: 0...10)

            HStack {
                Text("Miles")
                Spacer()
                TextField("Miles", value: $parsedData.miles, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
            }
        }
    }
    
    private var totalSection: some View {
        Section("Total") {
            HStack {
                Text("Calculated Total")
                    .font(.headline)
                Spacer()
                Text("$\(calculatedTotal, specifier: "%.2f")")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            }
        }
    }
    
    private var createJobButton: some View {
        Button {
            createJob()
        } label: {
            if isCreatingJob {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Label("Create Job", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!onsiteSent || !parsedData.isValid || isCreatingJob)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var validationMessage: some View {
        if !onsiteSent {
            Text("You must send an Onsite email before creating a job")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal)
        } else if !parsedData.isValid {
            Text("Lot number is required to create a job")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal)
        }
    }
    
    private var onsiteButton: some View {
        Button {
            showingPhotoOptions = true
        } label: {
            if isSendingOnsite {
                ProgressView()
            } else if onsiteSent {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Sent")
                }
                .foregroundStyle(.green)
                .fontWeight(.semibold)
            } else {
                Text("Onsite")
                    .fontWeight(.semibold)
            }
        }
        .disabled(isSendingOnsite || onsiteSent)
    }

    // MARK: - OCR Scanning

    private func scanAttachmentsForAddress() async {
        // Only scan images
        let imageAttachments = email.attachments.filter { $0.isImage && $0.localURL != nil }

        guard !imageAttachments.isEmpty else { return }

        // Check if this is a Guardian job (attachment filenames contain "guardian")
        let isGuardianJob = email.attachments.contains { attachment in
            attachment.filename.lowercased().contains("guardian")
        }

        if isGuardianJob {
            print("🛡️ Guardian job detected - will use subject line prospect")
        }

        await MainActor.run {
            isScanningImages = true
        }

        var foundAddress: String?
        var foundAccountNumber: String?

        // Try to find address and account# in images
        for attachment in imageAttachments {
            guard let url = attachment.localURL else { continue }

            // Scan for address
            if foundAddress == nil {
                if let address = await ImageTextScanner.extractAddress(from: url) {
                    foundAddress = address
                    print("✅ Found address in image: \(address)")
                }
            }

            // Scan for Account# (only for non-Guardian jobs)
            if !isGuardianJob && foundAccountNumber == nil {
                if let accountNum = await ImageTextScanner.extractAccountNumber(from: url) {
                    foundAccountNumber = accountNum
                    print("✅ Found Account# in image: \(accountNum)")
                }
            }

            // If we found what we need, we can stop
            if foundAddress != nil && (isGuardianJob || foundAccountNumber != nil) {
                break
            }
        }

        await MainActor.run {
            if let address = foundAddress {
                scannedAddress = address
            }

            isScanningImages = false

            // Re-parse with the scanned data
            // For Guardian jobs, don't pass the OCR account number - use subject line prospect
            parsedData = EmailParser.parse(
                subject: email.subject,
                bodyText: email.bodyText,
                scannedAddress: foundAddress,
                scannedAccountNumber: isGuardianJob ? nil : foundAccountNumber
            )

            // Set the next job number
            parsedData.jobNumber = Job.generateNextJobNumber(existingJobs: allJobs)

            print("📱 UI Updated - Prospect now: \(parsedData.prospect)")
        }
    }

    private func openInMaps(address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?address=\(encodedAddress)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Job Creation

    private func createJob() {
        isCreatingJob = true

        // Check for duplicates
        let fetchDescriptor = FetchDescriptor<Job>()

        do {
            let existingJobs = try modelContext.fetch(fetchDescriptor)

            // Check if a job with same lot# and date exists
            let calendar = Calendar.current
            let jobDayStart = calendar.startOfDay(for: parsedData.jobDate)

            if let duplicate = existingJobs.first(where: { job in
                let existingDayStart = calendar.startOfDay(for: job.jobDate)
                return job.lotNumber == parsedData.lotNumber && existingDayStart == jobDayStart
            }) {
                duplicateJob = duplicate
                showingDuplicateAlert = true
                isCreatingJob = false
                return
            }

            // No duplicate, save directly
            saveJob()

        } catch {
            errorMessage = "Error checking for duplicates: \(error.localizedDescription)"
            showingError = true
            isCreatingJob = false
        }
    }

    private func saveJob() {
        let job = parsedData.toJob(settings: settings)

        // Attach onsite photo (saved when onsite email was sent)
        if let photoPath = savedOnsitePhotoPath ?? UserDefaults.standard.string(forKey: "onsitePhoto_\(email.id)") {
            job.onsitePhotoPath = photoPath
        }

        modelContext.insert(job)

        // If miles were entered, also create a MileageTrip for tax records
        if parsedData.miles > 0 {
            let mileageTrip = MileageTrip(
                startDate: parsedData.jobDate,
                endDate: parsedData.jobDate,
                miles: parsedData.miles,
                purpose: "Work",
                notes: "Job \(parsedData.jobNumber) - \(parsedData.address)",
                ownerEmail: GmailAuthManager.shared.userEmail,
                ownerName: Settings.shared.workerName
            )
            modelContext.insert(mileageTrip)
            print("📍 Mileage trip created: \(parsedData.miles) miles for Job \(parsedData.jobNumber)")
        }

        do {
            try modelContext.save()

            // Cleanup temp attachments
            AttachmentManager.shared.cleanupEmailAttachments(emailId: email.id)

            print("✅ Job created: \(job.jobNumber)")

            // Store the created job and show next action dialog
            createdJob = job
            isCreatingJob = false
            showingNextActionSheet = true
        } catch {
            errorMessage = "Error saving job: \(error.localizedDescription)"
            showingError = true
            isCreatingJob = false
        }
    }

    // MARK: - Photo Storage

    /// Save onsite photo to Documents directory, return path
    static func saveOnsitePhoto(_ image: UIImage?) -> String? {
        guard let image = image,
              let data = image.jpegData(compressionQuality: 0.6) else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OnsitePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        let url = dir.appendingPathComponent(filename)
        try? data.write(to: url)
        return url.path
    }

    // MARK: - On-Site Email

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        capturedImages = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    capturedImages.append(image)
                }
            }
        }
    }

    private func sendOnsiteEmail() {
        isSendingOnsite = true

        Task {
            do {
                // Convert images to JPEG data
                let imageData = capturedImages.compactMap { image in
                    image.jpegData(compressionQuality: 0.7)
                }

                // Send the reply
                try await gmailService.sendReply(
                    to: email,
                    body: "Onsite",
                    images: imageData
                )

                // Save first photo as job thumbnail
                let photoPath = Self.saveOnsitePhoto(capturedImages.first)

                await MainActor.run {
                    isSendingOnsite = false
                    savedOnsitePhotoPath = photoPath
                    capturedImages = []
                    selectedPhotoItems = []
                    onsiteSent = true
                    // Persist the sent status
                    UserDefaults.standard.set(true, forKey: onsiteSentKey)
                    if let photoPath {
                        UserDefaults.standard.set(photoPath, forKey: "onsitePhoto_\(email.id)")
                    }
                    print("✅ On-site email sent with \(imageData.count) photos")
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to send on-site email: \(error.localizedDescription)"
                    showingError = true
                    isSendingOnsite = false
                }
            }
        }
    }
}

// MARK: - Onsite Camera View

struct OnsiteCameraView: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    @Environment(\.dismiss) private var dismiss
    var onComplete: () -> Void

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
        let parent: OnsiteCameraView
        var captureCount = 0

        init(_ parent: OnsiteCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.images.append(image)
                captureCount += 1
            }

            // Allow up to 2 photos
            if captureCount < 2 {
                // Reset picker for another photo
                // Note: This is a simple approach - user can cancel to finish early
            } else {
                picker.dismiss(animated: true) {
                    self.parent.onComplete()
                }
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // If they took at least one photo, send it
            if !parent.images.isEmpty {
                parent.onComplete()
            }
            parent.dismiss()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToAllJobs = Notification.Name("navigateToAllJobs")
}
