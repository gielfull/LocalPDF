import SwiftUI

/// The toolbar's activity popover: running and finished jobs with progress, cancel,
/// try again, and a way back to each job's results.
struct QueuePopover: View {
    let queue: JobQueue

    var body: some View {
        VStack(spacing: 0) {
            if queue.jobs.isEmpty {
                ContentUnavailableView(
                    "No Tasks Yet", systemImage: "tray",
                    description: Text("Tasks you run appear here while they work and after they finish.")
                )
                .frame(height: 200)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(queue.jobs) { job in
                            JobRow(job: job, queue: queue)
                            if job !== queue.jobs.last {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                }
                .frame(maxHeight: 360)
                Divider()
                HStack {
                    Text(queue.runningCount == 0 ? "All tasks finished" : "\(queue.runningCount) running")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear Finished") { queue.clearFinished() }
                        .disabled(queue.jobs.allSatisfy(\.isRunning))
                }
                .padding(12)
            }
        }
        .frame(width: 360)
    }
}

/// One job in the popover.
private struct JobRow: View {
    let job: Job
    let queue: JobQueue

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            ToolIcon(systemImage: job.tool.systemImage, tint: job.tool.tint, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(job.tool.title)
                    .font(.callout.weight(.medium))
                Text(job.inputSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                status
            }
            Spacer(minLength: 4)
            action
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        switch job.state {
        case .running(let progress):
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .controlSize(.small)
        case .succeeded:
            Label("\(job.outputs.count) saved", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(2)
        case .cancelled:
            Label("Cancelled", systemImage: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var action: some View {
        switch job.state {
        case .running:
            Button("Cancel", systemImage: "xmark.circle.fill") { queue.cancel(job) }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        case .succeeded:
            Button("Show Results") {
                dismiss()
                queue.presentedJob = job
            }
            .controlSize(.small)
        case .failed, .cancelled:
            Button("Try Again") { queue.retry(job) }
                .controlSize(.small)
        }
    }
}
