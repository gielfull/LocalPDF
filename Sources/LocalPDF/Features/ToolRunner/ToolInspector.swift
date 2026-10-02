import PDFEngine
import SwiftUI

/// The inspector column: the tool's options, where results go, and the primary action.
struct ToolInspector: View {
    @Bindable var session: ToolSession
    @Environment(Preferences.self) private var preferences

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    ToolIcon(systemImage: session.descriptor.systemImage, tint: session.descriptor.tint, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.descriptor.title)
                            .font(.headline)
                        Text(session.descriptor.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            options

            Section("Output") {
                LabeledContent("Save to") {
                    Text(preferences.outputFolderDisplayPath)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(preferences.outputFolder.path(percentEncoded: false))
                }
                SettingsLink {
                    Text("Change Output Folder…")
                }
                .buttonStyle(.link)
            }
        }
        .formStyle(.grouped)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PrimaryActionBar(session: session)
        }
    }

    @ViewBuilder
    private var options: some View {
        switch session.tool {
        case .merge: MergeOptions(session: session)
        case .split: SplitOptions(session: session)
        case .removePages: RemovePagesOptions(session: session)
        case .extractPages: ExtractPagesOptions(session: session)
        case .organize: OrganizeOptions(session: session)
        case .compress: CompressOptions(session: session)
        case .rotate: RotateOptions(session: session)
        case .pageNumbers: PageNumbersOptions(session: session)
        case .watermark: WatermarkOptions(session: session)
        case .crop: CropOptions(session: session)
        case .imagesToPDF: ImagesToPDFOptions(session: session)
        case .pdfToImages: PDFToImagesOptions(session: session)
        case .protect: ProtectOptions(session: session)
        case .unlock: UnlockOptions(session: session)
        case .repair: RepairOptions(session: session)
        case .ocr: OCROptions(session: session)
        default: EmptyView()
        }
    }
}
