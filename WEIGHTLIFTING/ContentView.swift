//
//  ContentView.swift
//  WEIGHTLIFTING
//
//  Created by Codex on 2025-10-30.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var inbox: ExportInboxStore
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let snapshot = inbox.latestFile {
                        ExportDetailCard(snapshot: snapshot) {
                            shareItem = ShareItem(url: snapshot.fileURL)
                        }
                    } else {
                        EmptyInboxView()
                    }

                    if inbox.history.count > 1 {
                        Divider()
                        Text("Recent Exports")
                            .font(.headline)
                        RecentExportsList(
                            snapshots: Array(inbox.history.dropFirst()),
                            onShare: { snapshot in
                                shareItem = ShareItem(url: snapshot.fileURL)
                            }
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export Inbox")
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
        }
        .task {
            inbox.requestNotificationAuthorization()
        }
    }
}

private struct ExportDetailCard: View {
    let snapshot: ExportedSnapshot
    let onShare: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSV Export Ready")
                .font(.title3)
                .bold()
            Text(snapshot.fileName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            InfoRow(title: "Rows", value: "\(snapshot.rows)")
            InfoRow(title: "Size", value: snapshot.sizeLabel)
            InfoRow(title: "Received", value: DateFormatter.shortFormatter.string(from: snapshot.receivedAt))
            InfoRow(title: "Schema", value: snapshot.schema)

            Button("Share / Save to Files", action: onShare)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout)
        }
    }
}

private struct EmptyInboxView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No exports yet")
                .font(.headline)
            Text("Use the Export option on your watch to send a CSV snapshot.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }
}

private struct RecentExportsList: View {
    let snapshots: [ExportedSnapshot]
    let onShare: (ExportedSnapshot) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(snapshots.enumerated()), id: \.element.id) { entry in
                let snapshot = entry.element
                let index = entry.offset
                Button {
                    onShare(snapshot)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.fileName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(snapshot.receivedAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(snapshot.sizeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)

                if index < snapshots.count - 1 {
                    Divider()
                }
            }
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

private extension DateFormatter {
    static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
