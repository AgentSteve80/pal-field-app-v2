//
//  CloseoutEmailViewer.swift
//  Pal Field
//
//  Displays the saved closeout email for a job.
//

import SwiftUI
import UIKit

struct CloseoutEmailViewer: View {
    let job: Job
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Subject
                    if let subject = job.closeoutEmailSubject {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Subject")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(subject)
                                .font(.headline)
                        }
                        .padding(.horizontal)
                    }

                    // Date
                    if let date = job.closeoutDate {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.green)
                            Text("Sent \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    Divider()

                    // Body
                    if let body = job.closeoutEmailBody {
                        Text(body)
                            .font(.body)
                            .monospaced()
                            .padding(.horizontal)
                    }

                    // Photos
                    let paths = job.closeoutPhotoPaths
                    if !paths.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Photos (\(paths.count))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(paths, id: \.self) { path in
                                        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                                           let image = UIImage(data: data) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 200, height: 200)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Closeout Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
