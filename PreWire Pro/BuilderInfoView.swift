//
//  BuilderInfoView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct BuilderInfoView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showingAddBuilder = false
    @State private var showingAddContact = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Standards").tag(0)
                Text("Contacts").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                BuilderStandardsView(isAdminMode: settings.adminModeEnabled && settings.userRole.canEdit)
            } else {
                ContactsView(searchText: $searchText, isAdminMode: settings.adminModeEnabled && settings.userRole.canEdit)
            }
        }
        .background(Color.black)
        .navigationTitle("Builder Info")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search subdivisions...")
        .tint(brandGreen)
        .toolbar {
            if selectedTab == 0 && settings.adminModeEnabled && settings.userRole.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBuilder = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(brandGreen)
                    }
                }
            } else if selectedTab == 1 && settings.adminModeEnabled && settings.userRole.canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(brandGreen)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddBuilder) {
            AddBuilderView()
        }
        .sheet(isPresented: $showingAddContact) {
            EditContactView(contact: nil)
        }
        .onAppear {
            // Seed default builders if none exist
            DefaultBuilderData.seedBuilders(context: modelContext)
        }
    }
}

// MARK: - Builder Standards View

struct BuilderStandardsView: View {
    @Query(sort: \EditableBuilder.sortOrder) private var builders: [EditableBuilder]
    @Environment(\.modelContext) private var modelContext
    let isAdminMode: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(builders) { builder in
                    EditableBuilderCard(builder: builder, isAdminMode: isAdminMode)
                }
            }
            .padding()
        }
    }
}

struct EditableBuilderCard: View {
    @Bindable var builder: EditableBuilder
    @Environment(\.modelContext) private var modelContext
    let isAdminMode: Bool
    @State private var isExpanded = false
    @State private var showingEditSheet = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(builder.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    // Edit button - only show in admin mode
                    if isAdminMode {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(brandGreen)
                        }
                        .buttonStyle(.plain)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding()
                .background(Color.white.opacity(0.1))
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if !builder.dmarkItems.isEmpty {
                        BuilderSection(title: "DMARK", items: builder.dmarkItems, color: .blue)
                    }
                    if !builder.wiringItems.isEmpty {
                        BuilderSection(title: "WIRING", items: builder.wiringItems, color: .orange)
                    }
                    if !builder.enclosureItems.isEmpty {
                        BuilderSection(title: "ENCLOSURE", items: builder.enclosureItems, color: .purple)
                    }
                    if !builder.fppItems.isEmpty {
                        BuilderSection(title: "FPP", items: builder.fppItems, color: .cyan)
                    }
                    if !builder.modelItems.isEmpty {
                        BuilderSection(title: "MODEL", items: builder.modelItems, color: .pink)
                    }
                    if !builder.notesItems.isEmpty {
                        BuilderSection(title: "NOTES", items: builder.notesItems, color: .yellow)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingEditSheet) {
            EditBuilderView(builder: builder)
        }
        .contextMenu {
            if isAdminMode {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Builder", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    modelContext.delete(builder)
                    try? modelContext.save()
                } label: {
                    Label("Delete Builder", systemImage: "trash")
                }
            }
        }
    }
}

struct BuilderSection: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.white.opacity(0.5))
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
}

// MARK: - Contacts View (Editable)

struct ContactsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EditableContact.sortOrder) private var contacts: [EditableContact]
    @Binding var searchText: String
    let isAdminMode: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var filteredContacts: [EditableContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter {
            $0.community.localizedCaseInsensitiveContains(searchText) ||
            $0.city.localizedCaseInsensitiveContains(searchText) ||
            $0.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var eastSideContacts: [EditableContact] {
        contacts.filter { $0.region == "East Side" }
    }

    var centralContacts: [EditableContact] {
        contacts.filter { $0.region == "Central" }
    }

    var westSideContacts: [EditableContact] {
        contacts.filter { $0.region == "West Side" }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Area Managers Section
                if searchText.isEmpty {
                    AreaManagersSection()
                }

                // Contacts by region
                if searchText.isEmpty {
                    EditableContactSection(title: "East Side", contacts: eastSideContacts, isAdminMode: isAdminMode)
                    EditableContactSection(title: "Central", contacts: centralContacts, isAdminMode: isAdminMode)
                    EditableContactSection(title: "West Side", contacts: westSideContacts, isAdminMode: isAdminMode)
                } else {
                    // Search results
                    ForEach(filteredContacts) { contact in
                        EditableContactCard(contact: contact, isAdminMode: isAdminMode)
                    }

                    if filteredContacts.isEmpty {
                        Text("No subdivisions found")
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 40)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Seed default contacts if none exist
            DefaultContactData.seedContacts(context: modelContext)
        }
    }
}

// Legacy PulteContactsView for backwards compatibility
struct PulteContactsView: View {
    @Binding var searchText: String

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var filteredContacts: [PulteContact] {
        if searchText.isEmpty {
            return PulteContactData.allContacts
        }
        return PulteContactData.allContacts.filter {
            $0.community.localizedCaseInsensitiveContains(searchText) ||
            $0.city.localizedCaseInsensitiveContains(searchText) ||
            $0.officeLocation.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Area Managers Section
                if searchText.isEmpty {
                    AreaManagersSection()
                }

                // Contacts by region
                if searchText.isEmpty {
                    ContactSection(title: "East Side", contacts: PulteContactData.eastSide)
                    ContactSection(title: "Central", contacts: PulteContactData.central)
                    ContactSection(title: "West Side", contacts: PulteContactData.westSide)
                } else {
                    // Search results
                    ForEach(filteredContacts) { contact in
                        ContactCard(contact: contact)
                    }

                    if filteredContacts.isEmpty {
                        Text("No subdivisions found")
                            .foregroundStyle(.white.opacity(0.5))
                            .padding(.top, 40)
                    }
                }
            }
            .padding()
        }
    }
}

struct AreaManagersSection: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("Area Construction Managers")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding()
                .background(Color.yellow.opacity(0.2))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(PulteContactData.areaManagers, id: \.name) { manager in
                        ManagerRow(area: manager.area, name: manager.name, phone: manager.phone, email: manager.email)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ManagerRow: View {
    let area: String
    let name: String
    let phone: String
    let email: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(area)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.3))
                    .clipShape(Capsule())
                Spacer()
            }

            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                Button {
                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: "-", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                Button {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ContactSection: View {
    let title: String
    let contacts: [PulteContact]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top, 8)

            ForEach(contacts) { contact in
                ContactCard(contact: contact)
            }
        }
    }
}

// MARK: - Editable Contact Section

struct EditableContactSection: View {
    let title: String
    let contacts: [EditableContact]
    let isAdminMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .padding(.top, 8)

            ForEach(contacts) { contact in
                EditableContactCard(contact: contact, isAdminMode: isAdminMode)
            }
        }
    }
}

// MARK: - Editable Contact Card

struct EditableContactCard: View {
    @Bindable var contact: EditableContact
    @Environment(\.modelContext) private var modelContext
    let isAdminMode: Bool
    @State private var isExpanded = false
    @State private var showingEditSheet = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.community)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !contact.city.isEmpty {
                            Text(contact.city)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    if isAdminMode {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(brandGreen)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("\(contact.managers.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(brandGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding()
                .background(Color.white.opacity(0.1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(contact.managers) { manager in
                        ContactManagerRow(name: manager.name, phone: manager.phone, email: manager.email)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingEditSheet) {
            EditContactView(contact: contact)
        }
        .contextMenu {
            if isAdminMode {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Contact", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    modelContext.delete(contact)
                    try? modelContext.save()
                } label: {
                    Label("Delete Contact", systemImage: "trash")
                }
            }
        }
    }
}

struct ContactCard: View {
    let contact: PulteContact
    @State private var isExpanded = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.community)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !contact.city.isEmpty {
                            Text(contact.city)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    Text("\(contact.managers.count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(brandGreen)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding()
                .background(Color.white.opacity(0.1))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(contact.managers, id: \.name) { manager in
                        ContactManagerRow(name: manager.name, phone: manager.phone, email: manager.email)
                    }
                }
                .padding()
                .background(Color.white.opacity(0.05))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ContactManagerRow: View {
    let name: String
    let phone: String
    let email: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)

                Text(phone)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "tel:\(phone.replacingOccurrences(of: "-", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.green)
                        .clipShape(Circle())
                }

                Button {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BuilderInfoView()
    }
}
