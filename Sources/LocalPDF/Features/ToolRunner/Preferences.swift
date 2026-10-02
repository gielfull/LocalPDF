import AppKit
import Observation
import PDFEngine

/// Where results go and other user defaults, persisted in `UserDefaults`.
///
/// The output folder defaults to `~/Downloads/LocalPDF/`, which the Downloads entitlement
/// covers. A folder the user picks elsewhere is remembered as a security-scoped bookmark,
/// since the sandbox forgets open-panel grants on relaunch.
@Observable
final class Preferences {
    var defaultCompressionLevel: CompressOperation.Level {
        didSet { defaults.set(defaultCompressionLevel.rawValue, forKey: Keys.compressionLevel) }
    }

    /// The folder results are moved to.
    private(set) var outputFolder: URL
    /// Whether `outputFolder` came from a bookmark and needs scoped access to write.
    private(set) var isCustomFolder: Bool
    /// Set when choosing or restoring a folder failed; shown in Settings.
    private(set) var folderError: String?

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaultCompressionLevel = defaults.string(forKey: Keys.compressionLevel)
            .flatMap(CompressOperation.Level.init(rawValue:)) ?? .recommended
        outputFolder = Self.defaultFolder
        isCustomFolder = false
        restoreBookmark()
    }

    /// The real `~/Downloads/LocalPDF`. `FileManager`'s Downloads URL points into the
    /// sandbox container (a symlink), which reads oddly in Finder and in Settings.
    static var defaultFolder: URL {
        let home = getpwuid(getuid())?.pointee.pw_dir.map { String(cString: $0) } ?? NSHomeDirectory()
        return URL(filePath: home, directoryHint: .isDirectory)
            .appending(path: "Downloads", directoryHint: .isDirectory)
            .appending(path: "LocalPDF", directoryHint: .isDirectory)
    }

    /// A `Sendable` snapshot of the destination for a job running off the main actor.
    var destination: OutputDestination {
        OutputDestination(folder: outputFolder, isSecurityScoped: isCustomFolder)
    }

    /// "~/Downloads/LocalPDF" style path for display.
    var outputFolderDisplayPath: String {
        let home = Self.defaultFolder.deletingLastPathComponent().deletingLastPathComponent().path
        let path = outputFolder.path(percentEncoded: false)
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose where LocalPDF saves its results."
        panel.directoryURL = outputFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Keys.folderBookmark)
            outputFolder = url
            isCustomFolder = true
            folderError = nil
        } catch {
            folderError = "LocalPDF can't remember that folder. Results will keep going to Downloads."
        }
    }

    func resetOutputFolder() {
        defaults.removeObject(forKey: Keys.folderBookmark)
        outputFolder = Self.defaultFolder
        isCustomFolder = false
        folderError = nil
    }

    private func restoreBookmark() {
        guard let bookmark = defaults.data(forKey: Keys.folderBookmark) else { return }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
            folderError = "The chosen output folder is no longer available. Results go to Downloads."
            defaults.removeObject(forKey: Keys.folderBookmark)
            return
        }
        if isStale, url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            if let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                defaults.set(fresh, forKey: Keys.folderBookmark)
            }
        }
        outputFolder = url
        isCustomFolder = true
    }

    private enum Keys {
        static let compressionLevel = "defaultCompressionLevel"
        static let folderBookmark = "outputFolderBookmark"
    }
}

