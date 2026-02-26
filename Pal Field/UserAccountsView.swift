//
//  UserAccountsView.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct UserAccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ChatUser.displayName) private var users: [ChatUser]

    @State private var showingAddUser = false
    @State private var userToEdit: ChatUser?
    @State private var showingDeleteConfirmation = false
    @State private var userToDelete: ChatUser?

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        List {
            if users.isEmpty {
                ContentUnavailableView(
                    "No Users",
                    systemImage: "person.3",
                    description: Text("Users are automatically registered when they open the chat. You can also add users manually.")
                )
            } else {
                ForEach(users) { user in
                    UserAccountRow(user: user)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            userToEdit = user
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                userToDelete = user
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }

                            Button {
                                userToEdit = user
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                }
            }
        }
        .navigationTitle("User Accounts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddUser = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddUser) {
            EditUserAccountView(user: nil)
        }
        .sheet(item: $userToEdit) { user in
            EditUserAccountView(user: user)
        }
        .alert("Delete User", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                userToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let user = userToDelete {
                    modelContext.delete(user)
                    try? modelContext.save()
                }
                userToDelete = nil
            }
        } message: {
            if let user = userToDelete {
                Text("Are you sure you want to delete \(user.displayName)? This cannot be undone.")
            }
        }
    }
}

// MARK: - User Account Row

struct UserAccountRow: View {
    let user: ChatUser

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with role color
            Circle()
                .fill(user.role.color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(user.role.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.headline)

                    // Role badge
                    Text(user.role.rawValue)
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(user.role.color)
                        .clipShape(Capsule())
                }

                Text(user.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Last seen: \(user.lastSeen, style: .relative) ago")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit User Account View

struct EditUserAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let user: ChatUser?

    @State private var email: String = ""
    @State private var displayName: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    private var isEditing: Bool {
        user != nil
    }

    private var canSave: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewRole: UserRole {
        UserRole.role(for: email)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .disabled(isEditing) // Can't change email after creation

                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                } header: {
                    Text("User Information")
                }

                Section {
                    HStack {
                        Text("Role")
                        Spacer()
                        HStack(spacing: 6) {
                            Text(previewRole.rawValue)
                                .foregroundStyle(previewRole.color)
                            Circle()
                                .fill(previewRole.color)
                                .frame(width: 12, height: 12)
                        }
                    }

                    Text(previewRole.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Role Preview")
                } footer: {
                    Text("Roles are determined automatically by email address and cannot be changed here.")
                }

                if isEditing, let user = user {
                    Section("Account Info") {
                        HStack {
                            Text("Created")
                            Spacer()
                            Text(user.createdAt, style: .date)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Last Seen")
                            Spacer()
                            Text(user.lastSeen, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit User" : "Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveUser()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let user = user {
                    email = user.email
                    displayName = user.displayName
                }
            }
        }
    }

    private func saveUser() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        if isEditing, let user = user {
            // Update existing user
            user.displayName = trimmedName
            try? modelContext.save()
            dismiss()
        } else {
            // Check if email already exists
            let descriptor = FetchDescriptor<ChatUser>(predicate: #Predicate { $0.email == trimmedEmail })
            if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
                errorMessage = "A user with this email already exists."
                showingError = true
                return
            }

            // Create new user
            let newUser = ChatUser(email: trimmedEmail, displayName: trimmedName)
            modelContext.insert(newUser)
            try? modelContext.save()
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        UserAccountsView()
    }
}
