import PDFEngine

/// A destination in the sidebar.
enum SidebarItem: Hashable {
    case home
    case tool(ToolID)
    case workflows
    case history
}
