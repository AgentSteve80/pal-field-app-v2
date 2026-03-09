//
//  EditJobView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 11/13/25.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import WidgetKit
import PhotosUI

struct EditJobView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings

    let job: Job

    // MARK: - Job Info State
    @State private var jobNumber: String
    @State private var jobDate: Date
    @State private var lotNumber: String
    @State private var address: String
    @State private var subdivision: String
    @State private var prospect: String
    @State private var wireRuns: Int
    @State private var enclosure: Int
    @State private var flatPanelStud: Int
    @State private var flatPanelWall: Int
    @State private var flatPanelRemote: Int
    @State private var flexTube: Int
    @State private var mediaBox: Int
    @State private var dryRun: Int
    @State private var serviceRun: Int
    @State private var miles: Double
    private let originalMiles: Double
    @State private var calculatingMiles = false
    @State private var showGeocodeQuery = false
    @State private var geocodeQuery: String
    @State private var showDeleteAlert = false
    @State private var showingCloseoutEmail = false
    @State private var voiceNotePath: String?
    @State private var superNotes: String  // Voice note transcription → job.superNotes

    // MARK: - Closeout State
    @State private var closeoutPayNumber: String = ""
    @State private var completionPercentage: Int = 100
    @State private var doorbellType: String = "18/2"
    @State private var hasWhip: Bool = true
    @State private var tradesOnsite: String = ""
    @State private var closeoutJobNotes: String = ""   // → job.wapUpstairs
    @State private var palNotes: String = ""           // → job.wapDownstairs
    @State private var notCompleted: String = ""
    @State private var parts: [CloseoutPart] = []

    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var closeoutImages: [UIImage] = []
    @State private var showingCamera = false

    // Preview / Send
    @State private var isSending = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingPreview = false
    @State private var previewSubject = ""
    @State private var previewBody = ""

    // Add Part sheet
    @State private var showingAddPart = false
    @State private var newPartName = ""
    @State private var newPartQty = "1"

    // Email Link sheet
    @State private var showingEmailPicker = false
    @State private var availableEmails: [EmailMessage] = []
    @State private var isLoadingEmails = false
    @State private var emailLoadError: String?

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    // MARK: - Computed

    var liveTotal: Double {
        let tempJob = Job(
            wireRuns: wireRuns,
            enclosure: enclosure,
            flatPanelStud: flatPanelStud,
            flatPanelWall: flatPanelWall,
            flatPanelRemote: flatPanelRemote,
            flexTube: flexTube,
            mediaBox: mediaBox,
            dryRun: dryRun,
            serviceRun: serviceRun,
            miles: miles,
            payTierValue: settings.payTier.rawValue
        )
        return tempJob.total(settings: settings)
    }

    /// Recent parts with saved quantities — returns [(name, qty, frequency)]
    private var recentPartsWithQty: [(name: String, qty: String, freq: Int)] {
        let freqDict = UserDefaults.standard.dictionary(forKey: "closeoutPartsFrequency") as? [String: Int] ?? [:]
        let qtyDict = UserDefaults.standard.dictionary(forKey: "closeoutPartsLastQty") as? [String: String] ?? [:]
        return freqDict.sorted { $0.value > $1.value }.map { (name: $0.key, qty: qtyDict[$0.key] ?? "1", freq: $0.value) }
    }

    // MARK: - Init

    init(job: Job) {
        self.job = job
        self.originalMiles = job.miles
        _jobNumber = State(initialValue: job.jobNumber)
        _jobDate = State(initialValue: job.jobDate)
        _lotNumber = State(initialValue: job.lotNumber)
        _address = State(initialValue: job.address)
        _subdivision = State(initialValue: job.subdivision)
        _prospect = State(initialValue: job.prospect)
        _wireRuns = State(initialValue: job.wireRuns)
        _enclosure = State(initialValue: job.enclosure)
        _flatPanelStud = State(initialValue: job.flatPanelStud)
        _flatPanelWall = State(initialValue: job.flatPanelWall)
        _flatPanelRemote = State(initialValue: job.flatPanelRemote)
        _flexTube = State(initialValue: job.flexTube)
        _mediaBox = State(initialValue: job.mediaBox)
        _dryRun = State(initialValue: job.dryRun)
        _serviceRun = State(initialValue: job.serviceRun)
        _miles = State(initialValue: job.miles)
        _geocodeQuery = State(initialValue: job.address + " subdivision, north Indianapolis, IN")
        _voiceNotePath = State(initialValue: job.voiceNotePath)
        _superNotes = State(initialValue: job.superNotes)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                pricingSection
                voiceNoteSection
                mileageSection
                emailThreadSection
                closeoutCompletionSection
                closeoutSiteNotesSection
                closeoutPartsSection
                closeoutPhotosSection
                closeoutStatusSection
                totalSection
                sendCloseoutSection
            }
            .navigationTitle("Edit Job")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveJob() }
                        .disabled(lotNumber.isEmpty)
                }
            }
            .onAppear {
                loadCloseoutFromJob()
            }
            .onChange(of: address) { _, newValue in
                geocodeQuery = newValue + " subdivision, north Indianapolis, IN"
            }
            .onChange(of: selectedPhotos) { _, newItems in
                loadSelectedPhotos(newItems)
            }
            .alert("Delete Job", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteJob() }
            } message: {
                Text("Are you sure you want to delete job #\(jobNumber)? This action cannot be undone.")
            }
            .sheet(isPresented: $showingCloseoutEmail) {
                CloseoutEmailViewer(job: job)
            }
            .sheet(isPresented: $showingCamera) {
                CloseoutCameraView(images: $closeoutImages)
            }
            .sheet(isPresented: $showingAddPart) {
                addPartSheet
            }
            .sheet(isPresented: $showingEmailPicker) {
                emailPickerSheet
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

    // MARK: - Form Sections

    private var basicsSection: some View {
        Section("Basics") {
            HStack {
                Text("Job #")
                Spacer()
                TextField("JB001", text: $jobNumber)
                    .multilineTextAlignment(.trailing)
            }
            DatePicker("Job Date", selection: $jobDate, displayedComponents: .date)
            HStack {
                Text("Lot #")
                Spacer()
                TextField("123", text: $lotNumber)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Address")
                Spacer()
                TextField("123 Main St", text: $address)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Subdivision")
                Spacer()
                TextField("Courtyards Russell", text: $subdivision)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Prospect #")
                Spacer()
                TextField("52260357", text: $prospect)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var pricingSection: some View {
        Section("Pricing Items (Tier \(settings.payTier.rawValue))") {
            Stepper("Wire Runs (\(settings.priceForWireRun(), specifier: "$%.0f") ea): \(wireRuns)", value: $wireRuns, in: 0...50)
            Stepper("Enclosure (\(settings.priceForEnclosure(), specifier: "$%.0f") ea): \(enclosure)", value: $enclosure, in: 0...10)
            Stepper("Flex Tube (\(settings.priceForFlexTube(), specifier: "$%.0f") ea): \(flexTube)", value: $flexTube, in: 0...5)
            Stepper("Flat Panel Same Stud (\(settings.priceForFlatPanelStud(), specifier: "$%.0f") ea): \(flatPanelStud)", value: $flatPanelStud, in: 0...10)
            Stepper("Flat Panel Same Wall (\(settings.priceForFlatPanelWall(), specifier: "$%.0f") ea): \(flatPanelWall)", value: $flatPanelWall, in: 0...10)
            Stepper("Remote (\(settings.priceForFlatPanelRemote(), specifier: "$%.0f") ea): \(flatPanelRemote)", value: $flatPanelRemote, in: 0...10)
            Stepper("Media Box (\(settings.priceForMediaBox(), specifier: "$%.0f") ea): \(mediaBox)", value: $mediaBox, in: 0...5)
            Stepper("Dry Run (\(settings.priceForDryRun(), specifier: "$%.0f")): \(dryRun)", value: $dryRun, in: 0...3)
            Stepper("Service Run 30min (\(settings.priceForServiceRun(), specifier: "$%.0f")): \(serviceRun)", value: $serviceRun, in: 0...10)
        }
    }

    private var voiceNoteSection: some View {
        Section("Voice Note") {
            VoiceNoteView(voiceNotePath: $voiceNotePath, notes: $superNotes)
            if !superNotes.isEmpty {
                Text(superNotes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mileageSection: some View {
        Section("Mileage (For Tax Purposes)") {
            HStack {
                Text("Miles (one-way):")
                Spacer()
                Text("\(miles, specifier: "%.1f")")
                    .foregroundStyle(.secondary)
            }
            if showGeocodeQuery {
                Text("Could not locate address. Refine the search query below:")
                    .foregroundStyle(.red)
                    .font(.caption)
                TextField("Geocode Search Query", text: $geocodeQuery)
            }
            Button("Calculate from Address") {
                calculatingMiles = true
                Task {
                    await calculateMiles()
                    calculatingMiles = false
                }
            }
            .disabled(calculatingMiles || address.isEmpty)
            if calculatingMiles {
                ProgressView("Calculating...")
            }
        }
    }

    // MARK: - Email Thread Section

    private var emailThreadSection: some View {
        Section {
            if let threadId = job.sourceEmailThreadId, !threadId.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "link.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Linked ✅")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let subject = job.sourceEmailSubject, !subject.isEmpty {
                            Text(subject)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Thread ID: \(threadId.prefix(16))...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("Unlink Email Thread") {
                    job.sourceEmailThreadId = nil
                    job.sourceEmailMessageId = nil
                    job.sourceEmailSubject = nil
                }
                .foregroundStyle(.red)
            } else {
                HStack {
                    Image(systemName: "link.badge.plus")
                        .foregroundStyle(.secondary)
                    Button("Link to Email") {
                        showingEmailPicker = true
                        Task { await fetchEmailsForPicker() }
                    }
                }
                Text("Link this job to its original email so closeout replies land in the same Gmail thread.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Email Thread")
        } footer: {
            if job.sourceEmailThreadId == nil {
                Text("Without a linked email, closeouts send as a new email instead of a reply.")
            }
        }
    }

    // MARK: - Closeout: Completion Details

    private var closeoutCompletionSection: some View {
        Section {
            DisclosureGroup {
                HStack {
                    Text("Pay Number")
                    Spacer()
                    TextField("PLV013", text: $closeoutPayNumber)
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

                if completionPercentage <= 99 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Not Completed")
                            .foregroundStyle(.red)
                        TextField("List what didn't get finished...", text: $notCompleted, axis: .vertical)
                            .lineLimit(2...5)
                    }
                }
            } label: {
                HStack {
                    Text("Completion Details")
                    Spacer()
                    Text("\(completionPercentage)%")
                        .font(.caption)
                        .foregroundStyle(completionPercentage == 100 ? .green : .orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            (completionPercentage == 100 ? Color.green : Color.orange).opacity(0.15)
                        )
                        .clipShape(Capsule())
                }
            }
        } header: {
            Text("Closeout")
        }
    }

    // MARK: - Closeout: Site Notes

    private var closeoutSiteNotesSection: some View {
        Section {
            DisclosureGroup("Site Notes") {
                HStack {
                    Text("Trades Onsite")
                    Spacer()
                    TextField("framers, electricians", text: $tradesOnsite)
                        .multilineTextAlignment(.trailing)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Job Notes")
                    TextField("Notes about the job...", text: $closeoutJobNotes, axis: .vertical)
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
    }

    // MARK: - Closeout: Parts Used

    private var closeoutPartsSection: some View {
        Section {
            DisclosureGroup("Parts Used (\(parts.count))") {
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

                if !parts.isEmpty {
                    Text("Swipe left to remove a part")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Closeout: Photos

    private var closeoutPhotosSection: some View {
        Section {
            DisclosureGroup("Photos (\(closeoutImages.count))") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
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

                if !closeoutImages.isEmpty {
                    Text("Add photos of your completed work. Photos are scaled to 1600px max.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Closeout Status (when complete)

    @ViewBuilder
    private var closeoutStatusSection: some View {
        if job.isCloseoutComplete {
            Section("Closeout Status") {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Completed")
                    Spacer()
                    if let date = job.closeoutDate {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if job.closeoutEmailBody != nil {
                    Button {
                        showingCloseoutEmail = true
                    } label: {
                        Label("View Closeout Email", systemImage: "envelope.fill")
                    }
                }
            }
        }
    }

    // MARK: - Total Section

    private var totalSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("JOB TOTAL")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(liveTotal, specifier: "%.2f")")
                        .font(.title.bold())
                        .foregroundStyle(.green)
                }
                Spacer()
            }
        }
    }

    // MARK: - Send Closeout Section

    private var sendCloseoutSection: some View {
        Section {
            Button {
                buildEmailContent()
                showingPreview = true
            } label: {
                HStack {
                    Spacer()
                    Label(
                        job.isCloseoutComplete ? "Re-send Closeout Email" : "Preview Closeout Email",
                        systemImage: "envelope.badge.fill"
                    )
                    .fontWeight(.semibold)
                    .foregroundStyle(brandGreen)
                    Spacer()
                }
            }
            .disabled(isSending)
        } footer: {
            if job.sourceEmailThreadId == nil {
                Text("⚠️ No email linked — closeout will send as a new email, not as a reply.")
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Add Part Sheet

    private var addPartSheet: some View {
        NavigationStack {
            Form {
                if !recentPartsWithQty.isEmpty {
                    Section("Recent Parts") {
                        ForEach(recentPartsWithQty.prefix(12), id: \.name) { part in
                            Button {
                                addPart(part.name, qty: part.qty)
                                showingAddPart = false
                            } label: {
                                HStack {
                                    Text(part.qty)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(brandGreen)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Text(part.name)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(brandGreen)
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

    // MARK: - Email Picker Sheet

    private var emailPickerSheet: some View {
        NavigationStack {
            Group {
                if isLoadingEmails {
                    VStack(spacing: 20) {
                        ProgressView("Loading recent emails…")
                        Text("Fetching from Gmail")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errMsg = emailLoadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("Could not load emails")
                            .font(.headline)
                        Text(errMsg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await fetchEmailsForPicker() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmailListView(emails: availableEmails) { selectedEmail in
                        job.sourceEmailThreadId = selectedEmail.threadId
                        job.sourceEmailMessageId = selectedEmail.rfc2822MessageId
                        job.sourceEmailSubject = selectedEmail.subject
                        showingEmailPicker = false
                    }
                }
            }
            .navigationTitle("Link to Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingEmailPicker = false }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveJob() {
        job.jobNumber = jobNumber
        job.jobDate = jobDate
        job.lotNumber = lotNumber
        job.address = address
        job.subdivision = subdivision
        job.prospect = prospect
        job.wireRuns = wireRuns
        job.enclosure = enclosure
        job.flatPanelStud = flatPanelStud
        job.flatPanelWall = flatPanelWall
        job.flatPanelRemote = flatPanelRemote
        job.flexTube = flexTube
        job.mediaBox = mediaBox
        job.dryRun = dryRun
        job.serviceRun = serviceRun
        job.miles = miles
        job.payTierValue = settings.payTier.rawValue
        job.voiceNotePath = voiceNotePath
        job.superNotes = superNotes
        job.updatedAt = Date()
        job.syncStatusRaw = 1

        if miles > originalMiles && originalMiles == 0 {
            let mileageTrip = MileageTrip(
                startDate: jobDate,
                endDate: jobDate,
                miles: miles,
                purpose: "Work",
                notes: "Job \(jobNumber) - \(address)",
                ownerEmail: GmailAuthManager.shared.userEmail,
                ownerName: settings.workerName
            )
            modelContext.insert(mileageTrip)
            print("📍 Mileage trip created: \(miles) miles for Job \(jobNumber)")
        }

        do {
            try modelContext.save()
            HapticManager.success()
            NotificationCenter.default.post(name: .jobDataDidChange, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                dismiss()
            }
        } catch {
            HapticManager.error()
            print("Failed to save job: \(error)")
        }
    }

    private func deleteJob() {
        HapticManager.warning()
        modelContext.delete(job)
        dismiss()
    }

    private func loadCloseoutFromJob() {
        closeoutPayNumber = settings.payNumber
        completionPercentage = job.completionPercentage
        doorbellType = job.doorbellType
        hasWhip = job.hasWhip
        tradesOnsite = job.tradesOnsite
        closeoutJobNotes = job.wapUpstairs
        palNotes = job.wapDownstairs
        // superNotes already initialized from job.superNotes in init()
        notCompleted = job.notCompleted
        parts = job.closeoutParts
    }

    private func addPart(_ name: String, qty: String = "1") {
        let part = CloseoutPart(name: name, quantity: qty)
        parts.append(part)
        trackPartUsage(name, qty: qty)
    }

    private func trackPartUsage(_ name: String, qty: String) {
        var freqDict = UserDefaults.standard.dictionary(forKey: "closeoutPartsFrequency") as? [String: Int] ?? [:]
        freqDict[name, default: 0] += 1
        UserDefaults.standard.set(freqDict, forKey: "closeoutPartsFrequency")

        // Also save the last-used quantity for this part
        var qtyDict = UserDefaults.standard.dictionary(forKey: "closeoutPartsLastQty") as? [String: String] ?? [:]
        qtyDict[name] = qty
        UserDefaults.standard.set(qtyDict, forKey: "closeoutPartsLastQty")
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    let fixedImage = image.fixedOrientation()
                    await MainActor.run {
                        closeoutImages.append(fixedImage)
                    }
                    if let coord = PhotoLocationReporter.shared.extractGPS(from: data) {
                        let token = UserDefaults.standard.string(forKey: "convexAuthToken")
                        PhotoLocationReporter.shared.reportLocation(
                            lat: coord.latitude,
                            lng: coord.longitude,
                            jobId: nil,
                            token: token
                        )
                    }
                }
            }
            await MainActor.run {
                selectedPhotos = []
            }
        }
    }

    private func fetchEmailsForPicker() async {
        await MainActor.run {
            isLoadingEmails = true
            emailLoadError = nil
            availableEmails = []
        }
        do {
            let emails = try await GmailService().fetchRecentMessages(daysBack: 30, maxResults: 50)
            await MainActor.run {
                availableEmails = emails
                isLoadingEmails = false
            }
        } catch {
            await MainActor.run {
                emailLoadError = error.localizedDescription
                isLoadingEmails = false
            }
        }
    }

    private func buildEmailContent() {
        let whipStatus = hasWhip ? "whip" : "no whip"

        var body = """
        \(job.lotNumber) \(job.subdivision)
        \(job.prospect)
        \(job.builderCompany.isEmpty ? "Builder" : job.builderCompany) pw

        \(closeoutPayNumber), \(completionPercentage)% completed, db \(doorbellType), \(whipStatus)\(tradesOnsite.isEmpty ? "" : ", \(tradesOnsite) onsite")
        """

        if !closeoutJobNotes.isEmpty {
            body += "\n\(closeoutJobNotes)"
        }

        if !palNotes.isEmpty {
            body += "\nPAL Notes: \(palNotes)"
        }

        if !superNotes.isEmpty {
            body += "\nSuper Noted: \(superNotes)"
        }

        if !notCompleted.isEmpty {
            body += "\nNot Completed: \(notCompleted)"
        }

        body += "\n\nParts\n"
        for part in parts {
            body += "\(part.quantity) \(part.name)\n"
        }

        body += "\nBilling\n"
        if job.enclosure > 0    { body += "Enclosure-\(job.enclosure)\n" }
        if job.flexTube > 0     { body += "Ftdm-\(job.flexTube)\n" }
        if job.wireRuns > 0     { body += "Wires-\(job.wireRuns)\n" }
        if job.flatPanelStud > 0  { body += "Ssfpp-\(job.flatPanelStud)\n" }
        if job.flatPanelWall > 0  { body += "Swfpp-\(job.flatPanelWall)\n" }
        if job.flatPanelRemote > 0 { body += "Rfpp-\(job.flatPanelRemote)\n" }

        // Use original email subject for proper Gmail threading
        if let originalSubject = job.sourceEmailSubject, !originalSubject.isEmpty {
            previewSubject = originalSubject.hasPrefix("Re:") ? originalSubject : "Re: \(originalSubject)"
        } else {
            previewSubject = "Re: (P) \(job.lotNumber) \(job.subdivision) \(job.prospect)"
        }
        previewBody = body
    }

    private func saveCloseoutToJob() {
        job.completionPercentage = completionPercentage
        job.doorbellType = doorbellType
        job.hasWhip = hasWhip
        job.tradesOnsite = tradesOnsite
        job.wapUpstairs = closeoutJobNotes
        job.wapDownstairs = palNotes
        job.superNotes = superNotes
        job.notCompleted = notCompleted
        job.closeoutParts = parts
        job.isCloseoutComplete = true
        job.closeoutDate = Date()
        job.updatedAt = Date()
        job.syncStatusRaw = 1
        try? modelContext.save()
    }

    private func sendCloseout() {
        isSending = true

        if previewSubject.isEmpty { buildEmailContent() }

        // Debug: log threading info
        print("📧 Closeout threading debug:")
        print("  threadId: \(job.sourceEmailThreadId ?? "nil")")
        print("  messageId: \(job.sourceEmailMessageId ?? "nil")")
        print("  sourceSubject: \(job.sourceEmailSubject ?? "nil")")
        print("  previewSubject: \(previewSubject)")

        Task {
            do {
                let photoPaths = CloseoutView.saveCloseoutPhotos(closeoutImages, jobId: job.id)

                try await GmailService().sendCloseoutEmail(
                    subject: previewSubject,
                    body: previewBody,
                    images: closeoutImages,
                    threadId: job.sourceEmailThreadId,
                    inReplyTo: job.sourceEmailMessageId
                )

                await MainActor.run {
                    saveCloseoutToJob()
                    job.closeoutEmailSubject = previewSubject
                    job.closeoutEmailBody = previewBody
                    job.closeoutPhotoPaths = photoPaths

                    // Auto-create Return Job if completion <= 99%
                    if completionPercentage <= 99 && !notCompleted.isEmpty {
                        let returnJob = Job()
                        returnJob.jobNumber = "RT-\(job.jobNumber)"
                        returnJob.jobDate = Date()
                        returnJob.lotNumber = job.lotNumber
                        returnJob.address = job.address
                        returnJob.subdivision = job.subdivision
                        returnJob.prospect = job.prospect
                        returnJob.builderCompany = job.builderCompany
                        returnJob.ownerEmail = job.ownerEmail
                        returnJob.ownerName = job.ownerName
                        returnJob.isReturnJob = true
                        returnJob.returnJobStatus = "pending"
                        returnJob.parentJobId = job.id.uuidString
                        returnJob.notCompleted = notCompleted
                        returnJob.completionPercentage = completionPercentage
                        // Copy threading info so return completion can reply to same thread
                        returnJob.sourceEmailThreadId = job.sourceEmailThreadId
                        returnJob.sourceEmailMessageId = job.sourceEmailMessageId
                        returnJob.sourceEmailSubject = job.sourceEmailSubject
                        modelContext.insert(returnJob)
                    }

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

    private func calculateMiles() async {
        let home = settings.homeAddress
        let destination = geocodeQuery

        func mapItem(for address: String) async throws -> MKMapItem? {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = address
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.first
        }

        do {
            guard let homeMapItem = try await mapItem(for: home) else { return }
            guard let destMapItem = try await mapItem(for: destination) else { throw NSError(domain: "Geocode", code: 1) }

            let request = MKDirections.Request()
            request.source = homeMapItem
            request.destination = destMapItem
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            guard let route = response.routes.first else { return }

            let distanceMiles = route.distance / 1609.34
            miles = round(distanceMiles * 100) / 100
            showGeocodeQuery = false
        } catch {
            print("Miles calculation error: \(error.localizedDescription)")
            showGeocodeQuery = true
        }
    }
}
