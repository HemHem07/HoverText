import Foundation

@main
@MainActor
enum CaptureSessionCheck {
    static func main() {
        let model = CaptureViewModel()
        let initialRevision = model.sessionRevision

        model.draftText = "first capture"
        model.finishSaving()
        assert(model.sessionRevision == initialRevision + 1)

        model.draftText = "discarded capture"
        model.discard()
        assert(model.sessionRevision == initialRevision + 2)
    }
}
