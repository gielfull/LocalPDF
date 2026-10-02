// swift-tools-version: 6.2
import PackageDescription

// PDFEngine: every LocalPDF tool, as pure Swift with no UI imports.
//
// Deliberately NO `.defaultIsolation(MainActor.self)` here, unlike the app target.
// The engine is nonisolated and Sendable so jobs run off the main actor, and so the
// same code can move into the XPC worker and the `localpdf` CLI unchanged.
let package = Package(
    name: "PDFEngine",
    platforms: [
        .macOS("27.0"),
    ],
    products: [
        .library(name: "PDFEngine", targets: ["PDFEngine"]),
    ],
    targets: [
        .target(
            name: "PDFEngine",
            dependencies: ["CQPDF"]
        ),

        // qpdf 12.4.2 (Apache-2.0), vendored as source. Why a dependency: PDFKit can't
        // rebuild a damaged file's cross-reference table, write object streams, recompress
        // or deduplicate streams, or encrypt with AES-256. qpdf does all of that
        // offline, in-process, and is permissively licensed. Swift calls it only through its
        // C API (include/qpdf/qpdf-c.h) plus a few LocalPDF additions
        // (include/qpdf-c-localpdf.h), so no C++ interop is needed. Built with qpdf's own
        // ("native") crypto provider: no OpenSSL or GnuTLS. zlib comes from the macOS SDK.
        // Recreate with Scripts/vendor-qpdf.sh; licenses in THIRD_PARTY_NOTICES.md.
        .target(
            name: "CQPDF",
            dependencies: ["CJPEG"],
            exclude: [
                "LICENSE.txt", "NOTICE.md", "LOCALPDF.md",
                // #included by sha2.c and sha2big.c, never compiled on its own.
                "libqpdf/sph/md_helper.c",
            ],
            cSettings: [
                .headerSearchPath("libqpdf"),
            ],
            cxxSettings: [
                .headerSearchPath("libqpdf"),
                // QTC is qpdf's test-coverage hook; release builds turn it off.
                .define("QPDF_DISABLE_QTC", to: "1"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("c++"),
            ]
        ),

        // IJG libjpeg 10 (IJG license), vendored as source: qpdf's DCT (JPEG) filter
        // needs a libjpeg, and the macOS SDK doesn't ship one. Recreated by the same script.
        .target(
            name: "CJPEG",
            exclude: ["README", "LOCALPDF.md"],
            cSettings: [
                // jpeglib.h includes the private jpegint.h for the library's own sources.
                .headerSearchPath("."),
            ]
        ),

        .testTarget(
            name: "PDFEngineTests",
            // CQPDF directly too: fixtures build and inspect files with qpdf's C API.
            dependencies: ["PDFEngine", "CQPDF"]
        ),
    ],
    swiftLanguageModes: [.v6],
    cxxLanguageStandard: .cxx20
)
