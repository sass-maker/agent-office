import Foundation

public struct WorkdayEngine: Sendable {
    public init() {}

    public func advance(
        _ input: OrganizationState,
        runner: any EmployeeRunner,
        store: LocalOrganizationStore,
        now: Date = Date()
    ) async -> OrganizationState {
        guard input.workdayStatus == .active else { return input }
        var state = input
        unlockDependencies(in: &state, now: now)

        guard let task = nextTask(in: state) else {
            state.workdayStatus = .complete
            restEmployees(in: &state)
            state.activity.append(Activity(
                id: UUID().uuidString,
                actorID: "owner",
                kind: .completed,
                message: "The team finished every available task for the day.",
                createdAt: now
            ))
            try? await store.save(state)
            return state
        }

        do {
            switch task.status {
            case .review:
                try await review(task, state: &state, runner: runner, store: store, now: now)
            case .revision:
                try await produce(task, operation: .revise, state: &state, runner: runner, store: store, now: now)
            case .ready:
                let operation: WorkOperation = switch task.kind {
                case .research: .research
                case .draft: .draft
                case .report: .report
                case .analysis: .customerVoice
                }
                try await produce(task, operation: operation, state: &state, runner: runner, store: store, now: now)
            default:
                break
            }
        } catch is CancellationError {
            try? await store.save(input)
            return input
        } catch {
            block(taskID: task.id, employeeID: activeEmployeeID(for: task), error: error, state: &state, now: now)
        }

        try? await store.save(state)
        return state
    }

    private func nextTask(in state: OrganizationState) -> WorkTask? {
        state.tasks.first { !isGenericOutcomeTask($0) && [.review, .revision].contains($0.status) }
            ?? state.tasks.first { !isGenericOutcomeTask($0) && $0.status == .ready }
    }

    private func unlockDependencies(in state: inout OrganizationState, now: Date) {
        let completed = Set(state.tasks.filter { $0.status == .done }.map(\.id))
        for index in state.tasks.indices
            where !isGenericOutcomeTask(state.tasks[index]) && state.tasks[index].status == .waiting {
            if Set(state.tasks[index].dependencyIDs).isSubset(of: completed) {
                state.tasks[index].status = .ready
                state.tasks[index].updatedAt = now
            }
        }
    }

    private func isGenericOutcomeTask(_ task: WorkTask) -> Bool {
        task.id.hasPrefix("employee-outcome-")
    }

    private func produce(
        _ task: WorkTask,
        operation: WorkOperation,
        state: inout OrganizationState,
        runner: any EmployeeRunner,
        store: LocalOrganizationStore,
        now: Date
    ) async throws {
        guard let employee = state.employee(task.assigneeID),
              let taskIndex = state.tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        setEmployee(employee.id, status: .working, taskID: task.id, in: &state)
        state.tasks[taskIndex].status = .doing
        state.tasks[taskIndex].updatedAt = now
        state.activity.append(Activity(
            id: UUID().uuidString,
            actorID: employee.id,
            kind: .started,
            message: "\(employee.name) started \(task.title.lowercased()).",
            createdAt: now
        ))
        try await store.save(state)

        let context = await artifactContext(for: task, in: state, store: store)
        let request = EmployeeWorkRequest(
            operation: operation,
            employee: employee,
            task: state.tasks[taskIndex],
            organizationName: state.name,
            outcome: state.outcome,
            productBrief: state.productBrief,
            context: context,
            memory: memoryContext(for: employee.id, in: state),
            skills: state.assignedSkills(employeeID: employee.id),
            capabilityGrants: employee.capabilityGrants,
            workspaceURL: store.rootURL.appendingPathComponent("employees/\(employee.id)", isDirectory: true)
        )
        try FileManager.default.createDirectory(at: request.workspaceURL, withIntermediateDirectories: true)
        let usesWebResearch = state.executionMode == .localCodex && request.canUseWebResearch
        if usesWebResearch {
            appendCapabilityEvent(
                capability: "web-research",
                employeeID: employee.id,
                taskID: task.id,
                actorID: employee.id,
                kind: .started,
                detail: "\(employee.name) started permitted web research.",
                state: &state,
                now: now
            )
            try await store.save(state)
        }

        let output: EmployeeWorkOutput
        do {
            output = try await runner.perform(request)
        } catch {
            if usesWebResearch {
                let eventKind: CapabilityEventKind
                if case .unavailable? = error as? CodexRunnerError {
                    eventKind = .unavailable
                } else {
                    eventKind = .failed
                }
                appendCapabilityEvent(
                    capability: "web-research",
                    employeeID: employee.id,
                    taskID: task.id,
                    actorID: employee.id,
                    kind: eventKind,
                    detail: error.localizedDescription,
                    state: &state,
                    now: now
                )
            }
            throw error
        }

        let kind: ArtifactKind = switch operation {
        case .plan, .analysis: .analysis
        case .research: .research
        case .draft, .revise: .draft
        case .report: .report
        case .review: .review
        case .customerVoice: .analysis
        }
        let revision = operation == .revise ? state.tasks[taskIndex].revisionCount : 0
        let sourceArtifacts = state.artifacts.filter { task.dependencyIDs.contains($0.taskID) }
        let evidenceBasis = sourceArtifacts.contains { $0.evidenceBasis == "permitted-web-research" }
            ? "permitted-web-research"
            : output.evidenceBasis
        let artifact = Artifact(
            id: UUID().uuidString,
            title: output.title,
            kind: kind,
            relativePath: LocalOrganizationStore.artifactPath(
                employeeID: employee.id,
                taskID: task.id,
                kind: kind,
                revision: revision
            ),
            authorID: employee.id,
            taskID: task.id,
            createdAt: now,
            sourceArtifactIDs: sourceArtifacts.map(\.id),
            evidenceBasis: evidenceBasis
        )
        try await store.writeArtifact(relativePath: artifact.relativePath, content: output.content)
        state.artifacts.append(artifact)
        state.tasks[taskIndex].artifactIDs.append(artifact.id)
        state.tasks[taskIndex].updatedAt = now

        switch operation {
        case .plan, .analysis:
            state.tasks[taskIndex].status = .done
            setEmployee(employee.id, status: .waiting, taskID: nil, in: &state)
        case .research:
            state.tasks[taskIndex].status = .done
            setGoalProgress(0.25, in: &state)
            setEmployee(employee.id, status: .waiting, taskID: nil, in: &state)
            appendMemory(
                employeeID: employee.id,
                authorID: employee.id,
                summary: output.summary,
                sourceArtifactID: artifact.id,
                state: &state,
                now: now
            )
            if usesWebResearch {
                appendCapabilityEvent(
                    capability: "web-research",
                    employeeID: employee.id,
                    taskID: task.id,
                    actorID: employee.id,
                    kind: .succeeded,
                    detail: "Research evidence was saved to \(artifact.relativePath).",
                    state: &state,
                    now: now
                )
            }
        case .draft, .revise:
            state.tasks[taskIndex].status = .review
            setEmployee(employee.id, status: .waiting, taskID: nil, in: &state)
            if let reviewer = task.reviewerID {
                setEmployee(reviewer, status: .reviewing, taskID: task.id, in: &state)
            }
        case .report:
            state.tasks[taskIndex].status = .done
            setGoalProgress(1, in: &state)
            state.workdayStatus = .complete
            restEmployees(in: &state)
            appendMemory(
                employeeID: employee.id,
                authorID: employee.id,
                summary: output.summary,
                sourceArtifactID: artifact.id,
                state: &state,
                now: now
            )
            appendAssistantHandoff(kind: .endOfDay, summary: output.summary, state: &state, now: now)
        case .review:
            break
        case .customerVoice:
            state.tasks[taskIndex].status = .done
            setEmployee(employee.id, status: .resting, taskID: nil, in: &state)
        }

        state.activity.append(Activity(
            id: UUID().uuidString,
            actorID: employee.id,
            kind: operation == .report ? .completed : .handoff,
            message: output.summary,
            createdAt: now
        ))
    }

    private func review(
        _ task: WorkTask,
        state: inout OrganizationState,
        runner: any EmployeeRunner,
        store: LocalOrganizationStore,
        now: Date
    ) async throws {
        guard let reviewerID = task.reviewerID,
              let reviewer = state.employee(reviewerID),
              let taskIndex = state.tasks.firstIndex(where: { $0.id == task.id })
        else { return }

        setEmployee(reviewerID, status: .reviewing, taskID: task.id, in: &state)
        let context = await artifactContext(for: task, in: state, store: store)
        let request = EmployeeWorkRequest(
            operation: .review,
            employee: reviewer,
            task: state.tasks[taskIndex],
            organizationName: state.name,
            outcome: state.outcome,
            productBrief: state.productBrief,
            context: context,
            memory: memoryContext(for: reviewer.id, in: state),
            skills: state.assignedSkills(employeeID: reviewer.id),
            capabilityGrants: reviewer.capabilityGrants,
            workspaceURL: store.rootURL.appendingPathComponent("employees/\(reviewer.id)", isDirectory: true)
        )
        try FileManager.default.createDirectory(at: request.workspaceURL, withIntermediateDirectories: true)
        let output = try await runner.perform(request)
        let reviewNumber = state.tasks[taskIndex].revisionCount + 1
        let reviewedDrafts = state.artifacts.filter { $0.taskID == task.id && $0.kind == .draft }
        let artifact = Artifact(
            id: UUID().uuidString,
            title: output.title,
            kind: .review,
            relativePath: LocalOrganizationStore.artifactPath(
                employeeID: reviewer.id,
                taskID: task.id,
                kind: .review,
                revision: state.tasks[taskIndex].revisionCount
            ),
            authorID: reviewer.id,
            taskID: task.id,
            createdAt: now,
            sourceArtifactIDs: reviewedDrafts.map(\.id),
            evidenceBasis: reviewedDrafts.contains { $0.evidenceBasis == "permitted-web-research" }
                ? "permitted-web-research"
                : output.evidenceBasis
        )
        try await store.writeArtifact(relativePath: artifact.relativePath, content: output.content)
        state.artifacts.append(artifact)
        state.tasks[taskIndex].artifactIDs.append(artifact.id)
        state.tasks[taskIndex].updatedAt = now

        if output.verdict == .approve {
            state.tasks[taskIndex].status = .done
            setGoalProgress(0.8, in: &state)
            setEmployee(reviewerID, status: .waiting, taskID: nil, in: &state)
            state.activity.append(Activity(
                id: UUID().uuidString,
                actorID: reviewerID,
                kind: .approved,
                message: output.summary,
                createdAt: now
            ))
            if let approvedDraft = state.artifacts.last(where: { $0.taskID == task.id && $0.kind == .draft }) {
                appendMemory(
                    employeeID: task.assigneeID,
                    authorID: reviewerID,
                    summary: "\(approvedDraft.title) was approved by \(reviewer.name).",
                    sourceArtifactID: approvedDraft.id,
                    state: &state,
                    now: now
                )
            }
        } else if state.tasks[taskIndex].revisionCount < state.tasks[taskIndex].maxRevisions {
            state.tasks[taskIndex].revisionCount += 1
            state.tasks[taskIndex].status = .revision
            setEmployee(reviewerID, status: .waiting, taskID: nil, in: &state)
            setEmployee(task.assigneeID, status: .working, taskID: task.id, in: &state)
            state.activity.append(Activity(
                id: UUID().uuidString,
                actorID: reviewerID,
                kind: .review,
                message: "\(output.summary) Revision \(reviewNumber) of \(task.maxRevisions).",
                createdAt: now
            ))
        } else {
            block(
                taskID: task.id,
                employeeID: reviewerID,
                detail: "The draft reached its \(task.maxRevisions)-revision limit and needs the owner's decision.",
                state: &state,
                now: now
            )
        }
    }

    private func artifactContext(
        for task: WorkTask,
        in state: OrganizationState,
        store: LocalOrganizationStore
    ) async -> String {
        let relevantTaskIDs = Set(task.dependencyIDs + [task.id])
        let artifacts = state.artifacts.filter { relevantTaskIDs.contains($0.taskID) }.suffix(4)
        var sections: [String] = []
        for artifact in artifacts {
            if let content = try? await store.readArtifact(relativePath: artifact.relativePath) {
                sections.append("## \(artifact.title)\n\(content)")
            }
        }
        return sections.joined(separator: "\n\n")
    }

    private func memoryContext(for employeeID: String, in state: OrganizationState) -> String {
        state.knowledge?.memoryEntries
            .filter { $0.employeeID == employeeID }
            .suffix(8)
            .map { "- Day \($0.dayNumber): \($0.summary)" }
            .joined(separator: "\n") ?? ""
    }

    private func ensureKnowledge(in state: inout OrganizationState) {
        if state.knowledge == nil {
            state.knowledge = OrganizationKnowledge(productBrief: "")
        }
    }

    private func appendMemory(
        employeeID: String,
        authorID: String,
        summary: String,
        sourceArtifactID: String?,
        state: inout OrganizationState,
        now: Date
    ) {
        ensureKnowledge(in: &state)
        guard state.knowledge?.memoryEntries.contains(where: {
            $0.employeeID == employeeID && $0.sourceArtifactID == sourceArtifactID && $0.summary == summary
        }) != true else { return }
        state.knowledge?.memoryEntries.append(EmployeeMemoryEntry(
            id: UUID().uuidString,
            employeeID: employeeID,
            authorID: authorID,
            dayNumber: state.dayNumber,
            summary: summary,
            sourceArtifactID: sourceArtifactID,
            createdAt: now
        ))
    }

    private func appendCapabilityEvent(
        capability: String,
        employeeID: String,
        taskID: String?,
        actorID: String,
        kind: CapabilityEventKind,
        detail: String,
        state: inout OrganizationState,
        now: Date
    ) {
        ensureKnowledge(in: &state)
        state.knowledge?.capabilityEvents.append(CapabilityEvent(
            id: UUID().uuidString,
            capability: capability,
            employeeID: employeeID,
            taskID: taskID,
            actorID: actorID,
            kind: kind,
            detail: detail,
            createdAt: now
        ))
    }

    private func appendAssistantHandoff(
        kind: AssistantHandoffKind,
        summary: String,
        state: inout OrganizationState,
        now: Date
    ) {
        ensureKnowledge(in: &state)
        guard let assistant = state.assistant(for: "owner"),
              state.knowledge?.assistantHandoffs.contains(where: {
                  $0.assistantID == assistant.id && $0.dayNumber == state.dayNumber && $0.kind == kind
              }) != true
        else { return }
        state.knowledge?.assistantHandoffs.append(AssistantHandoff(
            id: UUID().uuidString,
            assistantID: assistant.id,
            humanID: "owner",
            dayNumber: state.dayNumber,
            kind: kind,
            summary: summary,
            artifactIDs: Array(state.artifacts.suffix(6).map(\.id)),
            createdAt: now
        ))
        state.activity.append(Activity(
            id: UUID().uuidString,
            actorID: assistant.id,
            kind: .handoff,
            message: "Your day-end handoff is ready.",
            createdAt: now
        ))
    }

    private func activeEmployeeID(for task: WorkTask) -> String {
        task.status == .review ? (task.reviewerID ?? task.assigneeID) : task.assigneeID
    }

    private func block(
        taskID: String,
        employeeID: String,
        error: Error,
        state: inout OrganizationState,
        now: Date
    ) {
        block(
            taskID: taskID,
            employeeID: employeeID,
            detail: error.localizedDescription,
            state: &state,
            now: now
        )
    }

    private func block(
        taskID: String,
        employeeID: String,
        detail: String,
        state: inout OrganizationState,
        now: Date
    ) {
        if let index = state.tasks.firstIndex(where: { $0.id == taskID }) {
            state.tasks[index].status = .blocked
            state.tasks[index].updatedAt = now
        }
        setEmployee(employeeID, status: .blocked, taskID: taskID, in: &state)
        state.blockers.append(Blocker(
            id: UUID().uuidString,
            title: "Owner decision needed",
            detail: detail,
            employeeID: employeeID,
            taskID: taskID,
            createdAt: now,
            resolved: false
        ))
        state.activity.append(Activity(
            id: UUID().uuidString,
            actorID: employeeID,
            kind: .blocked,
            message: detail,
            createdAt: now
        ))
    }

    private func setEmployee(
        _ id: String,
        status: EmployeeStatus,
        taskID: String?,
        in state: inout OrganizationState
    ) {
        guard let index = state.employees.firstIndex(where: { $0.id == id }) else { return }
        state.employees[index].status = status
        state.employees[index].currentTaskID = taskID
    }

    private func restEmployees(in state: inout OrganizationState) {
        for index in state.employees.indices {
            state.employees[index].status = .resting
            state.employees[index].currentTaskID = nil
        }
    }

    private func setGoalProgress(_ progress: Double, in state: inout OrganizationState) {
        guard !state.goals.isEmpty else { return }
        state.goals[0].progress = max(state.goals[0].progress, progress)
    }
}
