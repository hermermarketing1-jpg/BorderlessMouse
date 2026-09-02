import AppKit
import Foundation

/// Obserwuje NSPasteboard (po `changeCount`, co 0,5 s) i pozwala ustawić
/// schowek z zewnątrz bez odsyłania własnej zmiany z powrotem.
final class ClipboardSync {
    /// Wołane na wątku głównym.
    var onLocalChange: ((String) -> Void)?

    private let pasteboard = NSPasteboard.general
    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int
    private var lastText: String?

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        DispatchQueue.main.async {
            guard self.timer == nil else { return }
            self.lastChangeCount = self.pasteboard.changeCount
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.schedule(deadline: .now() + 0.5, repeating: 0.5, leeway: .milliseconds(100))
            t.setEventHandler { [weak self] in self?.poll() }
            t.resume()
            self.timer = t
        }
    }

    func stop() {
        DispatchQueue.main.async {
            self.timer?.cancel()
            self.timer = nil
        }
    }

    /// Ustawia schowek tekstem z drugiego komputera.
    func apply(_ text: String) {
        DispatchQueue.main.async {
            self.pasteboard.clearContents()
            self.pasteboard.setString(text, forType: .string)
            self.lastChangeCount = self.pasteboard.changeCount
            self.lastText = text
        }
    }

    private func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard let text = pasteboard.string(forType: .string), !text.isEmpty,
              text.utf8.count <= ProtocolConstants.maxClipboardBytes,
              text != lastText else { return }
        lastText = text
        onLocalChange?(text)
    }
}
