//
//  InvoicesView.swift
//  Pal Low Voltage Pro
//
//  Created by Claude on 12/14/25.
//

import SwiftUI
import SwiftData
import QuickLook

struct InvoicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Invoice.createdAt, order: .reverse) private var allInvoices: [Invoice]
    @State private var previewURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var invoiceToDelete: Invoice?
    @State private var showingInvoiceGenerator = false

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var invoices: [Invoice] {
        allInvoices.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    var body: some View {
        NavigationStack {
            Group {
                if invoices.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("No Invoices")
                            .font(.title2.bold())

                        Text("Generate invoices from the menu to see them here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    // Invoice list
                    List {
                        ForEach(invoices) { invoice in
                            InvoiceRowWithActions(
                                invoice: invoice,
                                onView: { viewInvoice(invoice) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    invoiceToDelete = invoice
                                    showingDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invoices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingInvoiceGenerator = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .quickLookPreview($previewURL)
            .sheet(isPresented: $showingInvoiceGenerator) {
                WeeklyInvoiceView()
            }
            .alert("Delete Invoice?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let invoice = invoiceToDelete {
                        deleteInvoice(invoice)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let invoice = invoiceToDelete {
                    Text("Are you sure you want to delete the invoice for \(invoice.weekRange)?")
                }
            }
        }
    }

    // MARK: - Methods

    private func viewInvoice(_ invoice: Invoice) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(invoice.fileName)
        do {
            try invoice.pdfData.write(to: tempURL)
            previewURL = tempURL
        } catch {
            print("Error writing PDF for preview: \(error)")
        }
    }

    private func deleteInvoice(_ invoice: Invoice) {
        modelContext.delete(invoice)
        try? modelContext.save()
    }
}

// MARK: - Invoice Row with View and Share Actions

struct InvoiceRowWithActions: View {
    let invoice: Invoice
    let onView: () -> Void

    private func getPDFURL(for invoice: Invoice) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(invoice.fileName)
        do {
            try invoice.pdfData.write(to: tempURL)
            return tempURL
        } catch {
            print("Error writing PDF: \(error)")
            return nil
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tap to view invoice
            Button {
                onView()
            } label: {
                HStack(spacing: 12) {
                    // PDF Icon
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)

                    // Invoice info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(invoice.weekRange)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        HStack(spacing: 8) {
                            Label("\(invoice.jobCount) jobs", systemImage: "briefcase")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.secondary)

                            Text(invoice.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("$\(invoice.total, specifier: "%.2f")")
                            .font(.title3.bold())
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Large Share Button
            if let url = getPDFURL(for: invoice) {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.blue.gradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
