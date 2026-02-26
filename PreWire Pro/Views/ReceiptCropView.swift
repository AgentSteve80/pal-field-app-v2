//
//  ReceiptCropView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import Vision

struct ReceiptCropView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let onCrop: (UIImage) -> Void

    @State private var detectedRect: VNRectangleObservation?
    @State private var isDetecting = true
    @State private var cropRect: CGRect = .zero
    @State private var imageSize: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .ignoresSafeArea()

                    // Display the image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            GeometryReader { imageGeometry in
                                Color.clear
                                    .onAppear {
                                        imageSize = imageGeometry.size
                                        updateCropRect(in: imageGeometry.size)
                                    }
                                    .onChange(of: detectedRect) { oldValue, newValue in
                                        updateCropRect(in: imageGeometry.size)
                                    }
                            }
                        )

                    // Crop overlay
                    if !isDetecting && imageSize != .zero {
                        CropOverlay(rect: $cropRect, imageSize: imageSize)
                    }

                    // Loading indicator
                    if isDetecting {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Detecting receipt...")
                                .foregroundStyle(.white)
                                .padding(.top)
                        }
                    }
                }
            }
            .navigationTitle("Crop Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        // Use original image without cropping
                        onCrop(image)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Crop") {
                        cropAndSave()
                    }
                    .disabled(isDetecting)
                }
            }
            .task {
                await detectReceipt()
            }
        }
    }

    private func detectReceipt() async {
        guard let cgImage = image.cgImage else {
            isDetecting = false
            // Set default crop to full image
            cropRect = CGRect(origin: .zero, size: imageSize)
            return
        }

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.1
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.05
        request.minimumConfidence = 0.3
        request.maximumObservations = 5

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            if let observations = request.results {
                // Find best rectangle
                var bestObservation: VNRectangleObservation?
                var bestArea: CGFloat = 0

                for observation in observations {
                    let area = observation.boundingBox.width * observation.boundingBox.height
                    if area > 0.1 && area < 0.95 && area > bestArea {
                        bestArea = area
                        bestObservation = observation
                    }
                }

                await MainActor.run {
                    detectedRect = bestObservation
                    isDetecting = false
                }
            }
        } catch {
            print("Detection error: \(error)")
            await MainActor.run {
                isDetecting = false
            }
        }
    }

    private func updateCropRect(in displaySize: CGSize) {
        guard let rect = detectedRect else {
            // Default to full image
            cropRect = CGRect(origin: .zero, size: displaySize)
            return
        }

        // Convert normalized coordinates to display coordinates
        let x = rect.boundingBox.minX * displaySize.width
        let y = (1 - rect.boundingBox.maxY) * displaySize.height
        let width = rect.boundingBox.width * displaySize.width
        let height = rect.boundingBox.height * displaySize.height

        cropRect = CGRect(x: x, y: y, width: width, height: height)
    }

    private func cropAndSave() {
        guard let cgImage = image.cgImage else {
            onCrop(image)
            dismiss()
            return
        }

        // Calculate crop rect in original image coordinates
        let scale = CGFloat(cgImage.width) / imageSize.width
        let scaledRect = CGRect(
            x: cropRect.minX * scale,
            y: cropRect.minY * scale,
            width: cropRect.width * scale,
            height: cropRect.height * scale
        )

        // Crop the image
        if let croppedCGImage = cgImage.cropping(to: scaledRect) {
            let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            onCrop(croppedImage)
        } else {
            onCrop(image)
        }

        dismiss()
    }
}

// MARK: - Crop Overlay

struct CropOverlay: View {
    @Binding var rect: CGRect
    let imageSize: CGSize
    @State private var initialRect: CGRect = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed areas outside crop
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .mask(
                        Rectangle()
                            .overlay(
                                Rectangle()
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                                    .blendMode(.destinationOut)
                            )
                    )

                // Crop border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Corner handles
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(Color.white)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 30, height: 30)
                        .position(cornerPosition(index))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if initialRect == .zero {
                                        initialRect = rect
                                    }
                                    updateCorner(index, dragValue: value)
                                }
                                .onEnded { _ in
                                    initialRect = .zero
                                }
                        )
                }
            }
        }
    }

    private func cornerPosition(_ index: Int) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: rect.minX, y: rect.minY) // Top-left
        case 1: return CGPoint(x: rect.maxX, y: rect.minY) // Top-right
        case 2: return CGPoint(x: rect.minX, y: rect.maxY) // Bottom-left
        case 3: return CGPoint(x: rect.maxX, y: rect.maxY) // Bottom-right
        default: return .zero
        }
    }

    private func updateCorner(_ index: Int, dragValue: DragGesture.Value) {
        let minSize: CGFloat = 50
        let initial = initialRect == .zero ? rect : initialRect
        var newRect = rect

        switch index {
        case 0: // Top-left
            let newX = min(initial.maxX - minSize, max(0, initial.minX + dragValue.translation.width))
            let newY = min(initial.maxY - minSize, max(0, initial.minY + dragValue.translation.height))
            newRect = CGRect(
                x: newX,
                y: newY,
                width: initial.maxX - newX,
                height: initial.maxY - newY
            )
        case 1: // Top-right
            let newMaxX = max(initial.minX + minSize, min(imageSize.width, initial.maxX + dragValue.translation.width))
            let newY = min(initial.maxY - minSize, max(0, initial.minY + dragValue.translation.height))
            newRect = CGRect(
                x: initial.minX,
                y: newY,
                width: newMaxX - initial.minX,
                height: initial.maxY - newY
            )
        case 2: // Bottom-left
            let newX = min(initial.maxX - minSize, max(0, initial.minX + dragValue.translation.width))
            let newMaxY = max(initial.minY + minSize, min(imageSize.height, initial.maxY + dragValue.translation.height))
            newRect = CGRect(
                x: newX,
                y: initial.minY,
                width: initial.maxX - newX,
                height: newMaxY - initial.minY
            )
        case 3: // Bottom-right
            let newMaxX = max(initial.minX + minSize, min(imageSize.width, initial.maxX + dragValue.translation.width))
            let newMaxY = max(initial.minY + minSize, min(imageSize.height, initial.maxY + dragValue.translation.height))
            newRect = CGRect(
                x: initial.minX,
                y: initial.minY,
                width: newMaxX - initial.minX,
                height: newMaxY - initial.minY
            )
        default:
            break
        }

        rect = newRect
    }
}
