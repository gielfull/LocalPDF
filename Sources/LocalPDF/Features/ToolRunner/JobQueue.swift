import Foundation
import Observation
import PDFEngine

/// Runs jobs off the main actor and keeps their history for the queue popover.
/// Also owns the two modal moments of a job: the password prompt and the result sheet.
@Observable
final class JobQueue {
    /// Newest first.
    private(set) var jobs: [Job] = []
    /// The job whose result sheet is showing.
    var presentedJob: Job?
    /// The password prompt that is showing.
    var passwordRequest: PasswordRequest?
    /// Counts jobs that reached an outcome, so the toolbar can bounce on each one.
    private(set) var completions = 0

    @ObservationIgnored private let preferences: Preferences

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    var runningCount: Int { jobs.count(where: \.isRunning) }

    @discardableResult
    func submit(_ request: JobRequest) -> Job {
        let job = Job(request: request)
        jobs.insert(job, at: 0)
        Haptics.jobStarted()
        start(job)
        return job
    }

    func cancel(_ job: Job) {
        job.task?.cancel()
    }

    /// Runs a failed or cancelled job again with the same inputs and options.
    func retry(_ job: Job) {
        jobs.removeAll { $0 === job }
        submit(job.request)
    }

    func clearFinished() {
        jobs.removeAll(where: \.isFinished)
    }

    private func start(_ job: Job) {
        let request = job.request
        let destination = preferences.destination
        let (updates, continuation) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))

        job.task = Task {
            // Progress arrives on arbitrary threads; this relay applies it on the main actor, in order.
            let relay = Task {
                for await fraction in updates where job.isRunning {
                    job.state = .running(progress: min(max(fraction, 0), 1))
                }
            }
            let result: Result<[SavedOutput], any Error>
            do {
                result = .success(try await JobExecutor.execute(request, to: destination) { continuation.yield($0) })
            } catch {
                result = .failure(error)
            }
            continuation.finish()
            await relay.value
            finish(job, with: result)
        }
    }

    private func finish(_ job: Job, with result: Result<[SavedOutput], any Error>) {
        completions += 1
        switch result {
        case .success(let outputs):
            job.outputs = outputs
            job.state = .succeeded
            Haptics.jobSucceeded()
            present(job, after: .milliseconds(900))
        case .failure(PDFEngineError.cancelled), .failure(is CancellationError):
            job.state = .cancelled
        case .failure(PDFEngineError.passwordRequired(let url)):
            job.state = .failed(message: PDFEngineError.passwordRequired(url).localizedDescription)
            askForPassword(job, url: url, wasRejected: false)
        case .failure(PDFEngineError.wrongPassword(let url)):
            job.state = .failed(message: PDFEngineError.wrongPassword(url).localizedDescription)
            askForPassword(job, url: url, wasRejected: true)
        case .failure(let error):
            job.state = .failed(message: error.localizedDescription)
            Haptics.jobFailed()
            present(job, after: .milliseconds(700))
        }
    }

    /// Shows the result sheet once the primary button has played its done or failed
    /// moment, so the outcome is felt and seen before the sheet covers it.
    private func present(_ job: Job, after delay: Duration) {
        Task { [weak self] in
            try? await Task.sleep(for: delay)
            self?.presentedJob = job
        }
    }

    /// The engine hit a locked input the up-front check missed: ask, then run again.
    private func askForPassword(_ job: Job, url: URL, wasRejected: Bool) {
        Task { [weak self] in
            let file = await SourceFile.load(url)
            guard let self else { return }
            passwordRequest = PasswordRequest(file: file, wasRejected: wasRejected) { [weak self] unlocked in
                guard let self, let password = unlocked.password else { return }
                jobs.removeAll { $0 === job }
                submit(job.request.supplying(password: password, for: url))
            }
        }
    }
}
