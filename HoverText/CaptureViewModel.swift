import Foundation
import AppKit
import Combine

@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var draftText: String = ""
    @Published var attachments: [PastedImage] = []
    @Published var focusTick: Int = 0
    // ponytail: normal save/discard cleans these; add Pending-directory startup cleanup only if crash leftovers matter.
    private var importedImageURLs = Set<URL>()

    private func clear() {
        draftText = ""
        attachments.removeAll()
        importedImageURLs.removeAll()
    }

    func requestFocus() {
        // Incrementing this tick allows views to observe and refocus the editor
        focusTick &+= 1
    }

    func addAttachment(url: URL) {
        attachments.append(PastedImage(url: url))
        importedImageURLs.insert(url)
    }

    func loadDraft(body: String, imageURLs: [URL]) {
        discard()
        draftText = body
        attachments = imageURLs.map(PastedImage.init(url:))
    }

    func finishSaving() {
        deleteImages(at: importedImageURLs.subtracting(attachments.map(\.url)))
        clear()
    }

    func discard() {
        deleteImages(at: importedImageURLs)
        clear()
    }

    private func deleteImages(at urls: Set<URL>) {
        for url in urls {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                NSLog("[HoverText] Failed to remove unused image: \(error.localizedDescription)")
            }
        }
    }
}

struct PastedImage: Identifiable, Hashable {
    let url: URL
    var id: URL { url }
}
