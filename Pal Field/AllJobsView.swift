//
//  AllJobsView.swift
//  Pal Low Voltage Pro
//
//  Created by Andrew Stewart on 12/13/25.
//

import SwiftUI
import SwiftData

struct AllJobsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: Settings
    @Query(sort: \Job.jobDate, order: .reverse) private var allJobs: [Job]
    @State private var showingPDFImport = false
    @State private var showingAddJob = false

    // Filter by current user (empty ownerEmail = legacy data, treat as current user's)
    private var currentUserEmail: String {
        GmailAuthManager.shared.userEmail.lowercased()
    }

    private var jobs: [Job] {
        allJobs.filter { $0.ownerEmail.isEmpty || $0.ownerEmail.lowercased() == currentUserEmail }
    }

    private var calendar: Calendar { Calendar.current }

    // Group jobs by month
    var jobsByMonth: [(monthName: String, month: Date, jobs: [Job])] {
        let grouped = Dictionary(grouping: jobs) { job in
            calendar.startOfMonth(for: job.jobDate)
        }

        return grouped.map { (month, jobs) in
            let monthName = month.formatted(.dateTime.month(.wide).year())
            return (monthName: monthName, month: month, jobs: jobs)
        }
        .sorted { $0.month > $1.month } // Most recent first
    }
    
    var body: some View {
        List {
            ForEach(jobsByMonth, id: \.month) { monthData in
                Section {
                    ForEach(monthData.jobs) { job in
                        NavigationLink {
                            EditJobView(job: job)
                        } label: {
                            JobRowCompact(job: job, settings: settings)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteJob(job)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    MonthHeaderView(
                        monthName: monthData.monthName,
                        jobs: monthData.jobs,
                        settings: settings
                    )
                }
            }
        }
        .navigationTitle("All Jobs (\(jobs.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingAddJob = true
                    } label: {
                        Label("Add Job", systemImage: "plus")
                    }

                    Button {
                        showingPDFImport = true
                    } label: {
                        Label("Import from PDF", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddJob) {
            AddJobView()
        }
        .sheet(isPresented: $showingPDFImport) {
            PDFImportView()
        }
    }
    
    private func deleteJob(_ job: Job) {
        modelContext.delete(job)
    }
}

struct MonthHeaderView: View {
    let monthName: String
    let jobs: [Job]
    let settings: Settings
    
    private var totalPay: Double {
        jobs.reduce(0) { $0 + $1.total(settings: settings) }
    }
    
    private var totalMiles: Double {
        jobs.reduce(0) { $0 + $1.miles }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monthName)
                .font(.headline)
            
            HStack(spacing: 16) {
                Label("\(jobs.count) jobs", systemImage: "briefcase.fill")
                    .font(.caption)
                
                Label("$\(totalPay, specifier: "%.2f")", systemImage: "dollarsign.circle.fill")
                    .font(.caption)
                
                Label("\(totalMiles, specifier: "%.0f") mi", systemImage: "car.fill")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }
}

struct JobRowCompact: View {
    let job: Job
    let settings: Settings
    
    var body: some View {
        HStack(spacing: 12) {
            // Onsite photo thumbnail
            if let thumbnail = job.onsiteThumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: job.isCloseoutComplete ? "checkmark.circle.fill" : "briefcase.fill")
                    .font(.title3)
                    .foregroundStyle(job.isCloseoutComplete ? .green : .secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.jobNumber)
                        .font(.subheadline.bold())
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("Lot \(job.lotNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if !job.address.isEmpty || !job.prospect.isEmpty {
                    Text(job.address.isEmpty ? job.prospect : job.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Text(job.jobDate, style: .date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(job.total(settings: settings), specifier: "%.2f")")
                    .font(.callout.bold())
                    .foregroundStyle(.green)
                
                if job.miles > 0 {
                    Text("\(job.miles, specifier: "%.0f") mi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// Extension to help with month calculations
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
