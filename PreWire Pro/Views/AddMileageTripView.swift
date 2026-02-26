//
//  AddMileageTripView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI
import SwiftData

struct AddMileageTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var miles: String = ""
    @State private var date = Date()
    @State private var purpose: String = "Work"
    @State private var notes: String = ""
    @FocusState private var isInputActive: Bool

    var isValid: Bool {
        guard let milesValue = Double(miles), milesValue > 0 else {
            return false
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    HStack {
                        Text("Miles")
                        Spacer()
                        TextField("0.0", text: $miles)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    Picker("Purpose", selection: $purpose) {
                        Text("Work").tag("Work")
                        Text("Business Meeting").tag("Business Meeting")
                        Text("Client Visit").tag("Client Visit")
                        Text("Other").tag("Other")
                    }
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }

                Section {
                    if let milesValue = Double(miles), milesValue > 0 {
                        HStack {
                            Text("Tax Deduction")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("$\(milesValue * 0.67, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Add Mileage Trip")
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
                        saveTrip()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func saveTrip() {
        guard let milesValue = Double(miles) else { return }

        let trip = MileageTrip(
            startDate: date,
            endDate: date,
            miles: milesValue,
            purpose: purpose,
            notes: notes,
            ownerEmail: GmailAuthManager.shared.userEmail,
            ownerName: Settings.shared.workerName
        )

        modelContext.insert(trip)
        try? modelContext.save()

        dismiss()
    }
}
