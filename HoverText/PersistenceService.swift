import Foundation

struct CaptureEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let body: String
    let imageURLs: [URL]
    fileprivate let sourceLine: String
}

struct PersistenceService {
    private let fileURL: URL

    init(filename: String = "captures.jsonl") {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "HoverText"
        let dir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func appendEntry(body: String, imageURLs: [URL] = []) throws {
        let entry: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "body": body,
            "images": imageURLs.map(\.path)
        ]
        let data = try JSONSerialization.data(withJSONObject: entry) + Data([0x0A])
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: fileURL, options: .atomic)
        }
    }

    func loadEntries() throws -> [CaptureEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return Self.decodeEntries(try Data(contentsOf: fileURL))
    }

    func deleteEntry(_ entry: CaptureEntry) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        var lines = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        guard let index = lines.firstIndex(of: entry.sourceLine) else { return }

        lines.remove(at: index)
        let updatedData = Data((lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n").utf8)
        try updatedData.write(to: fileURL, options: .atomic)

        let remainingImagePaths = Set(Self.decodeEntries(updatedData).flatMap(\.imageURLs).map(\.path))
        for url in entry.imageURLs where !remainingImagePaths.contains(url.path) {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                NSLog("[HoverText] Failed to remove deleted capture image: \(error.localizedDescription)")
            }
        }
    }

    func deleteEntries(olderThan cutoff: Date) throws {
        // ponytail: history is local and small; use one-pass rewriting only if retention cleanup becomes slow.
        for entry in try loadEntries() where entry.timestamp < cutoff {
            try deleteEntry(entry)
        }
    }

    static func decodeEntries(_ data: Data) -> [CaptureEntry] {
        let formatter = ISO8601DateFormatter()
        let lines = String(decoding: data, as: UTF8.self).split(whereSeparator: \.isNewline)
        return lines.compactMap { line in
            guard let value = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let timestamp = value["timestamp"] as? String,
                  let date = formatter.date(from: timestamp) else { return nil }
            return CaptureEntry(
                timestamp: date,
                body: value["body"] as? String ?? "",
                imageURLs: (value["images"] as? [String] ?? []).map { URL(fileURLWithPath: $0) },
                sourceLine: String(line)
            )
        }.reversed()
    }
}
