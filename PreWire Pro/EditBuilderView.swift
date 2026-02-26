//
//  EditBuilderView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct EditBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var builder: EditableBuilder

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            List {
                // Basic Info
                Section("Builder Info") {
                    TextField("Builder Name", text: $builder.name)
                    TextField("Highlight (quick reminder)", text: $builder.highlight)
                }

                // DMARK
                EditableListSection(
                    title: "DMARK",
                    items: $builder.dmarkItems,
                    color: .blue
                )

                // Wiring
                EditableListSection(
                    title: "WIRING",
                    items: $builder.wiringItems,
                    color: .orange
                )

                // Enclosure
                EditableListSection(
                    title: "ENCLOSURE",
                    items: $builder.enclosureItems,
                    color: .purple
                )

                // FPP
                EditableListSection(
                    title: "FPP",
                    items: $builder.fppItems,
                    color: .cyan
                )

                // Model
                EditableListSection(
                    title: "MODEL",
                    items: $builder.modelItems,
                    color: .pink
                )

                // Notes
                EditableListSection(
                    title: "NOTES",
                    items: $builder.notesItems,
                    color: .yellow
                )
            }
            .navigationTitle("Edit \(builder.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(brandGreen)
                }
            }
        }
    }
}

struct EditableListSection: View {
    let title: String
    @Binding var items: [String]
    let color: Color

    @State private var newItemText = ""

    var body: some View {
        Section {
            ForEach(items.indices, id: \.self) { index in
                HStack {
                    TextField("Item", text: Binding(
                        get: { items[index] },
                        set: { items[index] = $0 }
                    ))

                    Button {
                        items.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onMove { from, to in
                items.move(fromOffsets: from, toOffset: to)
            }

            HStack {
                TextField("Add new item...", text: $newItemText)
                    .foregroundStyle(.secondary)

                Button {
                    if !newItemText.isEmpty {
                        items.append(newItemText)
                        newItemText = ""
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .disabled(newItemText.isEmpty)
            }
        } header: {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
            }
        }
    }
}

// MARK: - Add New Builder View

struct AddBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var highlight = ""

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        NavigationStack {
            Form {
                Section("Builder Info") {
                    TextField("Builder Name", text: $name)
                    TextField("Highlight (quick reminder)", text: $highlight)
                }

                Section {
                    Text("You can add DMARK, Wiring, Enclosure, and other details after creating the builder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        let descriptor = FetchDescriptor<EditableBuilder>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
                        let maxOrder = (try? modelContext.fetch(descriptor).first?.sortOrder) ?? -1

                        let newBuilder = EditableBuilder(
                            name: name,
                            highlight: highlight,
                            sortOrder: maxOrder + 1
                        )
                        modelContext.insert(newBuilder)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(brandGreen)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    EditBuilderView(builder: EditableBuilder(name: "Test Builder", highlight: "Test"))
}
