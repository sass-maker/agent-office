import Foundation

public enum WorkOperation: String, Sendable {
    case research
    case draft
    case revise
    case review
    case report
}

public enum ReviewVerdict: String, Codable, Sendable {
    case revise
    case approve
}

public struct EmployeeWorkRequest: Sendable {
    public var operation: WorkOperation
    public var employee: Employee
    public var task: WorkTask
    public var organizationName: String
    public var outcome: String
    public var context: String
    public var workspaceURL: URL

    public init(
        operation: WorkOperation,
        employee: Employee,
        task: WorkTask,
        organizationName: String,
        outcome: String,
        context: String,
        workspaceURL: URL
    ) {
        self.operation = operation
        self.employee = employee
        self.task = task
        self.organizationName = organizationName
        self.outcome = outcome
        self.context = context
        self.workspaceURL = workspaceURL
    }
}

public struct EmployeeWorkOutput: Sendable {
    public var title: String
    public var summary: String
    public var content: String
    public var verdict: ReviewVerdict?

    public init(
        title: String,
        summary: String,
        content: String,
        verdict: ReviewVerdict? = nil
    ) {
        self.title = title
        self.summary = summary
        self.content = content
        self.verdict = verdict
    }
}

public protocol EmployeeRunner: Sendable {
    func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput
}

public struct DeterministicEmployeeRunner: EmployeeRunner {
    public init() {}

    public func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        switch request.operation {
        case .research:
            return EmployeeWorkOutput(
                title: "Audience research",
                summary: "Nia found a concrete question the article can answer.",
                content: """
                # Audience research

                ## Outcome
                \(request.outcome)

                ## Useful audience question
                How can a small product team turn a vague outcome into useful,
                reviewable work without adding another complicated dashboard?

                ## Reader intent
                The reader wants a concrete operating pattern, an honest first
                step, and clarity about where human judgment remains necessary.

                ## Article direction
                Explain the smallest useful loop: name an outcome, assign an
                owner, produce one artifact, review it, and preserve the next
                action. Avoid claims about autonomy that the product cannot yet
                demonstrate.
                """
            )

        case .draft:
            return EmployeeWorkOutput(
                title: "From outcome to a useful workday",
                summary: "Theo produced a complete first draft for Maya.",
                content: """
                # From an outcome to a useful workday

                Most tools begin by asking you to configure a workflow. Small
                teams rarely wake up wanting another workflow; they have an
                outcome they need someone to own.

                Start with one useful loop. Give a named teammate an outcome,
                let them break it into visible work, and require every handoff
                to produce an inspectable artifact. A researcher can identify
                the audience question. A writer can turn that evidence into a
                draft. A manager can review it against the outcome rather than
                against a generic checklist.

                The loop needs a stopping condition. Two review cycles are
                enough for a first version: either the work is approved or the
                owner receives a precise blocker. The goal is not simulated
                busyness. It is a small organization that remembers where it
                stopped and knows what should happen next.

                That is already useful before integrations, elaborate
                permissions, or autonomous infrastructure work arrive.
                """
            )

        case .revise:
            return EmployeeWorkOutput(
                title: "From outcome to a useful workday — revised",
                summary: "Theo revised the draft around a clearer practical example.",
                content: """
                # From an outcome to a useful workday

                Imagine asking a small content team for one useful article.
                Nia researches the question readers actually have. Theo writes
                the first answer. Maya reviews it against the outcome and sends
                back one concrete correction: show the operating loop, not just
                the idea.

                The team now has a visible path: outcome → research → draft →
                review → approval. Every handoff leaves an ordinary file behind,
                and every employee knows who owns the next move. If two revisions
                cannot resolve the work, the loop stops and asks the owner for a
                decision instead of quietly consuming another afternoon.

                This is useful before the organization can publish, browse, or
                operate cloud systems. Those abilities can arrive later with
                stronger permissions and guardrails. The first proof is simpler:
                named employees can pick up real work, coordinate, and leave the
                company in a clearer state than they found it.
                """
            )

        case .review:
            let shouldApprove = request.task.revisionCount > 0
            return EmployeeWorkOutput(
                title: shouldApprove ? "Editorial approval" : "Editorial review",
                summary: shouldApprove
                    ? "Maya approved the revised article."
                    : "Maya asked for one focused revision.",
                content: shouldApprove
                    ? "# Approved\n\nThe revision now demonstrates the operating loop, its stopping condition, and the boundary between current proof and future capability."
                    : "# Revision requested\n\nOpen with a concrete researcher → writer → manager example. Make the two-cycle stopping condition explicit and separate today's useful proof from future permissions and integrations.",
                verdict: shouldApprove ? .approve : .revise
            )

        case .report:
            return EmployeeWorkOutput(
                title: "Day \(request.task.revisionCount + 1) report",
                summary: "Maya prepared the owner's end-of-day report.",
                content: """
                # Owner report

                ## Completed
                - Nia identified the audience question and article direction.
                - Theo wrote and revised the article.
                - Maya reviewed and approved the final draft.

                ## Artifacts
                Research, draft versions, editorial feedback, and approval are
                stored in the organization folder.

                ## Blockers
                None.

                ## Recommended next step
                Read the approved draft and decide whether the next employee
                should prepare a publishing package.
                """
            )
        }
    }
}

public enum CodexRunnerError: LocalizedError {
    case unavailable
    case failed(Int32, String)
    case emptyOutput

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            "The locally authenticated Codex CLI is not available."
        case let .failed(status, detail):
            "Codex stopped with status \(status). \(detail)"
        case .emptyOutput:
            "Codex completed without returning employee work."
        }
    }
}

public struct CodexEmployeeRunner: EmployeeRunner {
    public let executableURL: URL

    public init(executableURL: URL) {
        self.executableURL = executableURL
    }

    public static func discover(fileManager: FileManager = .default) -> CodexEmployeeRunner? {
        let environmentPaths = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        let candidates = environmentPaths.map { URL(fileURLWithPath: $0).appendingPathComponent("codex") }
            + [URL(fileURLWithPath: "/opt/homebrew/bin/codex"), URL(fileURLWithPath: "/usr/local/bin/codex")]

        guard let executable = candidates.first(where: { fileManager.isExecutableFile(atPath: $0.path) }) else {
            return nil
        }
        return CodexEmployeeRunner(executableURL: executable)
    }

    public func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
        let executableURL = self.executableURL
        return try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = executableURL
            process.currentDirectoryURL = request.workspaceURL
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.arguments = [
                "exec",
                "--ephemeral",
                "--sandbox", "read-only",
                "--skip-git-repo-check",
                "--color", "never",
                "--cd", request.workspaceURL.path,
                Self.prompt(for: request),
            ]

            try process.run()
            process.waitUntilExit()

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let error = String(
                data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                throw CodexRunnerError.failed(process.terminationStatus, error)
            }
            guard !output.isEmpty else {
                throw CodexRunnerError.emptyOutput
            }

            let verdict: ReviewVerdict?
            if request.operation == .review {
                verdict = output.localizedCaseInsensitiveContains("APPROVE") ? .approve : .revise
            } else {
                verdict = nil
            }

            return EmployeeWorkOutput(
                title: request.task.title,
                summary: "\(request.employee.name) completed \(request.operation.rawValue) work with local Codex.",
                content: output,
                verdict: verdict
            )
        }.value
    }

    private static func prompt(for request: EmployeeWorkRequest) -> String {
        let reviewInstruction = request.operation == .review
            ? "Begin your response with exactly APPROVE or REVISE, then provide concise evidence-based feedback."
            : "Return the complete useful Markdown artifact only."
        return """
        You are \(request.employee.name), the \(request.employee.role) at \(request.organizationName).
        Your responsibility: \(request.employee.responsibility)
        Organization outcome: \(request.outcome)
        Current task: \(request.task.title) — \(request.task.detail)
        Operation: \(request.operation.rawValue)

        Context from the organization's existing local artifacts:
        \(request.context.isEmpty ? "No prior artifact is available." : request.context)

        Work only on this task. Do not run commands, modify files, contact services,
        publish anything, or claim evidence you do not have.
        \(reviewInstruction)
        """
    }
}

