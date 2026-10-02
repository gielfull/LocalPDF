import SwiftUI

/// The single primary action at the bottom of the inspector (`.glassProminent`, ⌘↩),
/// with the reason it's disabled shown above it.
///
/// The button also tells the job's story, so the result never appears out of nowhere: it
/// fills with progress while the job runs, turns green with a drawn checkmark when it
/// succeeds, and turns red and shakes when it fails, then settles back to its title.
struct PrimaryActionBar: View {
    let session: ToolSession

    @State private var phase = Phase.idle
    @State private var shakes = 0
    @State private var settleTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable {
        case idle
        case running(progress: Double)
        case succeeded
        case failed
    }

    var body: some View {
        VStack(spacing: 10) {
            if let message = session.validationMessage, !session.isRunning {
                if let locked = session.files.first(where: \.needsPassword) {
                    Button("Enter Password for \u{201C}\(locked.name)\u{201D}…", systemImage: "lock.open") {
                        session.requestPassword(for: locked)
                    }
                    .buttonStyle(.link)
                } else {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            actionButton

            if case .running = phase {
                Button("Cancel", role: .cancel, action: session.cancel)
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .animation(.spring(duration: 0.35, bounce: 0.2), value: phase)
        .onAppear {
            // Coming back to a tool shows a job that is still running, but doesn't replay
            // the outcome of one that finished while you were elsewhere.
            if case .running(let progress) = session.lastJob?.state {
                phase = .running(progress: progress)
            }
        }
        .onChange(of: session.lastJob?.state) { _, state in
            update(for: state)
        }
        .onDisappear { settleTask?.cancel() }
    }

    private var actionButton: some View {
        // Busy and outcome phases ignore presses instead of disabling the button: a
        // disabled glassProminent button drops its tint, which would gray out the green
        // "Done" and the red failure state.
        Button {
            if phase == .idle { session.run() }
        } label: {
            label
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.extraLarge)
        .tint(tint)
        .overlay { progressFill }
        .keyframeAnimator(initialValue: 0.0, trigger: shakes) { content, offset in
            content.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(-9, duration: 0.07)
                SpringKeyframe(8, duration: 0.07)
                SpringKeyframe(-6, duration: 0.07)
                SpringKeyframe(4, duration: 0.07)
                SpringKeyframe(-2, duration: 0.07)
                SpringKeyframe(0, duration: 0.1)
            }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(session.validationMessage != nil && phase == .idle)
        .help(session.validationMessage ?? "\(session.primaryActionTitle) (⌘↩)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(session.validationMessage ?? "")
    }

    @ViewBuilder
    private var label: some View {
        switch phase {
        case .idle:
            Text(session.primaryActionTitle)
                .transition(.blurReplace)
        case .running(let progress):
            HStack(spacing: 8) {
                if progress < 0.01 {
                    ProgressView().controlSize(.small)
                }
                Text("\(session.runningTitle)…")
                if progress >= 0.01 {
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: progress))
                }
            }
            .transition(.blurReplace)
        case .succeeded:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .transition(.symbolEffect(.drawOn))
                Text("Done")
            }
            .transition(.blurReplace)
        case .failed:
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .transition(.symbolEffect(.drawOn))
                Text("Didn\u{2019}t finish")
            }
            .transition(.blurReplace)
        }
    }

    /// A lighter band that grows across the button as the job advances. It sits over the
    /// glass, clipped to the button's capsule, and never takes clicks.
    @ViewBuilder
    private var progressFill: some View {
        if case .running(let progress) = phase {
            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(width: max(proxy.size.height, proxy.size.width * progress))
                    .animation(.smooth(duration: 0.3), value: progress)
            }
            .mask(Capsule())
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.opacity)
        }
    }

    private var tint: Color? {
        switch phase {
        case .succeeded: .green
        case .failed: .red
        default: nil
        }
    }

    private var accessibilityLabel: Text {
        switch phase {
        case .idle: Text(session.primaryActionTitle)
        case .running(let progress):
            Text("\(session.runningTitle), \(progress.formatted(.percent.precision(.fractionLength(0)))) done")
        case .succeeded: Text("\(session.descriptor.title) finished")
        case .failed: Text("\(session.descriptor.title) didn\u{2019}t finish")
        }
    }

    // MARK: Phases

    private func update(for state: Job.State?) {
        settleTask?.cancel()
        switch state {
        case .running(let progress):
            phase = .running(progress: progress)
        case .succeeded:
            phase = .succeeded
            settle(after: .seconds(1.8))
        case .failed:
            phase = .failed
            if !reduceMotion { shakes += 1 }
            settle(after: .seconds(1.6))
        case .cancelled, nil:
            phase = .idle
        }
    }

    /// Returns to the button's title once the outcome has had its moment.
    private func settle(after delay: Duration) {
        settleTask = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            phase = .idle
        }
    }
}
