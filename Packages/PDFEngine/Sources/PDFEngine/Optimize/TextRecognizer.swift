import CoreGraphics
import Foundation
import Vision

/// OCR's recognition step: Vision on one page image, results mapped to reader space.
///
/// `.accurate` uses `RecognizeDocumentsRequest` (lines in reading order, from Vision's
/// document model); `.fast` uses `RecognizeTextRequest` at its fast level. Both report
/// `RecognizedTextObservation` lines, so everything after the request is shared.
struct TextRecognizer: Sendable {
    /// The level actually used: `.fast` only knows a few Latin-script languages, so asking
    /// for any other language upgrades the request to `.accurate`.
    let accuracy: OCROperation.Accuracy
    /// Vision's own values for the requested languages; empty means automatic detection.
    let languages: [Locale.Language]

    /// Text shorter than this (in points, on the page as displayed) is ignored. Vision's
    /// default, 1/32 of the image height, would drop body text and footnotes.
    static let minimumTextHeight: CGFloat = 4

    init(options: OCROperation.Options) {
        let languages = Self.resolve(options.languages, among: Self.supported(for: .accurate))
        let fastLanguages = Self.supported(for: .fast)
        self.languages = languages
        self.accuracy = options.accuracy == .fast && languages.allSatisfy(fastLanguages.contains)
            ? .fast : .accurate
    }

    /// The lines Vision finds in `image`, which shows a page of `readerSize` points.
    /// - Throws: `.cancelled` when the task is cancelled, `.recognitionFailed(url)` when
    ///   Vision fails.
    func recognize(_ image: CGImage, readerSize: CGSize, of url: URL) async throws -> [RecognizedLine] {
        let minimumHeight = Float(min(max(Self.minimumTextHeight / max(readerSize.height, 1), 0.001), 1.0 / 32))
        let observations: [RecognizedTextObservation]
        do {
            switch accuracy {
            case .accurate:
                var request = RecognizeDocumentsRequest()
                request.barcodeDetectionOptions.enabled = false
                request.textRecognitionOptions.minimumTextHeightFraction = minimumHeight
                if !languages.isEmpty {
                    request.textRecognitionOptions.automaticallyDetectLanguage = false
                    request.textRecognitionOptions.recognitionLanguages = languages
                }
                observations = try await request.perform(on: image).flatMap(\.document.text.lines)
            case .fast:
                var request = RecognizeTextRequest()
                request.recognitionLevel = .fast
                request.minimumTextHeightFraction = minimumHeight
                if !languages.isEmpty {
                    request.automaticallyDetectsLanguage = false
                    request.recognitionLanguages = languages
                }
                observations = try await request.perform(on: image)
            }
        } catch {
            if Task.isCancelled || error is CancellationError { throw PDFEngineError.cancelled }
            throw PDFEngineError.recognitionFailed(url)
        }
        return observations.compactMap { Self.line(from: $0, readerSize: readerSize) }
    }

    // MARK: - Languages

    /// Vision's recognition languages for `accuracy`.
    static func supported(for accuracy: OCROperation.Accuracy) -> [Locale.Language] {
        switch accuracy {
        case .accurate:
            return RecognizeDocumentsRequest().supportedRecognitionLanguages
        case .fast:
            var request = RecognizeTextRequest()
            request.recognitionLevel = .fast
            return request.supportedRecognitionLanguages
        }
    }

    /// A short BCP-47 tag for one of Vision's languages: language plus region ("en-US",
    /// "ja-JP"), or plus script where Vision gives no region ("zh-Hans", "zh-Hant").
    static func identifier(for language: Locale.Language) -> String {
        let components = Locale.Language.Components(language: language)
        let code = components.languageCode?.identifier ?? language.maximalIdentifier
        if let region = components.region?.identifier { return "\(code)-\(region)" }
        if let script = components.script?.identifier { return "\(code)-\(script)" }
        return code
    }

    /// Maps user-facing tags onto Vision's languages, keeping their order. A tag matches
    /// exactly, else by its maximal form ("en" is "en-Latn-US"), else by language and
    /// script ("pt-PT" falls back to Vision's Portuguese). Unknown tags are dropped.
    static func resolve(_ tags: [String], among supported: [Locale.Language]) -> [Locale.Language] {
        var result: [Locale.Language] = []
        for tag in tags {
            let requested = Locale.Language(identifier: tag)
            let requestedCode = Locale.Language.Components(language: requested)
            let match = supported.first { identifier(for: $0).caseInsensitiveCompare(tag) == .orderedSame }
                ?? supported.first { $0.maximalIdentifier == requested.maximalIdentifier }
                ?? supported.first {
                    let components = Locale.Language.Components(language: $0)
                    return components.languageCode == requestedCode.languageCode
                        && components.script == requestedCode.script
                }
            if let match, !result.contains(match) { result.append(match) }
        }
        return result
    }

    // MARK: - Mapping

    /// A word box this wide, relative to its line, is suspicious: Vision sometimes reports
    /// the whole line's box for every word. The line is then drawn as one run.
    private static let maximumWordShare: CGFloat = 0.9

    private static func line(from observation: RecognizedTextObservation, readerSize: CGSize) -> RecognizedLine? {
        guard let candidate = observation.topCandidates(1).first else { return nil }
        let text = candidate.string
        guard !text.allSatisfy(\.isWhitespace) else { return nil }
        let lineQuad = quad(observation, readerSize: readerSize)
        let lineRun = RecognizedLine.Run(text: text.trimmingCharacters(in: .whitespaces), quad: lineQuad)

        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > 1 else { return RecognizedLine(text: text, runs: [lineRun]) }
        var runs: [RecognizedLine.Run] = []
        for word in words {
            guard let box = candidate.boundingBox(for: word.startIndex..<word.endIndex) else {
                return RecognizedLine(text: text, runs: [lineRun])
            }
            let wordQuad = quad(box, readerSize: readerSize)
            guard wordQuad.width < lineQuad.width * maximumWordShare else {
                return RecognizedLine(text: text, runs: [lineRun])
            }
            runs.append(RecognizedLine.Run(text: String(word), quad: wordQuad))
        }
        return RecognizedLine(text: text, runs: runs)
    }

    private static func quad(_ box: some QuadrilateralProviding, readerSize: CGSize) -> RecognizedLine.Quad {
        RecognizedLine.Quad(
            bottomLeft: box.bottomLeft.toImageCoordinates(readerSize, origin: .lowerLeft),
            bottomRight: box.bottomRight.toImageCoordinates(readerSize, origin: .lowerLeft),
            topRight: box.topRight.toImageCoordinates(readerSize, origin: .lowerLeft),
            topLeft: box.topLeft.toImageCoordinates(readerSize, origin: .lowerLeft)
        )
    }
}
