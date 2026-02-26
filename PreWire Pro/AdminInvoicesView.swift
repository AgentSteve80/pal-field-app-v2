//
//  AdminInvoicesView.swift
//  PreWire Pro
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData

struct AdminInvoicesView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @Query(sort: \Invoice.createdAt, order: .reverse) private var allInvoices: [Invoice]

    @State private var selectedUser: String?
    @State private var selectedInvoice: Invoice?
    @State private var showingPDF = false

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    /// Group invoices by owner email
    var invoicesByOwner: [String: [Invoice]] {
        Dictionary(grouping: allInvoices) { invoice in
            invoice.ownerEmail.isEmpty ? "Unknown" : invoice.ownerEmail
        }
    }

    /// Sorted owner emails
    var sortedOwners: [String] {
        invoicesByOwner.keys.sorted()
    }

    /// Invoices for selected user or all invoices if none selected
    var displayedInvoices: [Invoice] {
        if let selectedUser = selectedUser {
            return invoicesByOwner[selectedUser] ?? []
        }
        return allInvoices
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
                            Text("\(invoicesByOwner[owner]?.count ?? 0) invoices")
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
                    Text("Total Invoices")
                    Spacer()
                    Text("\(displayedInvoices.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Total Value")
                    Spacer()
                    Text(String(format: "$%.2f", displayedInvoices.reduce(0) { $0 + $1.total }))
                        .foregroundStyle(brandGreen)
                        .fontWeight(.semibold)
                }
            }

            // Invoices list
            Section("Invoices") {
                ForEach(displayedInvoices) { invoice in
                    Button {
                        selectedInvoice = invoice
                        showingPDF = true
                    } label: {
                        InvoiceRowView(invoice: invoice, showOwner: selectedUser == nil)
                    }
                }
            }
        }
        .navigationTitle("All Invoices")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPDF) {
            if let invoice = selectedInvoice {
                PDFViewerSheet(invoice: invoice)
            }
        }
    }

    private func ownerDisplayName(_ email: String) -> String {
        if email == "Unknown" { return "Unknown User" }
        if let invoice = allInvoices.first(where: { $0.ownerEmail == email }), !invoice.ownerName.isEmpty {
            return invoice.ownerName
        }
        return email
    }
}

// MARK: - Invoice Row View

struct InvoiceRowView: View {
    let invoice: Invoice
    let showOwner: Bool

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(invoice.weekRange)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.2f", invoice.total))
                    .font(.subheadline.bold())
                    .foregroundStyle(brandGreen)
            }

            HStack {
                Text("\(invoice.jobCount) jobs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showOwner && !invoice.ownerEmail.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(invoice.ownerName.isEmpty ? invoice.ownerEmail : invoice.ownerName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PDF Viewer Sheet

struct PDFViewerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let invoice: Invoice

    var body: some View {
        NavigationStack {
            PDFViewer(data: invoice.pdfData)
                .navigationTitle(invoice.weekRange)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: invoice.pdfData, preview: SharePreview(invoice.fileName, image: Image(systemName: "doc.fill")))
                    }
                }
        }
    }
}

// Simple PDF viewer using UIViewRepresentable
struct PDFViewer: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIView {
        let pdfView = PDFKit.PDFView()
        pdfView.document = PDFKit.PDFDocument(data: data)
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

import PDFKit

#Preview {
    NavigationStack {
        AdminInvoicesView()
            .environmentObject(Settings.shared)
    }
}
