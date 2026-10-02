/// Split's mode, flattened so the inspector can bind a picker to it; `SplitOperation.Mode`
/// carries payloads, which a picker can't select between.
enum SplitModeKind: String, CaseIterable, Identifiable {
    case ranges, everyN, eachPage

    var id: Self { self }

    var title: String {
        switch self {
        case .ranges: "Ranges"
        case .everyN: "Fixed"
        case .eachPage: "Every Page"
        }
    }
}
