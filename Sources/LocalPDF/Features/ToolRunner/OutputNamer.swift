import Foundation

/// Picks a free file name in the output folder. There is one collision policy:
/// keep both, adding " 2", " 3"… before the extension, the way Finder does.
nonisolated enum OutputNamer {
    /// `name` itself if it's free, else "report 2.pdf", "report 3.pdf"…
    /// - Parameter isTaken: whether a file with that name already exists.
    static func uniqueName(for name: String, isTaken: (String) -> Bool) -> String {
        guard isTaken(name) else { return name }

        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        var number = 2
        while true {
            let candidate = ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
            if !isTaken(candidate) { return candidate }
            number += 1
        }
    }

    /// Strips characters that can't appear in a file name, falling back to "Untitled".
    static func sanitized(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty || cleaned.hasPrefix(".") ? "Untitled\(cleaned)" : cleaned
    }
}
