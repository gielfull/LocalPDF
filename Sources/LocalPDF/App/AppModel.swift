import Foundation
import Observation
import PDFEngine

/// App-wide navigation state: the sidebar selection, tool search, the files staged on
/// the home drop zone, and one `ToolSession` per tool.
@Observable
final class AppModel {
    var selection: SidebarItem? = .home
    var searchText = ""
    /// Drives the Add Files open panel.
    var isImporting = false

    /// Files dropped or opened on the home screen, awaiting a suggestion pick.
    private(set) var staged: [SourceFile] = []
    private(set) var isStaging = false

    let queue: JobQueue
    let preferences: Preferences

    @ObservationIgnored private var sessions: [ToolID: ToolSession] = [:]

    init(queue: JobQueue, preferences: Preferences) {
        self.queue = queue
        self.preferences = preferences
        #if DEBUG
        // `-LPDFOpenTool <ToolID>` opens a tool at launch, so a layout can be checked in a
        // background instance (`open -n -g … --args -LPDFOpenTool organize`) without
        // clicking through the UI.
        if let raw = UserDefaults.standard.string(forKey: "LPDFOpenTool"), let tool = ToolID(rawValue: raw) {
            selection = .tool(tool)
        }
        #endif
    }

    // MARK: Tools

    /// The tool's session, created on first use and kept so its files survive navigation.
    func session(for tool: ToolID) -> ToolSession {
        if let session = sessions[tool] { return session }
        let session = ToolSession(tool: tool, queue: queue, preferences: preferences)
        sessions[tool] = session
        return session
    }

    func open(_ tool: ToolID) {
        selection = .tool(tool)
    }

    /// Opens `tool` with the subset of `files` it accepts preloaded.
    func open(_ tool: ToolID, with files: [SourceFile]) {
        session(for: tool).replaceFiles(with: SmartSuggestions.files(files, for: tool))
        selection = .tool(tool)
    }

    /// "Continue with…": feeds a job's results into the next tool.
    func open(_ tool: ToolID, withOutputs outputs: [SavedOutput]) async {
        open(tool, with: await SourceFile.load(outputs.map(\.url)))
    }

    var selectedTool: ToolID? {
        if case .tool(let tool) = selection { tool } else { nil }
    }

    // MARK: Search

    func matchesSearch(_ tool: ToolDescriptor) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return tool.title.localizedStandardContains(query)
            || tool.summary.localizedStandardContains(query)
            || tool.category.style.title.localizedStandardContains(query)
    }

    /// The category's tools that match the search.
    func tools(in category: ToolCategory) -> [ToolDescriptor] {
        ToolCatalog.tools(in: category).filter(matchesSearch)
    }

    // MARK: Files

    func addFiles() {
        isImporting = true
    }

    /// Open-panel results go to the tool on screen, or to the home suggestions.
    func importFiles(_ urls: [URL]) {
        holdAccess(to: urls)

        if let tool = selectedTool, ToolCatalog.descriptor(for: tool).isAvailable {
            Task { await session(for: tool).add(urls) }
        } else {
            receive(urls)
        }
    }

    /// Files from Finder: Open With and the Dock go to the home suggestions, a Quick
    /// Action straight into its tool (see `FinderAction.destination(for:)`).
    func perform(_ action: FinderAction, with urls: [URL]) {
        guard !urls.isEmpty else { return }
        holdAccess(to: urls)
        guard action.tool != nil else {
            receive(urls)
            return
        }
        Task {
            let files = await SourceFile.load(urls)
            switch action.destination(for: files) {
            case .tool(let tool, let accepted):
                searchText = ""
                open(tool, with: accepted)
            case .home:
                receive(urls)
            }
        }
    }

    /// A grant that arrives with the URLs (open panel, a Service's pasteboard) is
    /// security-scoped; hold it for as long as the app runs so the file stays usable in
    /// any tool. Jobs take their own balanced access too. URLs without one are skipped.
    private func holdAccess(to urls: [URL]) {
        for url in urls { _ = url.startAccessingSecurityScopedResource() }
    }

    /// Files dropped on the home screen or opened from Finder or the Dock.
    func receive(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        #if DEBUG
        // With `-LPDFOpenTool`, files opened at launch go straight into that tool
        // (`open -n -g -a LocalPDF.app file.pdf --args -LPDFOpenTool split`).
        if let raw = UserDefaults.standard.string(forKey: "LPDFOpenTool"), let tool = ToolID(rawValue: raw) {
            Task { open(tool, with: await SourceFile.load(urls)) }
            return
        }
        #endif
        selection = .home
        searchText = ""
        isStaging = true
        Task {
            staged = await SourceFile.load(urls).filter { $0.kind != .other }
            isStaging = false
        }
    }

    func clearStaged() {
        staged = []
    }

    var suggestions: [ToolID] { SmartSuggestions.tools(for: staged) }
}
