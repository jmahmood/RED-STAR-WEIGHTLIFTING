import SwiftUI
import Combine

struct StoredLinksView: View {
    @StateObject private var store = StoredLinkStore.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var groupedLinks: [StoredLinkKind: [StoredLink]] = [:]

    var body: some View {
        List {
            ForEach(StoredLinkKind.allCases, id: \.self) { kind in
                Section(kind.displayName) {
                    let links = groupedLinks[kind] ?? []
                    if links.isEmpty {
                        Text("No links yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(links) { link in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    if let title = link.title, !title.isEmpty {
                                        Text(title)
                                            .font(.subheadline)
                                    } else {
                                        Text(link.url.host ?? link.url.absoluteString)
                                            .font(.subheadline)
                                    }
                                    Text(link.url.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                openURL(link.url)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.delete(link)
                                    reload()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Stored Links")
        .onAppear { reload() }
        .onReceive(store.objectWillChange) { _ in reload() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                reload()
            }
        }
    }

    private func reload() {
        groupedLinks = store.fetchAllGrouped()
    }
}
