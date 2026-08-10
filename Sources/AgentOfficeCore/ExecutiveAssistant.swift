import Foundation

public struct AssistantBrief: Sendable, Equatable {
    public var assistantID: String
    public var humanID: String
    public var title: String
    public var summary: String
    public var nextAction: String
    public var decisions: [String]
    public var latestArtifactID: String?

    public init(
        assistantID: String,
        humanID: String,
        title: String,
        summary: String,
        nextAction: String,
        decisions: [String],
        latestArtifactID: String?
    ) {
        self.assistantID = assistantID
        self.humanID = humanID
        self.title = title
        self.summary = summary
        self.nextAction = nextAction
        self.decisions = decisions
        self.latestArtifactID = latestArtifactID
    }
}

public enum ExecutiveAssistant {
    public static func morningBrief(for state: OrganizationState, humanID: String = "owner") -> AssistantBrief? {
        guard let assistant = state.assistant(for: humanID) else { return nil }

        let completed = state.tasks.filter { $0.status == .done }.count
        let total = state.tasks.count
        let nextTask = state.tasks.first { ![.done, .blocked].contains($0.status) }
        let unresolvedBlockers = state.blockers.filter { !$0.resolved }
        var decisions = unresolvedBlockers.map { $0.detail }

        if !state.hasMeaningfulProductBrief {
            decisions.append("Tell the team what the product is, who it serves, and which claims it may safely make.")
        }
        if state.executionMode == .localCodex && !state.hasCapability("web-research", employeeID: "nia") {
            decisions.append("Decide whether Nia may use read-only web research for this outcome.")
        }

        let summary: String
        switch state.workdayStatus {
        case .active:
            summary = "The team is carrying \(total - completed) open task\(total - completed == 1 ? "" : "s") toward \(state.outcome)"
        case .complete:
            summary = "The team completed the bounded workday and left \(state.artifacts.count) inspectable artifact\(state.artifacts.count == 1 ? "" : "s")."
        case .ending, .resting:
            summary = completed == 0
                ? "No work is being claimed as complete yet. The team is ready to begin from your product brief."
                : "\(completed) of \(total) tasks are complete. The remaining work is preserved for the next day."
        }

        let nextAction: String
        if !decisions.isEmpty {
            nextAction = decisions[0]
        } else if let nextTask {
            nextAction = "Next: \(nextTask.title), owned by \(state.employee(nextTask.assigneeID)?.name ?? nextTask.assigneeID)."
        } else if let handoff = state.knowledge?.assistantHandoffs.last {
            nextAction = handoff.summary
        } else {
            nextAction = "Review the latest artifact and choose the next outcome."
        }

        return AssistantBrief(
            assistantID: assistant.id,
            humanID: humanID,
            title: state.workdayStatus == .complete ? "The day is on your desk" : "Before the doors open",
            summary: summary,
            nextAction: nextAction,
            decisions: decisions,
            latestArtifactID: state.artifacts.last?.id
        )
    }

    public static func appendInterruptedHandoff(
        to state: inout OrganizationState,
        now: Date = Date(),
        humanID: String = "owner"
    ) {
        guard let assistant = state.assistant(for: humanID) else { return }
        if state.knowledge == nil {
            state.knowledge = OrganizationKnowledge(productBrief: "")
        }
        guard state.knowledge?.assistantHandoffs.contains(where: {
            $0.assistantID == assistant.id
                && $0.dayNumber == state.dayNumber
                && $0.kind == .interruptedDay
        }) != true else { return }

        let completed = state.tasks.filter { $0.status == .done }.count
        let open = state.tasks.filter { ![.done, .blocked].contains($0.status) }.count
        let blockers = state.blockers.filter { !$0.resolved }.count
        let summary = "Day \(state.dayNumber) paused with \(completed) completed, \(open) still open, and \(blockers) blocker\(blockers == 1 ? "" : "s"). The exact next task is preserved."
        state.knowledge?.assistantHandoffs.append(AssistantHandoff(
            id: UUID().uuidString,
            assistantID: assistant.id,
            humanID: humanID,
            dayNumber: state.dayNumber,
            kind: .interruptedDay,
            summary: summary,
            artifactIDs: Array(state.artifacts.suffix(6).map(\.id)),
            createdAt: now
        ))
        state.activity.append(Activity(
            id: UUID().uuidString,
            actorID: assistant.id,
            kind: .handoff,
            message: summary,
            createdAt: now
        ))
    }
}
