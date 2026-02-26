//
//  AdminInventoryView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @Query(sort: \InventoryItem.createdAt, order: .reverse) private var allItems: [InventoryItem]

    @State private var selectedUser: String?
    @State private var showingExport = false
    @State private var exportURL: URL?

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    /// Group items by owner email
    var itemsByOwner: [String: [InventoryItem]] {
        Dictionary(grouping: allItems) { item in
            item.ownerEmail.isEmpty ? "Unknown" : item.ownerEmail
        }
    }

    /// Sorted owner emails
    var sortedOwners: [String] {
        itemsByOwner.keys.sorted()
    }

    /// Items for selected user or all items if none selected
    var displayedItems: [InventoryItem] {
        if let selectedUser = selectedUser {
            return itemsByOwner[selectedUser] ?? []
        }
        return allItems
    }

    /// Items that need restocking
    var needsRestockCount: Int {
        displayedItems.filter { $0.needsRestock }.count
    }

    var body: some View {
        List {
            // User filter section
            Section {
                Picker("Filter by User", selection: $selectedUser) {
                    Text("All Users").tag(nil as String?)
                    ForEach(sortedOwners, id: \.self) { owner in
                        HStack {
                            Text(ownerDisplayName(owner))
                            Spacer()
                            Text("\(itemsByOwner[owner]?.count ?? 0) items")
                                .foregroundStyle(.secondary)
                        }
                        .tag(owner as String?)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            // Summary section
            Section("Summary") {
                HStack {
                    Text("Total Items")
                    Spacer()
                    Text("\(displayedItems.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Needs Restock")
                    Spacer()
                    Text("\(needsRestockCount)")
                        .foregroundStyle(needsRestockCount > 0 ? .red : .green)
                        .fontWeight(.semibold)
                }
            }

            // Items list grouped by category
            Section("Inventory Items") {
                ForEach(displayedItems) { item in
                    InventoryItemRowView(item: item, showOwner: selectedUser == nil)
                }
            }
        }
        .navigationTitle("All Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    exportToCSV()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .fileExporter(
            isPresented: $showingExport,
            document: CSVDocument(url: exportURL),
            contentType: .commaSeparatedText,
            defaultFilename: "all_inventory_export.csv"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ Exported to \(url)")
            case .failure(let error):
                print("❌ Export failed: \(error)")
            }
        }
    }

    private func ownerDisplayName(_ email: String) -> String {
        if email == "Unknown" { return "Unknown User" }
        if let item = allItems.first(where: { $0.ownerEmail == email }), !item.ownerName.isEmpty {
            return item.ownerName
        }
        return email
    }

    private func exportToCSV() {
        var csv = "Supplier,Category,Item #,Quantity,Length (ft),Status,Owner,Notes\n"

        for item in displayedItems {
            let owner = item.ownerName.isEmpty ? item.ownerEmail : item.ownerName
            csv += "\"\(item.supplier)\",\"\(item.category)\",\"\(item.itemNumber)\",\"\(item.quantity)\",\"\(item.lengthFeet)\",\"\(item.status)\",\"\(owner)\",\"\(item.notes)\"\n"
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("all_inventory_export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        exportURL = tempURL
        showingExport = true
    }
}

// MARK: - Inventory Item Row View

struct InventoryItemRowView: View {
    let item: InventoryItem
    let showOwner: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.displayName)
                    .font(.headline)

                if item.needsRestock {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

                Spacer()

                Text(item.supplier)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
            }

            HStack {
                if item.usesFeet {
                    Text("\(item.lengthFeet) ft")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Qty: \(item.quantity)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("•")
                    .foregroundStyle(.secondary)

                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showOwner && !item.ownerEmail.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(item.ownerName.isEmpty ? item.ownerEmail : item.ownerName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AdminInventoryView()
            .environmentObject(Settings.shared)
    }
}
