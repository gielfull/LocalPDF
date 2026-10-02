import PDFEngine
import SwiftUI

/// The main window: sidebar, the selected destination, the toolbar, and the window's
/// sheets (results, passwords) and open panel.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(JobQueue.self) private var queue

    @State private var showsQueue = false

    var body: some View {
        @Bindable var model = model
        @Bindable var queue = queue
        NavigationSplitView {
            SidebarView()
        } detail: {
            detail
                .sheet(item: $queue.passwordRequest) { request in
                    PasswordSheet(request: request)
                }
        }
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search tools")
        .searchToolbarBehavior(.automatic)
        .toolbar { toolbar }
        .fileImporter(isPresented: $model.isImporting, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { model.importFiles(urls) }
        }
        .sheet(item: $queue.presentedJob) { job in
            ResultSheet(job: job) { tool, outputs in
                Task { await model.open(tool, withOutputs: outputs) }
            } onRetry: {
                queue.retry(job)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection ?? .home {
        case .home:
            HomeView(
                staged: model.staged, isStaging: model.isStaging, suggestions: model.suggestions,
                searchText: model.searchText, tools: model.tools(in:),
                onOpenTool: model.open, onPickSuggestion: { model.open($0, with: model.staged) },
                onDrop: model.receive, onAddFiles: model.addFiles, onClearStaged: model.clearStaged
            )
        case .tool(let id):
            let tool = ToolCatalog.descriptor(for: id)
            if tool.isAvailable {
                ToolView(session: model.session(for: id), onAddFiles: model.addFiles)
                    .id(id)
            } else {
                ComingSoonView(tool: tool) { model.selection = .home }
            }
        case .workflows:
            PlaceholderView(
                title: "Workflows", systemImage: "gearshape.2",
                message: "Chain tools like OCR → Compress → Protect and run them on files or a watched folder. Coming soon."
            )
        case .history:
            PlaceholderView(
                title: "History", systemImage: "clock.arrow.circlepath",
                message: "A record of everything you've processed, to reopen or run again. Coming soon. Recent tasks are in the Activity menu in the toolbar."
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Button {
                showsQueue.toggle()
            } label: {
                Label("Activity", systemImage: queue.runningCount > 0 ? "arrow.triangle.2.circlepath" : "tray.full")
                    .symbolEffect(.rotate, isActive: queue.runningCount > 0)
                    .symbolEffect(.bounce, value: queue.completions)
            }
            .badge(queue.runningCount)
            .help("Activity")
            .popover(isPresented: $showsQueue, arrowEdge: .bottom) {
                QueuePopover(queue: queue)
            }
        }
        ToolbarSpacer(.fixed)
        ToolbarItem {
            Button("Add Files", systemImage: "plus", action: model.addFiles)
                .labelStyle(.titleAndIcon)
                .help("Add Files (⌘O)")
        }
    }
}
