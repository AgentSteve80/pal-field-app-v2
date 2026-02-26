//
//  EmailImageGallery.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/13/25.
//

import SwiftUI
import PDFKit

struct EmailImageGallery: View {
    let attachments: [EmailAttachment]

    var viewableAttachments: [EmailAttachment] {
        attachments.filter { $0.isViewable && $0.localURL != nil }
    }

    var body: some View {
        if !viewableAttachments.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Attachments (\(viewableAttachments.count))")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewableAttachments) { attachment in
                            if let url = attachment.localURL {
                                if attachment.isPDF {
                                    PDFThumbnailView(url: url, filename: attachment.filename)
                                } else if attachment.isImage {
                                    ImageThumbnailView(url: url, filename: attachment.filename)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 180)
            }
        }
    }
}

// MARK: - Image Thumbnail View

struct ImageThumbnailView: View {
    let url: URL
    let filename: String
    @State private var showingFullScreen = false

    var body: some View {
        VStack(spacing: 4) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 150, height: 150)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(8)
                        .onTapGesture {
                            showingFullScreen = true
                        }
                case .failure:
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.gray)
                        .frame(width: 150, height: 150)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                @unknown default:
                    EmptyView()
                }
            }

            Text(filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 150)
        }
        .sheet(isPresented: $showingFullScreen) {
            FullScreenImageView(url: url, filename: filename)
        }
    }
}

// MARK: - PDF Thumbnail View

struct PDFThumbnailView: View {
    let url: URL
    let filename: String
    @State private var thumbnail: UIImage?
    @State private var showingFullScreen = false

    var body: some View {
        VStack(spacing: 4) {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 150)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(4),
                        alignment: .topTrailing
                    )
                    .onTapGesture {
                        showingFullScreen = true
                    }
            } else {
                ProgressView()
                    .frame(width: 150, height: 150)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            Text(filename)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 150)
        }
        .task {
            loadPDFThumbnail()
        }
        .sheet(isPresented: $showingFullScreen) {
            FullScreenPDFView(url: url, filename: filename)
        }
    }

    private func loadPDFThumbnail() {
        guard let pdfDocument = PDFDocument(url: url),
              let page = pdfDocument.page(at: 0) else {
            return
        }

        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)

        thumbnail = renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
    }
}

// MARK: - Full Screen Image View

struct FullScreenImageView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let filename: String

    var body: some View {
        NavigationStack {
            ZoomableImageView(url: url)
                .navigationTitle(filename)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Zoomable Image View

struct ZoomableImageView: View {
    let url: URL
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                    // Limit scale
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                        }
                                    } else if scale > 5.0 {
                                        withAnimation {
                                            scale = 5.0
                                            lastScale = 5.0
                                        }
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                } placeholder: {
                    ProgressView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

// MARK: - Full Screen PDF View

struct FullScreenPDFView: View {
    @Environment(\.dismiss) private var dismiss
    let url: URL
    let filename: String

    var body: some View {
        NavigationStack {
            if let pdfDocument = PDFDocument(url: url) {
                PDFKitRepresentableView(document: pdfDocument)
                    .navigationTitle(filename)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
            } else {
                Text("Unable to load PDF")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - PDFKit View Wrapper

struct PDFKitRepresentableView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
