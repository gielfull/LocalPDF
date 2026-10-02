import Foundation
import PDFEngine
import Testing
import UniformTypeIdentifiers
@testable import LocalPDF

@Suite("Finder Quick Actions")
struct FinderActionTests {
    @Test("Each Service message names its action; unknown messages don't")
    func messages() {
        #expect(FinderAction(rawValue: "compressWithLocalPDF") == .compress)
        #expect(FinderAction(rawValue: "mergeWithLocalPDF") == .merge)
        #expect(FinderAction(rawValue: "convertImagesToPDFWithLocalPDF") == .imagesToPDF)
        #expect(FinderAction(rawValue: "openInLocalPDF") == .open)
        #expect(FinderAction(rawValue: "shredWithLocalPDF") == nil)
    }

    @Test("Merge takes every PDF in Finder's order and skips the rest")
    func mergeKeepsOrder() {
        let c = SourceFile.fixture("c.pdf")
        let a = SourceFile.fixture("a.pdf")
        let image = SourceFile.fixture("photo.png", kind: .image)
        let b = SourceFile.fixture("b.pdf")
        #expect(FinderAction.merge.destination(for: [c, a, image, b]) == .tool(.merge, [c, a, b]))
    }

    @Test("Compress takes every PDF")
    func compressTakesPDFs() {
        let a = SourceFile.fixture("a.pdf")
        let b = SourceFile.fixture("b.pdf", encrypted: true)
        #expect(FinderAction.compress.destination(for: [a, b]) == .tool(.compress, [a, b]))
    }

    @Test("Convert Images to PDF takes the images, in order")
    func imagesTakesImages() {
        let pdf = SourceFile.fixture("a.pdf")
        let one = SourceFile.fixture("1.heic", kind: .image)
        let two = SourceFile.fixture("2.jpg", kind: .image)
        #expect(FinderAction.imagesToPDF.destination(for: [two, pdf, one]) == .tool(.imagesToPDF, [two, one]))
    }

    @Test("Open goes to the home screen's suggestions")
    func openGoesHome() {
        #expect(FinderAction.open.tool == nil)
        #expect(FinderAction.open.destination(for: [.fixture("a.pdf")]) == .home)
    }

    @Test("Files the tool can't take fall back to the home screen")
    func nothingAcceptedGoesHome() {
        let text = SourceFile.fixture("notes.txt", kind: .other)
        #expect(FinderAction.compress.destination(for: [text]) == .home)
        #expect(FinderAction.merge.destination(for: []) == .home)
    }

    @Test("A tool that isn't available falls back to the home screen")
    func unavailableToolGoesHome() {
        let files = [SourceFile.fixture("a.pdf"), .fixture("b.pdf")]
        #expect(FinderAction.merge.destination(for: files, isAvailable: { _ in false }) == .home)
        #expect(FinderAction.merge.destination(for: files, isAvailable: { $0 == .merge }) == .tool(.merge, files))
    }

    @Test("Every action's tool is available today")
    func toolsAreAvailable() {
        for action in FinderAction.allCases {
            if let tool = action.tool {
                #expect(ToolCatalog.descriptor(for: tool).isAvailable, "\(action) opens \(tool)")
            }
        }
    }

    @Test("Info.plist declares exactly these Services, each wired to a delegate method")
    func infoPlistMatches() throws {
        // Hosted tests run inside the app, so the main bundle is LocalPDF.app.
        let services = try #require(Bundle.main.infoDictionary?["NSServices"] as? [[String: Any]])
        let messages = services.compactMap { $0["NSMessage"] as? String }
        #expect(Set(messages) == Set(FinderAction.allCases.map(\.rawValue)))
        #expect(messages.count == services.count)

        let delegate = AppDelegate()
        for service in services {
            let message = try #require(service["NSMessage"] as? String)
            let action = try #require(FinderAction(rawValue: message))
            #expect(delegate.responds(to: Selector("\(message):userData:error:")), "\(message) has no method")
            let types = try #require(service["NSSendFileTypes"] as? [String])
            #expect(types == action.acceptedTypes.map(\.identifier), "\(message) file types")
            #expect(service["NSRequiredContext"] is [String: Any], "\(message) is on by default")
            let title = try #require((service["NSMenuItem"] as? [String: String])?["default"])
            #expect(!title.contains("$("), "\(message) title expanded")
            #expect(title.hasSuffix(Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "LocalPDF"))
        }
    }
}
