//
//  EditContactView.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct EditContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: EditableContact?

    @State private var community: String
    @State private var city: String
    @State private var region: String
    @State private var managers: [ContactManager]

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)
    private let regions = ["East Side", "Central", "West Side"]

    var isNewContact: Bool {
        contact == nil
    }

    init(contact: EditableContact?) {
        self.contact = contact
        _community = State(initialValue: contact?.community ?? "")
        _city = State(initialValue: contact?.city ?? "")
        _region = State(initialValue: contact?.region ?? "East Side")
        _managers = State(initialValue: contact?.managers ?? [ContactManager(name: "", phone: "", email: "")])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Community Info") {
                    TextField("Community Name", text: $community)
                    TextField("City", text: $city)

                    Picker("Region", selection: $region) {
                        ForEach(regions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                }

                Section {
                    ForEach($managers) { $manager in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Name", text: $manager.name)
                                .font(.headline)

                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                TextField("Phone", text: $manager.phone)
                                    .keyboardType(.phonePad)
                            }

                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                TextField("Email", text: $manager.email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteManager)

                    Button {
                        managers.append(ContactManager(name: "", phone: "", email: ""))
                    } label: {
                        Label("Add Manager", systemImage: "plus.circle.fill")
                            .foregroundStyle(brandGreen)
                    }
                } header: {
                    Text("Construction Managers")
                } footer: {
                    Text("Add contact information for construction managers at this community.")
                }
            }
            .navigationTitle(isNewContact ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(community.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func deleteManager(at offsets: IndexSet) {
        managers.remove(atOffsets: offsets)
        // Ensure at least one manager row exists
        if managers.isEmpty {
            managers.append(ContactManager(name: "", phone: "", email: ""))
        }
    }

    private func saveContact() {
        // Filter out empty managers
        let validManagers = managers.filter { !$0.name.isEmpty || !$0.phone.isEmpty || !$0.email.isEmpty }

        if let existingContact = contact {
            // Update existing contact
            existingContact.community = community
            existingContact.city = city
            existingContact.region = region
            existingContact.managers = validManagers
        } else {
            // Create new contact
            let newContact = EditableContact(
                community: community,
                city: city,
                region: region,
                sortOrder: 999,  // Will be at end
                managers: validManagers
            )
            modelContext.insert(newContact)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    EditContactView(contact: nil)
}
