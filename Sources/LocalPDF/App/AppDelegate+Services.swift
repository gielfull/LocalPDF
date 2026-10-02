import AppKit

/// Finder's Quick Actions for the app. They are Services: `project.yml`
/// declares each one under `NSServices`, Finder lists it for matching files, and AppKit
/// calls the method named by its `NSMessage` on `NSApp.servicesProvider` (the delegate),
/// on the main thread, with the selected files on the pasteboard.
///
/// The selectors are spelled out so they can't drift from the `NSMessage` values, which
/// are `FinderAction`'s raw values; a test checks every Service has its method.
extension AppDelegate {
    @objc(openInLocalPDF:userData:error:)
    func openInLocalPDF(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        perform(.open, from: pasteboard, error: error)
    }

    @objc(compressWithLocalPDF:userData:error:)
    func compressWithLocalPDF(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        perform(.compress, from: pasteboard, error: error)
    }

    @objc(mergeWithLocalPDF:userData:error:)
    func mergeWithLocalPDF(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        perform(.merge, from: pasteboard, error: error)
    }

    @objc(convertImagesToPDFWithLocalPDF:userData:error:)
    func convertImagesToPDFWithLocalPDF(
        _ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        perform(.imagesToPDF, from: pasteboard, error: error)
    }

    /// Reads the selected files, in Finder's order, and hands them to the model. The
    /// sandbox grants access to files passed this way; the model holds it like it does
    /// for the open panel.
    private func perform(
        _ action: FinderAction, from pasteboard: NSPasteboard, error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        let urls = (objects as? [URL]) ?? []
        guard !urls.isEmpty else {
            error?.pointee = "LocalPDF didn't receive any files." as NSString
            return
        }
        deliver(action, urls)
        // The user just picked this in Finder, so coming forward is expected.
        bringMainWindowForward()
    }
}
