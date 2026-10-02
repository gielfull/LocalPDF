import AppKit
import PDFEngine
import QuickLook
import SwiftUI

/// After a job: the saved files with Quick Look / Open / Reveal, a before/after size for
/// Compress, and "Continue with…" chips that feed the results into the next tool.
/// A failed job shows its error here instead, with Try Again.
struct ResultSheet: View {
    let job: Job
    let onContinue: (ToolID, [SavedOutput]) -> Void
    let onRetry: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var previewURL: URL?
    /// Turns on right after the sheet appears, so its parts animate into place in turn.
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if case .failed(let message) = job.state {
                Text(message)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if job.request.tool == .compress {
                    SavingsSummary(before: job.request.inputByteCount, after: job.outputByteCount,
                                   isRevealed: appeared)
                        .staggeredAppear(index: 1, isVisible: appeared)
                }
                outputList
                    .staggeredAppear(index: 2, isVisible: appeared)
                protectionCard
                    .staggeredAppear(index: 3, isVisible: appeared)
                continueChips
                    .staggeredAppear(index: 3, isVisible: appeared)
            }
            footer
        }
        .padding(24)
        .frame(width: 520)
        .quickLookPreview($previewURL, in: job.outputs.map(\.url))
        .task { appeared = true }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ToolIcon(systemImage: job.tool.systemImage, tint: job.tool.tint, size: 44)
                .overlay(alignment: .bottomTrailing) { outcomeBadge }
                .scaleEffect(appeared ? 1 : 0.7)
                .animation(.spring(duration: 0.5, bounce: 0.45), value: appeared)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// A checkmark (or exclamation mark) drawn onto the tool icon as the sheet opens.
    @ViewBuilder
    private var outcomeBadge: some View {
        if appeared {
            let failed = if case .failed = job.state { true } else { false }
            Image(systemName: failed ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, failed ? Color.red : Color.green)
                .background(Circle().fill(.background).padding(1))
                .offset(x: 7, y: 7)
                .transition(.symbolEffect(.drawOn))
                .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)
        }
    }

    private var title: String {
        switch job.state {
        case .failed: "\(job.tool.title) didn't finish"
        default: "\(job.tool.title) is done"
        }
    }

    private var subtitle: String {
        if case .failed = job.state { return job.inputSummary }
        let count = job.outputs.count
        let folder = job.outputs.first?.url.deletingLastPathComponent().lastPathComponent ?? ""
        return "\(count) \(count == 1 ? "file" : "files") saved to \u{201C}\(folder)\u{201D}"
    }

    private var outputList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(job.outputs.enumerated()), id: \.element.id) { index, output in
                    ResultFileRow(
                        thumbnail: output.thumbnail, name: output.name, byteCount: output.byteCount,
                        onQuickLook: { previewURL = output.url },
                        onOpen: { NSWorkspace.shared.open(output.url) },
                        onReveal: { NSWorkspace.shared.activateFileViewerSelecting([output.url]) }
                    )
                    .staggeredAppear(index: 3 + index, isVisible: appeared, step: 0.04)
                    if output != job.outputs.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 240)
        .fixedSize(horizontal: false, vertical: true)
        .background(.fill.quinary, in: .rect(cornerRadius: 12))
    }

    /// Says so when the outputs lost the inputs' password or restrictions, and offers
    /// Protect PDF right there, continuing with the outputs like the chips do.
    @ViewBuilder
    private var protectionCard: some View {
        let protect = ToolCatalog.descriptor(for: .protect)
        if let notice = protectionNotice {
            ProtectionDroppedCard(
                message: notice.message, actionTitle: protect.title, actionImage: protect.systemImage,
                tint: protect.tint
            ) {
                onContinue(.protect, job.outputs)
                dismiss()
            }
        }
    }

    private var protectionNotice: ProtectionNotice? {
        guard ToolCatalog.descriptor(for: .protect).isAvailable else { return nil }
        return ProtectionNotice(
            tool: job.request.tool, protection: job.request.inputProtection,
            inputCount: job.request.inputs.count, outputs: job.outputs
        )
    }

    @ViewBuilder
    private var continueChips: some View {
        let tools = continueTools
        if !tools.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue with…")
                    .font(.headline)
                GlassEffectContainer(spacing: 8) {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(tools.enumerated()), id: \.element) { index, tool in
                            ToolChip(tool: ToolCatalog.descriptor(for: tool)) {
                                onContinue(tool, job.outputs)
                                dismiss()
                            }
                            .staggeredAppear(index: 5 + index, isVisible: appeared, step: 0.035)
                        }
                    }
                }
            }
        }
    }

    /// Next steps that take these outputs, excluding the tool that just ran (and Protect
    /// when the protection card already offers it).
    private var continueTools: [ToolID] {
        let candidates: [ToolID] = job.outputs.allSatisfy(\.isPDF)
            ? [.compress, .protect, .ocr, .merge, .rotate, .pageNumbers, .watermark, .split, .organize]
            : [.imagesToPDF]
        let offered: ToolID? = protectionNotice == nil ? nil : .protect
        return candidates.filter { $0 != job.request.tool && $0 != offered }
    }

    private var footer: some View {
        HStack {
            if case .failed = job.state {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Try Again") {
                    dismiss()
                    onRetry()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting(job.outputs.map(\.url))
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
    }
}
