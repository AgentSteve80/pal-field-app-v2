//
//  NewDMUserListView.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct NewDMUserListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: Settings
    @Query(sort: \ChatUser.displayName) private var allUsers: [ChatUser]

    let onSelectUser: (ChatUser) -> Void

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    /// Filter users based on DM permission rules
    private var availableUsers: [ChatUser] {
        let myEmail = GmailAuthManager.shared.userEmail.lowercased()
        return allUsers.filter { user in
            // Don't show self
            guard user.email.lowercased() != myEmail else { return false }
            // Check if current user can DM this user
            return canDirectMessage(to: user.email)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if availableUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(brandGreen.opacity(0.5))

                        Text("No Users Available")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Other team members will appear here once they open the chat.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(availableUsers) { user in
                        Button {
                            onSelectUser(user)
                            // Parent handles dismissal
                        } label: {
                            HStack(spacing: 12) {
                                // Avatar circle with role color
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
                                            .foregroundStyle(.white)

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
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.white.opacity(0.05))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(brandGreen)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Check if current user can send DM to target user based on role permissions
    private func canDirectMessage(to targetEmail: String) -> Bool {
        let myRole = settings.userRole
        let targetRole = UserRole.role(for: targetEmail)

        // Admin/Developer can DM anyone
        if myRole == .developer || myRole == .admin {
            return true
        }

        // Supervisor can DM anyone
        if myRole == .supervisor {
            return true
        }

        // Standard can DM Supervisors and other Standard users
        if myRole == .standard {
            return targetRole == .supervisor || targetRole == .standard
        }

        return false
    }
}

#Preview {
    NewDMUserListView { user in
        print("Selected: \(user.displayName)")
    }
    .environmentObject(Settings.shared)
}
