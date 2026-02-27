//
//  AddExpenseView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var category: ExpenseCategory = .gas
    @State private var amount: String = ""
    @State private var merchant: String = ""
    @State private var notes: String = ""
    @State private var date = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var receiptImage: UIImage?
    @State private var showingCamera = false
    @State private var isProcessingReceipt = false
    @State private var scannedData: ReceiptScanner.ReceiptData?
    @FocusState private var isInputActive: Bool

    var isValid: Bool {
        guard let amountValue = Double(amount), amountValue > 0 else {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Expense Details") {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }

                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                    }

                    TextField("Merchant (e.g., Shell, Home Depot)", text: $merchant)
                        .focused($isInputActive)

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Receipt Photo") {
                    if isProcessingReceipt {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing receipt...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Removing background and scanning text")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let image = receiptImage {
                        VStack(spacing: 12) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .cornerRadius(8)

                            if let scanned = scannedData {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Receipt Scanned")
                                            .font(.subheadline.bold())
                                    }

                                    if scanned.amount != nil || scanned.merchant != nil || scanned.date != nil {
                                        Text("Auto-filled: \([scanned.amount != nil ? "Amount" : nil, scanned.merchant != nil ? "Merchant" : nil, scanned.date != nil ? "Date" : nil].compactMap { $0 }.joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }

                            Button("Remove Photo") {
                                receiptImage = nil
                                selectedPhoto = nil
                                scannedData = nil
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                showingCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Text("We'll automatically scan the receipt and fill in the details")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputActive = false
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!isValid)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await processReceipt(image)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { image in
                    Task {
                        await processReceipt(image)
                    }
                }
            }
        }
    }

    private func processReceipt(_ image: UIImage) async {
        await MainActor.run {
            isProcessingReceipt = true
            receiptImage = image
        }

        print("📸 Processing receipt...")

        // Run enhanced OCR parser for category guessing
        let ocrResult = await ReceiptOCRParser.parseReceipt(image: image)

        // Also run existing scanner for compatibility
        let scannedData = await ReceiptScanner.scanReceipt(image)

        await MainActor.run {
            self.scannedData = scannedData

            // Use OCR parser results with fallback to existing scanner
            let finalAmount = ocrResult.totalAmount ?? scannedData.amount
            let finalMerchant = ocrResult.vendorName ?? scannedData.merchant
            let finalDate = ocrResult.date ?? scannedData.date

            if let amt = finalAmount, amount.isEmpty {
                amount = String(format: "%.2f", amt)
                print("✓ Auto-filled amount: $\(amt)")
            }

            if let merch = finalMerchant, merchant.isEmpty {
                merchant = merch
                print("✓ Auto-filled merchant: \(merch)")
            }

            if let d = finalDate {
                date = d
                print("✓ Auto-filled date: \(d)")
            }

            // Auto-fill category based on vendor
            if let suggestedCategory = ocrResult.suggestedCategory,
               let cat = ExpenseCategory(rawValue: suggestedCategory) {
                category = cat
                print("✓ Auto-filled category: \(suggestedCategory)")
            }

            HapticManager.success()
            isProcessingReceipt = false
            print("✅ Receipt processing complete")
        }
    }

    private func saveExpense() {
        guard let amountValue = Double(amount) else {
            print("❌ Invalid amount: \(amount)")
            return
        }

        var imageData: Data?
        if let image = receiptImage {
            // Compress image to reduce storage size
            imageData = image.jpegData(compressionQuality: 0.7)
            print("📸 Receipt image size: \(imageData?.count ?? 0) bytes")
        }

        let expense = Expense(
            date: date,
            category: category.rawValue,
            amount: amountValue,
            merchant: merchant,
            notes: notes,
            receiptImageData: imageData,
            ownerEmail: GmailAuthManager.shared.userEmail,
            ownerName: Settings.shared.workerName
        )

        modelContext.insert(expense)

        do {
            try modelContext.save()
            HapticManager.light()
            print("✅ Expense saved: \(category.rawValue) - $\(amountValue) on \(date)")
            if imageData != nil {
                print("   📸 With receipt image attached")
            }
        } catch {
            HapticManager.error()
            print("❌ Failed to save expense: \(error)")
        }

        dismiss()
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage) -> Void

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
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
