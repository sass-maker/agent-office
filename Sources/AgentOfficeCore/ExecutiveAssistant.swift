import Foundation

public enum ExecutiveAssistant {
  public static func appendInterruptedHandoff(
    to state: inout OrganizationState,
    now: Date = Date(),
    humanID: String = "owner"
  ) {
    guard let assistant = state.assistant(for: humanID) else { return }
    if state.knowledge == nil {
      state.knowledge = OrganizationKnowledge(productBrief: "")
    }
    guard
      state.knowledge?.assistantHandoffs.contains(where: {
        $0.assistantID == assistant.id
          && $0.dayNumber == state.dayNumber
          && $0.kind == .interruptedDay
      }) != true
    else { return }

    let completed = state.tasks.filter { $0.status == .done }.count
    let open = state.tasks.filter { ![.done, .blocked].contains($0.status) }.count
    let blockers = state.blockers.filter { !$0.resolved }.count
    let summary =
      "Day \(state.dayNumber) paused with \(completed) completed, \(open) still open, and \(blockers) blocker\(blockers == 1 ? "" : "s"). The exact next task is preserved."
    state.appendAssistantHandoff(
      assistantID: assistant.id,
      humanID: humanID,
      kind: .interruptedDay,
      summary: summary,
      activityMessage: summary,
      now: now
    )
  }
}

extension OrganizationState {
  /// Records an assistant handoff and the activity that announces it.
  ///
  /// Both always happen together — a handoff nobody is told about is not a
  /// handoff — so they are written in one place.
  mutating func appendAssistantHandoff(
    assistantID: String,
    humanID: String,
    kind: AssistantHandoffKind,
    summary: String,
    activityMessage: String,
    now: Date
  ) {
    if knowledge == nil { knowledge = OrganizationKnowledge(productBrief: "") }
    knowledge?.assistantHandoffs.append(
      AssistantHandoff(
        id: UUID().uuidString,
        assistantID: assistantID,
        humanID: humanID,
        dayNumber: dayNumber,
        kind: kind,
        summary: summary,
        artifactIDs: Array(artifacts.suffix(6).map(\.id)),
        createdAt: now
      ))
    activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: assistantID,
        kind: .handoff,
        message: activityMessage,
        createdAt: now
      ))
  }
}
