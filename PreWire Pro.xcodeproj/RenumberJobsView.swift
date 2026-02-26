//
//  RenumberJobsView.swift
//  PreWire Pro
//
//  Created by Andrew Stewart on 12/14/25.
//
//  Utility view to renumber all existing jobs in chronological order
//  This is useful if you have old jobs with incorrect numbering

import SwiftUI
import SwiftData

struct RenumberJobsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Job.jobDate, order: .forward) private var allJobs: [Job]
    
    @State private var isProcessing = false
    @State private var showConfirmation = false
    @State private var statusMessage = ""
    @State private var previewJobs: [(old: String, new: String, date: Date)] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                    .padding()
                
                Text("Renumber All Jobs")
                    .font(.title2.bold())
                
                Text("This will renumber all jobs sequentially from JB1 onwards, based on their job date (oldest first).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if !previewJobs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preview Changes (\(previewJobs.count) jobs)")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Text("First 10 jobs:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                        
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(previewJobs.prefix(10).enumerated()), id: \.offset) { index, jobInfo in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(jobInfo.old)
                                                    .font(.caption)
                                                    .foregroundStyle(.red)
                                                    .strikethrough()
                                                
                                                Image(systemName: "arrow.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                
                                                Text(jobInfo.new)
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.green)
                                            }
                                            Text(jobInfo.date, style: .date)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 300)
                        
                        if previewJobs.count > 10 {
                            Text("... and \(previewJobs.count - 10) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        }
                    }
                }
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(statusMessage.contains("Error") ? .red : .green)
                        .padding()
                }
                
                Spacer()
                
                if isProcessing {
                    ProgressView("Renumbering jobs...")
                        .padding()
                }
                
                VStack(spacing: 12) {
                    Button {
                        generatePreview()
                    } label: {
                        Label("Preview Changes", systemImage: "eye.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isProcessing || allJobs.isEmpty)
                    
                    Button {
                        showConfirmation = true
                    } label: {
                        Label("Renumber All Jobs", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isProcessing || allJobs.isEmpty || previewJobs.isEmpty)
                }
                .padding()
            }
            .navigationTitle("Renumber Jobs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Renumber All Jobs?", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Renumber", role: .destructive) {
                    renumberAllJobs()
                }
            } message: {
                Text("This will change the job numbers for all \(allJobs.count) jobs. This action cannot be undone.")
            }
        }
    }
    
    private func generatePreview() {
        previewJobs = []
        
        // Sort jobs by date (oldest first)
        let sortedJobs = allJobs.sorted { $0.jobDate < $1.jobDate }
        
        // Generate preview of changes
        for (index, job) in sortedJobs.enumerated() {
            let newNumber = "JB\(index + 1)"
            if job.jobNumber != newNumber {
                previewJobs.append((old: job.jobNumber, new: newNumber, date: job.jobDate))
            }
        }
        
        if previewJobs.isEmpty {
            statusMessage = "✓ All jobs are already numbered correctly!"
        } else {
            statusMessage = "\(previewJobs.count) job(s) will be renumbered"
        }
    }
    
    private func renumberAllJobs() {
        isProcessing = true
        statusMessage = "Processing..."
        
        // Sort jobs by date (oldest first)
        let sortedJobs = allJobs.sorted { $0.jobDate < $1.jobDate }
        
        // Renumber sequentially
        var changedCount = 0
        for (index, job) in sortedJobs.enumerated() {
            let newNumber = "JB\(index + 1)"
            if job.jobNumber != newNumber {
                print("Renumbering: \(job.jobNumber) -> \(newNumber) (Date: \(job.jobDate))")
                job.jobNumber = newNumber
                changedCount += 1
            }
        }
        
        // Save changes
        do {
            try modelContext.save()
            statusMessage = "✓ Successfully renumbered \(changedCount) job(s)!"
            print("✓ Renumbering complete: \(changedCount) jobs updated")
            
            // Refresh preview
            generatePreview()
            
            // Dismiss after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
            print("❌ Error renumbering jobs: \(error)")
        }
        
        isProcessing = false
    }
}

#Preview {
    RenumberJobsView()
        .modelContainer(for: Job.self, inMemory: true)
}
