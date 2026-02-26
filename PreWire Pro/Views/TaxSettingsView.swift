//
//  TaxSettingsView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/16/25.
//

import SwiftUI

struct TaxSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: Settings
    @State private var showingTaxYearAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Filing Status", selection: $settings.taxFilingStatus) {
                        ForEach(TaxFilingStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }

                    Picker("State", selection: $settings.taxState) {
                        ForEach(USState.allCases) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }

                    HStack {
                        Text("State Tax Rate")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(settings.taxState.taxRate * 100, specifier: "%.2f")%")
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Tax Filing Information")
                } footer: {
                    if settings.taxState.taxRate == 0 {
                        Text("\(settings.taxState.rawValue) has no state income tax")
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    HStack {
                        Text("Tax Year")
                        Spacer()
                        Text(String(settings.taxYear))
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showingTaxYearAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                            Text("Update Tax Laws for New Year")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Tax Year")
                } footer: {
                    Text("Tax brackets, standard deductions, and mileage rates are updated annually by the IRS. Make sure to update for the new year when filing status changes.")
                }

                Section {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0.00", value: $settings.estimatedOtherIncome, format: .number)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Other Income (Optional)")
                } footer: {
                    Text("Include W-2 income, spouse income, or other sources. This helps estimate your total tax liability more accurately.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Tax Law Settings (\(String(settings.taxYear)))")
                            .font(.subheadline.bold())

                        HStack {
                            Text("Mileage Rate:")
                            Spacer()
                            Text("$0.67/mile")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)

                        HStack {
                            Text("Standard Deduction:")
                            Spacer()
                            Text(standardDeductionText)
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)

                        HStack {
                            Text("Self-Employment Tax:")
                            Spacer()
                            Text("15.3%")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Tax Law Reference")
                }
            }
            .navigationTitle("Tax Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Update Tax Year?", isPresented: $showingTaxYearAlert) {
                Button("Update to 2026") {
                    settings.taxYear = 2026
                }
                Button("Keep 2025") {
                    settings.taxYear = 2025
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Update tax calculations to use 2026 tax laws? Note: IRS hasn't released final 2026 numbers yet, so this uses projected values.")
            }
        }
    }

    private var standardDeductionText: String {
        switch settings.taxFilingStatus {
        case .single:
            return "$14,600"
        case .marriedFilingJointly:
            return "$29,200"
        case .marriedFilingSeparately:
            return "$14,600"
        case .headOfHousehold:
            return "$21,900"
        }
    }
}
