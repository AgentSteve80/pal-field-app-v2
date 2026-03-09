//
//  ReturnJobsView.swift
//  Pal Field
//
//  Return Jobs tracking — jobs that need a return visit to complete.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ReturnJobsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @Query(filter: #Predicate<Job> { $0.isReturnJob == true },
           sort: \Job.jobDate, order: .reverse) private var returnJobs: [Job]
    @ObservedObject private var gmailAuth = GmailAuthManager.shared

    private var currentUserEmail: String {
        gmailAuth.userEmail.lowercased()
    }

    private var myReturnJobs: [Job] {
        returnJobs.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var pendingJobs: [Job] {
        myReturnJobs.filter { $0.returnJobStatus == "pending" }
    }

    private var completedJobs: [Job] {
        myReturnJobs.filter { $0.returnJobStatus == "completed" }
    }

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        List {
            if pendingJobs.isEmpty && completedJobs.isEmpty {
                ContentUnavailableView {
                    Label("No Return Jobs", systemImage: "checkmark.circle.fill")
                } description: {
                    Text("All jobs are fully completed. Return jobs appear here when a closeout has less than 100% completion.")
                }
            }

            if !pendingJobs.isEmpty {
                Section {
                    ForEach(pendingJobs) { job in
                        NavigationLink {
                            ReturnJobDetailView(job: job)
                        } label: {
                            ReturnJobRow(job: job)
                        }
                    }
                } header: {
                    HStack {
                        Text("Needs Return")
                        Spacer()
                        Text("\(pendingJobs.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                }
            }

            if !completedJobs.isEmpty {
                Section("Completed Returns") {
                    ForEach(completedJobs) { job in
                        NavigationLink {
                            ReturnJobDetailView(job: job)
                        } label: {
                            ReturnJobRow(job: job)
                        }
                    }
                }
            }
        }
        .navigationTitle("Return Jobs")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Return Job Row

struct ReturnJobRow: View {
    let job: Job
    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(job.jobNumber)
                    .font(.headline)
                Spacer()
                if job.returnJobStatus == "completed" {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(brandGreen)
                } else {
                    Label("Pending", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if !job.address.isEmpty {
                Text(job.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if !job.subdivision.isEmpty {
                    Text(job.subdivision)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !job.builderCompany.isEmpty {
                    Text("• \(job.builderCompany)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !job.notCompleted.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(job.notCompleted)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                .padding(.top, 2)
            }

            Text(job.jobDate, style: .date)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Return Job Detail View

struct ReturnJobDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var job: Job

    @State private var completionNotes: String = ""
    @State private var completionPhotos: [UIImage] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var isSending = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        List {
            // Job Info Section
            Section("Job Information") {
                LabeledContent("Job #", value: job.jobNumber)
                if !job.address.isEmpty {
                    LabeledContent("Address", value: job.address)
                }
                if !job.subdivision.isEmpty {
                    LabeledContent("Subdivision", value: job.subdivision)
                }
                if !job.builderCompany.isEmpty {
                    LabeledContent("Builder", value: job.builderCompany)
                }
                if !job.lotNumber.isEmpty {
                    LabeledContent("Lot #", value: job.lotNumber)
                }
                LabeledContent("Original Completion", value: "\(job.completionPercentage)%")
            }

            // What Needs to be Done
            Section {
                Text(job.notCompleted)
                    .foregroundStyle(.red)
            } header: {
                Label("Not Completed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }

            if job.returnJobStatus == "pending" {
                // Completion Section
                Section("Complete Return Job") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completion Notes")
                        TextField("Describe what was completed...", text: $completionNotes, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    // Photos
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Completion Photos")
                            Spacer()
                            Text("\(completionPhotos.count) photos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            Button {
                                showingCamera = true
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("Camera")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 70)
                                .background(Color.blue.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            PhotosPicker(selection: $selectedPhotoItems,
                                        maxSelectionCount: 10,
                                        matching: .images) {
                                VStack(spacing: 4) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                    Text("Library")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 70)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        if !completionPhotos.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(completionPhotos.indices, id: \.self) { index in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: completionPhotos[index])
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 80, height: 80)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                            Button {
                                                completionPhotos.remove(at: index)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(.white, .red)
                                            }
                                            .offset(x: 4, y: -4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Complete Button
                Section {
                    Button {
                        completeReturnJob()
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isSending ? "Sending..." : "Mark Completed")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .listRowBackground(
                        (completionPhotos.isEmpty || completionNotes.isEmpty) ?
                        Color.gray : brandGreen
                    )
                    .disabled(completionPhotos.isEmpty || completionNotes.isEmpty || isSending)
                }

                if completionPhotos.isEmpty || completionNotes.isEmpty {
                    Section {
                        Label("Photos and notes are required to complete", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Already completed
                Section("Completion Details") {
                    if !job.returnCompletionNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(job.returnCompletionNotes)
                        }
                    }
                    if let date = job.returnCompletionDate {
                        LabeledContent("Completed", value: date, format: .dateTime)
                    }
                    if !job.returnCompletionPhotoPaths.isEmpty {
                        Text("\(job.returnCompletionPhotoPaths.count) photos attached")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(job.jobNumber)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCamera) {
            ReturnJobCameraView(images: $completionPhotos)
        }
        .onChange(of: selectedPhotoItems) { _, items in
            loadSelectedPhotos(items)
        }
        .alert("Return Job Completed!", isPresented: $showingSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Completion email has been sent and the return job is marked as done.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        completionPhotos.append(image)
                    }
                }
            }
        }
    }

    private func completeReturnJob() {
        isSending = true

        Task {
            do {
                // Scale photos
                let maxDimension: CGFloat = 1600
                let imageData: [Data] = completionPhotos.compactMap { image in
                    var img = image
                    let maxSide = max(img.size.width, img.size.height)
                    if maxSide > maxDimension {
                        let scale = maxDimension / maxSide
                        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
                        let renderer = UIGraphicsImageRenderer(size: newSize)
                        img = renderer.image { _ in
                            img.draw(in: CGRect(origin: .zero, size: newSize))
                        }
                    }
                    return img.jpegData(compressionQuality: 0.6)
                }

                // Send email reply to original thread
                if let threadId = job.sourceEmailThreadId,
                   let messageId = job.sourceEmailMessageId {

                    let subject: String
                    if let originalSubject = job.sourceEmailSubject, !originalSubject.isEmpty {
                        subject = originalSubject.hasPrefix("Re:") ? originalSubject : "Re: \(originalSubject)"
                    } else {
                        subject = "Re: Return Complete - \(job.lotNumber) \(job.subdivision)"
                    }

                    let body = """
                    Return Job Completed

                    \(job.lotNumber) \(job.subdivision)
                    \(job.address)
                    \(job.builderCompany)

                    Previously Not Completed:
                    \(job.notCompleted)

                    Completion Notes:
                    \(completionNotes)
                    """

                    try await GmailService().sendCloseoutEmail(
                        subject: subject,
                        body: body,
                        images: completionPhotos,
                        threadId: threadId,
                        inReplyTo: messageId
                    )
                }

                // Save completion photos to disk
                let photoPaths = saveCompletionPhotos()

                await MainActor.run {
                    job.returnJobStatus = "completed"
                    job.returnCompletionNotes = completionNotes
                    job.returnCompletionDate = Date()
                    job.returnCompletionPhotoPaths = photoPaths
                    job.updatedAt = Date()
                    job.syncStatusRaw = 1
                    try? modelContext.save()

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

    private func saveCompletionPhotos() -> [String] {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("ReturnPhotos")
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var paths: [String] = []
        for (i, image) in completionPhotos.enumerated() {
            let filename = "\(job.id.uuidString)_return_\(i).jpg"
            let url = dir.appendingPathComponent(filename)
            if let data = image.jpegData(compressionQuality: 0.7) {
                try? data.write(to: url)
                paths.append(url.path)
            }
        }
        return paths
    }
}

// MARK: - Camera for Return Jobs

struct ReturnJobCameraView: UIViewControllerRepresentable {
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
        let parent: ReturnJobCameraView

        init(_ parent: ReturnJobCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let fixedImage = image.fixedOrientation()
                parent.images.append(fixedImage)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - UIImage Orientation Fix

extension UIImage {
    /// Normalize image orientation — fixes photos taken in landscape/portrait appearing rotated
    /// Applies the correct CGAffineTransform based on EXIF orientation, then renders upright
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        guard let cgImage = self.cgImage else { return self }

        var transform = CGAffineTransform.identity
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)

        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0).rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height).rotated(by: -.pi / 2)
        default: break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0).scaledBy(x: -1, y: 1)
        default: break
        }

        let isRotated = imageOrientation == .left || imageOrientation == .leftMirrored ||
                         imageOrientation == .right || imageOrientation == .rightMirrored
        let canvasSize = isRotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height)

        guard let colorSpace = cgImage.colorSpace,
              let ctx = CGContext(data: nil, width: Int(canvasSize.width), height: Int(canvasSize.height),
                                 bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0,
                                 space: colorSpace, bitmapInfo: cgImage.bitmapInfo.rawValue) else {
            // Fallback: use renderer
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
        }

        ctx.concatenate(transform)
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let newCGImage = ctx.makeImage() else { return self }
        return UIImage(cgImage: newCGImage, scale: scale, orientation: .up)
    }
}
