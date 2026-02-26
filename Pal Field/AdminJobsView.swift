//
//  AdminJobsView.swift
//  Pal Field
//
//  Created by Claude on 2/4/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AdminJobsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]

    @State private var selectedUser: String?
    @State private var showingExport = false
    @State private var exportURL: URL?

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    /// Group jobs by owner email
    var jobsByOwner: [String: [Job]] {
        Dictionary(grouping: allJobs) { job in
            job.ownerEmail.isEmpty ? "Unknown" : job.ownerEmail
        }
    }

    /// Sorted owner emails
    var sortedOwners: [String] {
        jobsByOwner.keys.sorted()
    }

    /// Jobs for selected user or all jobs if none selected
    var displayedJobs: [Job] {
        if let selectedUser = selectedUser {
            return jobsByOwner[selectedUser] ?? []
        }
        return allJobs
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
                            Text("\(jobsByOwner[owner]?.count ?? 0) jobs")
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
                    Text("Total Jobs")
                    Spacer()
                    Text("\(displayedJobs.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Total Value")
                    Spacer()
                    Text(String(format: "$%.2f", displayedJobs.reduce(0) { $0 + $1.total(settings: settings) }))
                        .foregroundStyle(brandGreen)
                        .fontWeight(.semibold)
                }

                if let selectedUser = selectedUser {
                    HStack {
                        Text("Owner")
                        Spacer()
                        Text(ownerDisplayName(selectedUser))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Jobs list
            Section("Jobs") {
                ForEach(displayedJobs) { job in
                    NavigationLink {
                        EditJobView(job: job)
                    } label: {
                        JobRowView(job: job, showOwner: selectedUser == nil)
                    }
                }
            }
        }
        .navigationTitle("All Jobs")
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
            defaultFilename: "all_jobs_export.csv"
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
        // Try to find owner name from any job
        if let job = allJobs.first(where: { $0.ownerEmail == email }), !job.ownerName.isEmpty {
            return job.ownerName
        }
        return email
    }

    private func exportToCSV() {
        var csv = "Job #,Date,Lot #,Address,Subdivision,Owner,Total\n"

        for job in displayedJobs {
            let date = job.jobDate.formatted(date: .numeric, time: .omitted)
            let total = String(format: "%.2f", job.total(settings: settings))
            let owner = job.ownerName.isEmpty ? job.ownerEmail : job.ownerName
            csv += "\"\(job.jobNumber)\",\"\(date)\",\"\(job.lotNumber)\",\"\(job.address)\",\"\(job.subdivision)\",\"\(owner)\",\"\(total)\"\n"
        }

        // Save to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("all_jobs_export.csv")
        try? csv.write(to: tempURL, atomically: true, encoding: .utf8)
        exportURL = tempURL
        showingExport = true
    }
}

// MARK: - Job Row View

struct JobRowView: View {
    let job: Job
    let showOwner: Bool
    @EnvironmentObject var settings: Settings

    private let brandGreen = Color(red: 76/255, green: 140/255, blue: 43/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(job.jobNumber)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.2f", job.total(settings: settings)))
                    .font(.subheadline.bold())
                    .foregroundStyle(brandGreen)
            }

            Text(job.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(job.jobDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if showOwner && !job.ownerEmail.isEmpty {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(job.ownerName.isEmpty ? job.ownerEmail : job.ownerName)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CSV Document

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var url: URL?

    init(url: URL?) {
        self.url = url
    }

    init(configuration: ReadConfiguration) throws {
        // Not used for export
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let url = url,
              let data = try? Data(contentsOf: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    NavigationStack {
        AdminJobsView()
            .environmentObject(Settings.shared)
    }
}
