import SwiftUI
import AppKit

struct CaptureView: View {
    @ObservedObject var viewModel: CaptureViewModel
    let onCloseWithoutSave: () -> Void
    let onSaveAndNew: () -> Void
    let onImageInserted: (CGFloat) -> Void
    @State private var hovering = false
    @State private var windowIsFocused = true

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    // Top bar with actions
                    HStack(spacing: 8) {
                        Button {
                            onCloseWithoutSave()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .opacity(hovering ? 1 : 0.0)

                        Spacer()

                        Button {
                            onSaveAndNew()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .opacity(hovering ? 1 : 0.0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    Divider()

                    RichCaptureEditor(viewModel: viewModel, onImageInserted: onImageInserted)
                    .padding(12)
                    .frame(minHeight: 140)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.48), lineWidth: 2)
                )
                .overlay(
                    Group {
                        if !windowIsFocused {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 3)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(12)
            }
            .onHover { hovering = $0 }
            .onReceive(NotificationCenter.default.publisher(for: .captureWindowFocusChanged)) { note in
                if let focused = note.userInfo?["focused"] as? Bool {
                    windowIsFocused = focused
                }
            }
        }
        .frame(minWidth: 360, minHeight: 180)
    }

}

private struct RichCaptureEditor: NSViewRepresentable {
    @ObservedObject var viewModel: CaptureViewModel
    let onImageInserted: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, onImageInserted: onImageInserted)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let textView = InlineImageTextView()
        textView.delegate = context.coordinator
        textView.onImagePaste = { url in
            viewModel.addAttachment(url: url)
        }
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsImageEditing = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.linkTextAttributes = [:]
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.string = viewModel.draftText
        textView.setSelectedRange(NSRange(location: textView.string.utf16.count, length: 0))
        context.coordinator.applyDefaultTypingAttributes(to: textView)

        scrollView.documentView = textView
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onImageInserted = onImageInserted
        guard let textView = context.coordinator.textView else { return }

        if viewModel.draftText.isEmpty && viewModel.attachments.isEmpty && textView.textStorage?.length != 0 {
            textView.textStorage?.setAttributedString(NSAttributedString())
            context.coordinator.insertedAttachmentIDs.removeAll()
            context.coordinator.applyDefaultTypingAttributes(to: textView)
        }

        context.coordinator.insertNewAttachments(from: viewModel.attachments)

        if context.coordinator.lastFocusTick != viewModel.focusTick {
            context.coordinator.lastFocusTick = viewModel.focusTick
            DispatchQueue.main.async {
                context.coordinator.applyDefaultTypingAttributes(to: textView)
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        let viewModel: CaptureViewModel
        var onImageInserted: (CGFloat) -> Void
        weak var textView: NSTextView?
        var insertedAttachmentIDs = Set<URL>()
        var lastFocusTick = 0

        init(viewModel: CaptureViewModel, onImageInserted: @escaping (CGFloat) -> Void) {
            self.viewModel = viewModel
            self.onImageInserted = onImageInserted
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            syncViewModel(from: textView)
        }

        func insertNewAttachments(from attachments: [PastedImage]) {
            for attachment in attachments where !insertedAttachmentIDs.contains(attachment.url) {
                insertAttachment(attachment)
                insertedAttachmentIDs.insert(attachment.url)
            }
        }

        private func insertAttachment(_ pastedImage: PastedImage) {
            guard let textView, let image = NSImage(contentsOf: pastedImage.url) else { return }

            let storage = textView.textStorage ?? NSTextStorage()
            let insertionRange = textView.selectedRange()
            let textAttachment = ImageTextAttachment(url: pastedImage.url)
            textAttachment.image = image
            let bounds = scaledBounds(
                for: image,
                maxWidth: max(180, textView.visibleRect.width - 24),
                maxHeight: max(220, ((textView.window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 700) - 148)
            )
            textAttachment.bounds = bounds

            let inserted = NSMutableAttributedString()
            let previousCharacter = insertionRange.location > 0
                ? (storage.string as NSString).substring(with: NSRange(location: insertionRange.location - 1, length: 1))
                : "\n"
            if previousCharacter != "\n" {
                inserted.append(NSAttributedString(string: "\n"))
            }
            let attachmentString = NSMutableAttributedString(attachment: textAttachment)
            attachmentString.addAttribute(.link, value: pastedImage.url, range: NSRange(location: 0, length: attachmentString.length))
            inserted.append(attachmentString)
            inserted.append(NSAttributedString(string: "\n"))

            storage.replaceCharacters(in: insertionRange, with: inserted)
            textView.setSelectedRange(NSRange(location: insertionRange.location + inserted.length, length: 0))
            applyDefaultTypingAttributes(to: textView)
            textView.scrollRangeToVisible(textView.selectedRange())
            syncViewModel(from: textView)
            DispatchQueue.main.async { [onImageInserted] in
                onImageInserted(bounds.height)
            }
        }

        func applyDefaultTypingAttributes(to textView: NSTextView) {
            textView.font = textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
            textView.textColor = .labelColor
            textView.insertionPointColor = .labelColor
            textView.typingAttributes = [
                .font: textView.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
                .foregroundColor: NSColor.labelColor
            ]
        }

        private func syncViewModel(from textView: NSTextView) {
            viewModel.draftText = textView.string.replacingOccurrences(of: "\u{fffc}", with: "")

            guard let storage = textView.textStorage else { return }
            var urls: [URL] = []
            storage.enumerateAttribute(
                .attachment,
                in: NSRange(location: 0, length: storage.length),
                options: []
            ) { value, _, _ in
                if let attachment = value as? ImageTextAttachment {
                    urls.append(attachment.url)
                }
            }
            if viewModel.attachments.map(\.url) != urls {
                viewModel.attachments = urls.map { PastedImage(url: $0) }
            }
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL {
                ImagePreviewWindowController.shared.showImage(at: url)
                return true
            }
            if let urlString = link as? String, let url = URL(string: urlString) {
                ImagePreviewWindowController.shared.showImage(at: url)
                return true
            }
            return false
        }

        private func scaledBounds(for image: NSImage, maxWidth: CGFloat, maxHeight: CGFloat) -> CGRect {
            let size = image.size
            guard size.width > 0, size.height > 0 else {
                return CGRect(x: 0, y: -4, width: maxWidth, height: 120)
            }

            let scale = min(1, maxWidth / size.width, maxHeight / size.height)
            return CGRect(
                x: 0,
                y: -4,
                width: size.width * scale,
                height: size.height * scale
            )
        }
    }
}

private final class ImageTextAttachment: NSTextAttachment {
    let url: URL

    init(url: URL) {
        self.url = url
        super.init(data: nil, ofType: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class InlineImageTextView: NSTextView {
    var onImagePaste: ((URL) -> Void)?

    override func mouseDown(with event: NSEvent) {
        if let url = imageURL(at: event) {
            ImagePreviewWindowController.shared.showImage(at: url)
            return
        }
        super.mouseDown(with: event)
    }

    override func paste(_ sender: Any?) {
        let urls = importImagesFromPasteboard()
        if !urls.isEmpty {
            urls.forEach { onImagePaste?($0) }
            return
        }
        super.paste(sender)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            selectAll(nil)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private func importImagesFromPasteboard() -> [URL] {
        let pasteboard = NSPasteboard.general

        let files = pasteboard.pasteboardItems?.compactMap { item -> URL? in
            guard let urlString = item.string(forType: .fileURL),
                  let url = URL(string: urlString) else {
                return nil
            }
            return importImageFile(at: url)
        } ?? []
        if !files.isEmpty {
            return files
        }

        if let data = pasteboard.data(forType: .png) {
            return savePastedImageData(data, preferredExtension: "png").map { [$0] } ?? []
        }
        if let data = pasteboard.data(forType: .tiff) {
            return savePastedImageData(data, preferredExtension: "tiff").map { [$0] } ?? []
        }
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            return savePastedImageData(data, preferredExtension: "jpg").map { [$0] } ?? []
        }
        if let image = NSImage(pasteboard: pasteboard),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return savePastedImageData(png, preferredExtension: "png").map { [$0] } ?? []
        }

        return []
    }

    private func imageURL(at event: NSEvent) -> URL? {
        guard let layoutManager, let textContainer, let storage = textStorage else { return nil }

        var point = convert(event.locationInWindow, from: nil)
        point.x -= textContainerOrigin.x
        point.y -= textContainerOrigin.y

        let characterIndex = layoutManager.characterIndex(
            for: point,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        let indexes = [characterIndex, characterIndex - 1, characterIndex + 1]

        for index in indexes where index >= 0 && index < storage.length {
            if let attachment = storage.attribute(.attachment, at: index, effectiveRange: nil) as? ImageTextAttachment {
                return attachment.url
            }
        }

        return nil
    }
}

private final class ImagePreviewWindowController {
    static let shared = ImagePreviewWindowController()
    private var window: NSWindow?

    func showImage(at url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }

        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = NSRect(origin: .zero, size: image.size)
        imageView.autoresizingMask = [.width, .height]

        let scrollView = NSScrollView()
        scrollView.documentView = imageView
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let naturalSize = image.size
        let width = min(max(naturalSize.width, 420), 900)
        let height = min(max(naturalSize.height, 320), 700)

        let window = self.window ?? NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = url.lastPathComponent
        window.contentView = scrollView
        window.setContentSize(NSSize(width: width, height: height))
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}

private func savePastedImageData(_ data: Data, preferredExtension ext: String) -> URL? {
    let fm = FileManager.default
    do {
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "HoverText"
        let dir = appSupport.appendingPathComponent(bundleID, isDirectory: true).appendingPathComponent("Images", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).\(ext)"
        let url = dir.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    } catch {
        NSLog("[HoverText] Failed to save pasted image: \(String(describing: error))")
        return nil
    }
}

private func importImageFile(at sourceURL: URL) -> URL? {
    let ext = sourceURL.pathExtension.lowercased()
    if ["png", "jpg", "jpeg", "tif", "tiff", "gif", "bmp", "heic"].contains(ext),
       let data = try? Data(contentsOf: sourceURL) {
        let normalized: String
        switch ext {
        case "jpeg": normalized = "jpg"
        case "tif": normalized = "tiff"
        default: normalized = ext
        }
        return savePastedImageData(data, preferredExtension: normalized)
    }
    if let image = NSImage(contentsOf: sourceURL),
       let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        return savePastedImageData(png, preferredExtension: "png")
    }
    return nil
}

#Preview {
    CaptureView(viewModel: CaptureViewModel(), onCloseWithoutSave: {}, onSaveAndNew: {}, onImageInserted: { _ in })
}
