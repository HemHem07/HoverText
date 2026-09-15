import SwiftUI
import AppKit

struct HistoryView: View {
    let entries: [CaptureEntry]
    let onOpenAsDraft: (CaptureEntry) -> Void
    let onDelete: (CaptureEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("No Captures", systemImage: "tray", description: Text("Saved captures will appear here."))
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    onOpenAsDraft(entry)
                                } label: {
                                    Label("Open as Draft", systemImage: "square.and.pencil")
                                }

                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .buttonStyle(.borderless)

                            if !entry.body.isEmpty {
                                Text(entry.body)
                                    .textSelection(.enabled)
                            }

                            ForEach(entry.imageURLs, id: \.self) { url in
                                if let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 280)
                                } else {
                                    Label("Image unavailable", systemImage: "photo.badge.exclamationmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
    }
}
