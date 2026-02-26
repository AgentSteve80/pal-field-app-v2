//
//  InventoryView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData
import UIKit

struct InventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \InventoryItem.createdAt) private var allDbItems: [InventoryItem]
    @State private var selectedSupplier: SupplyCompany = .sns
    @State private var showingAddSheet = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var allItems: [InventoryItem] {
        allDbItems.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var supplierItems: [InventoryItem] {
        allItems.filter { $0.supplier == selectedSupplier.rawValue }
    }

    // Group items by category
    private var itemsByCategory: [String: [InventoryItem]] {
        Dictionary(grouping: supplierItems) { $0.category }
    }

    // Available categories for current supplier
    private var availableCategories: [InventoryCategory] {
        InventoryCategory.categories(for: selectedSupplier)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Supplier Picker
                Picker("Supplier", selection: $selectedSupplier) {
                    ForEach(SupplyCompany.allCases) { supplier in
                        Text(supplier.rawValue).tag(supplier)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if supplierItems.isEmpty {
                    ContentUnavailableView(
                        "No Inventory",
                        systemImage: "shippingbox",
                        description: Text("Tap + to add your first item")
                    )
                } else {
                    inventoryList
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        generatePDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(allItems.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddInventoryItemSheet(
                    supplier: selectedSupplier,
                    existingItems: supplierItems
                )
            }
            .fullScreenCover(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private var inventoryList: some View {
        List {
            ForEach(availableCategories) { category in
                let categoryItems = (itemsByCategory[category.rawValue] ?? [])
                    .sorted { $0.itemNumber < $1.itemNumber }

                if !categoryItems.isEmpty {
                    Section {
                        ForEach(categoryItems, id: \.persistentModelID) { item in
                            InventoryItemRow(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }

                        // Add more button for this category
                        Button {
                            addItem(to: category)
                        } label: {
                            Label("Add \(category.usesFeet ? "Spool" : "Item")", systemImage: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    } header: {
                        Text(category.displayName)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }

    private func addItem(to category: InventoryCategory) {
        let categoryItems = itemsByCategory[category.rawValue] ?? []
        let nextNumber = (categoryItems.map { $0.itemNumber }.max() ?? 0) + 1

        let newItem = InventoryItem(
            supplier: selectedSupplier.rawValue,
            category: category.rawValue,
            itemNumber: nextNumber
        )

        // Set owner info from current user
        newItem.ownerEmail = GmailAuthManager.shared.userEmail
        newItem.ownerName = Settings.shared.workerName

        modelContext.insert(newItem)
        try? modelContext.save()
    }

    private func deleteItem(_ item: InventoryItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func generatePDF() {
        // Export ALL inventory items (both suppliers)
        let pdfData = InventoryPDFGenerator.generatePDF(items: allItems)

        let fileName = "Inventory_\(Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: tempURL)
            exportURL = tempURL
            // Small delay to ensure file is ready before presenting share sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showingExportSheet = true
            }
        } catch {
            print("Error saving PDF: \(error)")
        }
    }
}

// MARK: - Inventory Item Row

struct InventoryItemRow: View {
    @Bindable var item: InventoryItem
    @Environment(\.modelContext) private var modelContext
    @State private var valueText: String = ""
    @State private var notesText: String = ""
    @State private var hasAppeared = false
    @FocusState private var isValueFocused: Bool
    @FocusState private var isNotesFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Item name
                Text(item.displayName)
                    .font(.subheadline.weight(.medium))
                    .frame(width: 80, alignment: .leading)

                // Value input (feet or quantity)
                HStack {
                    TextField("0", text: $valueText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .focused($isValueFocused)
                        .onChange(of: isValueFocused) { _, focused in
                            if !focused { saveValue() }
                        }
                    Text(item.usesFeet ? "ft" : "qty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status picker
                statusMenu
            }

            // Notes field
            TextField("Notes", text: $notesText)
                .font(.caption)
                .textFieldStyle(.roundedBorder)
                .focused($isNotesFocused)
                .onChange(of: isNotesFocused) { _, focused in
                    if !focused { saveNotes() }
                }
        }
        .padding(.vertical, 4)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            if item.usesFeet {
                valueText = item.lengthFeet > 0 ? "\(item.lengthFeet)" : ""
            } else {
                valueText = item.quantity > 0 ? "\(item.quantity)" : ""
            }
            notesText = item.notes
        }
    }

    private var statusMenu: some View {
        Menu {
            ForEach(InventoryStatus.allCases, id: \.self) { status in
                Button {
                    item.status = status.rawValue
                } label: {
                    Label(status.rawValue, systemImage: status == .goodStock ? "checkmark.circle" : "exclamationmark.triangle")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(item.status == InventoryStatus.goodStock.rawValue ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveValue() {
        if let value = Int(valueText) {
            if item.usesFeet {
                item.lengthFeet = value
            } else {
                item.quantity = value
            }
            // Auto-update status based on thresholds
            item.updateStatusBasedOnValue()
            try? modelContext.save()
        }
    }

    private func saveNotes() {
        item.notes = notesText
        try? modelContext.save()
    }
}

// MARK: - Add Inventory Item Sheet

struct AddInventoryItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let supplier: SupplyCompany
    let existingItems: [InventoryItem]

    @State private var selectedCategory: InventoryCategory?

    private var availableCategories: [InventoryCategory] {
        InventoryCategory.categories(for: supplier)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Select Category to Add") {
                    ForEach(availableCategories) { category in
                        Button {
                            addItem(category: category)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(category.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    let count = existingItems.filter { $0.category == category.rawValue }.count
                                    Text("\(count) \(category.usesFeet ? "spool(s)" : "item(s)") currently")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Add Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addItem(category: InventoryCategory) {
        let categoryItems = existingItems.filter { $0.category == category.rawValue }
        let nextNumber = (categoryItems.map { $0.itemNumber }.max() ?? 0) + 1

        let newItem = InventoryItem(
            supplier: supplier.rawValue,
            category: category.rawValue,
            itemNumber: nextNumber
        )

        // Set owner info from current user
        newItem.ownerEmail = GmailAuthManager.shared.userEmail
        newItem.ownerName = Settings.shared.workerName

        modelContext.insert(newItem)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - PDF Generator

struct InventoryPDFGenerator {
    static func generatePDF(items: [InventoryItem]) -> Data {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = pdfRenderer.pdfData { context in
            // Generate pages for each supplier
            for supplier in SupplyCompany.allCases {
                let supplierItems = items.filter { $0.supplier == supplier.rawValue }
                guard !supplierItems.isEmpty else { continue }

                context.beginPage()
                var yPosition: CGFloat = margin

                // Title
                let titleFont = UIFont.boldSystemFont(ofSize: 24)
                let title = "\(supplier.rawValue) Inventory"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: UIColor.systemOrange
                ]
                title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
                yPosition += 35

                // Date
                let dateFont = UIFont.systemFont(ofSize: 12)
                let dateText = "Updated: \(Date().formatted(date: .long, time: .shortened))"
                let dateAttributes: [NSAttributedString.Key: Any] = [
                    .font: dateFont,
                    .foregroundColor: UIColor.gray
                ]
                dateText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: dateAttributes)
                yPosition += 30

                // Table header
                let headerFont = UIFont.boldSystemFont(ofSize: 11)
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: UIColor.white
                ]

                // Draw table header
                yPosition = drawTableHeader(at: yPosition, margin: margin, pageWidth: pageWidth, headerAttributes: headerAttributes)

                // Table rows
                let rowFont = UIFont.systemFont(ofSize: 10)
                let rowHeight: CGFloat = 22
                let columnWidths: [CGFloat] = [140, 80, 120, 180]

                // Group by category
                let categories = InventoryCategory.categories(for: supplier)

                for category in categories {
                    let categoryItems = supplierItems.filter { $0.category == category.rawValue }
                        .sorted { $0.itemNumber < $1.itemNumber }

                    guard !categoryItems.isEmpty else { continue }

                    // Check if we need a new page
                    if yPosition > pageHeight - margin - 50 {
                        context.beginPage()
                        yPosition = margin
                        yPosition = drawTableHeader(at: yPosition, margin: margin, pageWidth: pageWidth, headerAttributes: headerAttributes)
                    }

                    // Category header - use explicit light gray color for PDF
                    UIColor(white: 0.9, alpha: 1.0).setFill()
                    let catRect = CGRect(x: margin, y: yPosition, width: pageWidth - (margin * 2), height: rowHeight)
                    UIBezierPath(rect: catRect).fill()

                    let catAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 11),
                        .foregroundColor: UIColor.black
                    ]
                    category.displayName.draw(at: CGPoint(x: margin + 5, y: yPosition + 5), withAttributes: catAttributes)
                    yPosition += rowHeight

                    for item in categoryItems {
                        // Check if we need a new page
                        if yPosition > pageHeight - margin - 30 {
                            context.beginPage()
                            yPosition = margin
                            yPosition = drawTableHeader(at: yPosition, margin: margin, pageWidth: pageWidth, headerAttributes: headerAttributes)
                        }

                        // No row background - clean white rows

                        var xPos = margin + 5

                        // Item name
                        item.displayName.draw(at: CGPoint(x: xPos, y: yPosition + 5), withAttributes: [.font: rowFont])
                        xPos += columnWidths[0]

                        // Value
                        let valueText: String
                        if item.usesFeet {
                            valueText = item.lengthFeet > 0 ? "\(item.lengthFeet) ft" : "-"
                        } else {
                            valueText = item.quantity > 0 ? "\(item.quantity)" : "-"
                        }
                        valueText.draw(at: CGPoint(x: xPos, y: yPosition + 5), withAttributes: [.font: rowFont])
                        xPos += columnWidths[1]

                        // Status with color
                        let statusColor = item.status == InventoryStatus.goodStock.rawValue ? UIColor.systemGreen : UIColor.systemOrange
                        let statusAttributes: [NSAttributedString.Key: Any] = [
                            .font: rowFont,
                            .foregroundColor: statusColor
                        ]
                        item.status.draw(at: CGPoint(x: xPos, y: yPosition + 5), withAttributes: statusAttributes)
                        xPos += columnWidths[2]

                        // Notes
                        let notesAttributes: [NSAttributedString.Key: Any] = [
                            .font: UIFont.systemFont(ofSize: 9),
                            .foregroundColor: UIColor.darkGray
                        ]
                        let truncatedNotes = item.notes.count > 30 ? String(item.notes.prefix(30)) + "..." : item.notes
                        truncatedNotes.draw(at: CGPoint(x: xPos, y: yPosition + 5), withAttributes: notesAttributes)

                        yPosition += rowHeight
                    }
                }
            }
        }

        return data
    }

    private static func drawTableHeader(at yPosition: CGFloat, margin: CGFloat, pageWidth: CGFloat, headerAttributes: [NSAttributedString.Key: Any]) -> CGFloat {
        var y = yPosition

        // Header background
        let headerRect = CGRect(x: margin, y: y, width: pageWidth - (margin * 2), height: 25)
        UIColor.systemOrange.setFill()
        UIBezierPath(rect: headerRect).fill()

        // Header text
        let columns = ["Item", "Value", "Status", "Notes"]
        let columnWidths: [CGFloat] = [140, 80, 120, 180]
        var xPos = margin + 5

        for (index, header) in columns.enumerated() {
            header.draw(at: CGPoint(x: xPos, y: y + 6), withAttributes: headerAttributes)
            xPos += columnWidths[index]
        }
        y += 30

        return y
    }
}

