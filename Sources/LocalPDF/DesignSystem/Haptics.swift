import AppKit

/// Force Touch trackpad feedback for the moments of a job: it starts, it succeeds, it fails.
///
/// macOS only plays haptics while a finger rests on a Force Touch trackpad. With a mouse,
/// or after ⌘↩ from the keyboard, they're silently skipped, which is why every moment that
/// taps here also has a visible animation in the primary action button.
enum Haptics {
    /// A single firm tap as the job is submitted.
    static func jobStarted() {
        perform(.generic)
    }

    /// Two quick taps, the "done" rhythm.
    static func jobSucceeded() {
        perform(.levelChange)
        Task {
            try? await Task.sleep(for: .milliseconds(110))
            perform(.levelChange)
        }
    }

    /// Three short taps that read as "no", matching the button's shake.
    static func jobFailed() {
        Task {
            for _ in 0..<3 {
                perform(.generic)
                try? await Task.sleep(for: .milliseconds(70))
            }
        }
    }

    private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
