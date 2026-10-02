import SwiftUI

/// Before → after size with the percentage saved, for Compress results.
///
/// When `isRevealed` turns on, a bar shrinks from the original size to the new one and
/// the percentage rolls up from zero, so the saving reads as something that just happened.
struct SavingsSummary: View {
    let before: Int64
    let after: Int64
    var isRevealed = true

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                sizeColumn("Before", before)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                sizeColumn("After", after)
                Spacer()
                verdict
            }
            if saved > 0.005 {
                shrinkBar
            }
        }
        .padding(14)
        .background(.fill.quinary, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var saved: Double {
        guard before > 0 else { return 0 }
        return max(0, Double(before - after) / Double(before))
    }

    private var shown: Double { isRevealed ? saved : 0 }

    @ViewBuilder
    private var verdict: some View {
        if saved > 0.005 {
            HStack(spacing: 4) {
                Text(shown, format: .percent.precision(.fractionLength(0)))
                    .contentTransition(.numericText(value: shown))
                Text("smaller")
            }
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.green)
            .animation(.smooth(duration: 0.9).delay(0.25), value: isRevealed)
        } else {
            Text("Already optimized")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    /// The full width is the original file; the green part is what's left.
    private var shrinkBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.fill.tertiary)
                Capsule()
                    .fill(.green.gradient)
                    .frame(width: max(6, proxy.size.width * (1 - shown)))
            }
        }
        .frame(height: 6)
        .animation(.spring(duration: 1.0, bounce: 0.15).delay(0.25), value: isRevealed)
        .accessibilityHidden(true)
    }

    private var accessibilityText: String {
        let sizes = "\(before.formatted(.byteCount(style: .file))) to \(after.formatted(.byteCount(style: .file)))"
        guard saved > 0.005 else { return "\(sizes), already optimized" }
        return "\(sizes), \(saved.formatted(.percent.precision(.fractionLength(0)))) smaller"
    }

    private func sizeColumn(_ title: String, _ bytes: Int64) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(bytes.formatted(.byteCount(style: .file)))
                .font(.headline)
                .monospacedDigit()
        }
    }
}
