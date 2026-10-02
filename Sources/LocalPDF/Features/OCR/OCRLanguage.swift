import Foundation
import PDFEngine

/// A language OCR can recognize, as the picker shows it.
nonisolated struct OCRLanguage: Identifiable, Hashable, Sendable {
    /// The engine's BCP-47 tag, e.g. "en-US" or "zh-Hans".
    let id: String
    /// "English", "Chinese, Simplified", in the user's language.
    let name: String

    init(tag: String, locale: Locale = .current) {
        id = tag
        let language = Locale.Language(identifier: tag)
        let code = language.languageCode?.identifier ?? tag
        // The region Vision attaches ("en-US", "fr-FR") is noise in a picker; a script
        // ("zh-Hans" vs "zh-Hant") is what tells two entries apart.
        let hasScript = tag.components(separatedBy: "-").dropFirst().contains(where: { $0.count == 4 })
        name = (hasScript ? locale.localizedString(forIdentifier: tag) : nil)
            ?? locale.localizedString(forLanguageCode: code)
            ?? tag
    }

    /// Every language Vision recognizes on this Mac, by name.
    static let all: [OCRLanguage] = OCROperation.supportedLanguages()
        .map { OCRLanguage(tag: $0) }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    /// The tags Fast recognition knows; others make a run use Accurate.
    static let fastTags = Set(OCROperation.supportedLanguages(for: .fast))

    /// "Automatic", one name, or "English + 2 more" for the picker's label.
    static func summary(of tags: [String]) -> String {
        let names = tags.map { tag in all.first { $0.id == tag }?.name ?? tag }
        switch names.count {
        case 0: return "Automatic"
        case 1: return names[0]
        default: return "\(names[0]) + \(names.count - 1) more"
        }
    }
}
