import Foundation

@main
enum HistoryCheck {
    static func main() {
        let fixture = Data("""
        {"timestamp":"2026-01-01T00:00:00Z","body":"older","images":[]}
        {"timestamp":"2026-01-02T00:00:00Z","body":"newer","images":["/tmp/image.png"]}
        """.utf8)
        let entries = PersistenceService.decodeEntries(fixture)

        assert(entries.map(\.body) == ["newer", "older"])
        assert(entries.first?.imageURLs.first?.path == "/tmp/image.png")

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HoverTextHistoryCheck-\(UUID().uuidString).jsonl")
        try! fixture.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let persistence = PersistenceService(fileURL: fileURL)
        let cutoff = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
        try! persistence.deleteEntries(olderThan: cutoff)
        assert(try! persistence.loadEntries().map(\.body) == ["newer"])
        try! persistence.deleteEntry(persistence.loadEntries().first!)
        assert(try! persistence.loadEntries().isEmpty)
    }
}
