import PDFEngine

/// The result sheet's note that the saved PDFs aren't protected the way the inputs were.
///
/// Most tools rebuild the PDF and write it unencrypted, even from a password-protected
/// or permission-restricted input. Protect sets encryption and Compress keeps it, so they
/// never need the note; Unlock removes it on purpose.
nonisolated struct ProtectionNotice: Equatable, Sendable {
    /// Tools whose output is already protected as intended.
    static let exemptTools: Set<ToolID> = [.protect, .compress, .unlock, .repair]

    let message: String

    /// Nil when there's nothing to say: no protected input, an exempt tool, or outputs
    /// that aren't PDFs (images can't carry a password, so Protect PDF can't follow).
    init?(tool: ToolID, protection: JobRequest.Protection, inputCount: Int, outputs: [SavedOutput]) {
        guard protection != .unprotected, !Self.exemptTools.contains(tool),
              !outputs.isEmpty, outputs.allSatisfy(\.isPDF) else { return nil }

        let single = outputs.count == 1
        let original = inputCount == 1 ? "The original" : "A file you added"
        message = switch protection {
        case .password:
            "\(original) was password-protected. \(single ? "This copy isn't." : "These copies aren't.")"
        case .restrictions, .unprotected:
            "\(original) had permission restrictions. \(single ? "This copy doesn't." : "These copies don't.")"
        }
    }
}
