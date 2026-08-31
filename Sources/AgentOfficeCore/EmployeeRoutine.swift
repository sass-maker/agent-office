import Foundation

/// What an employee is supposed to do repeatedly, in one place.
///
/// Derived, never stored. Organization state and the working contract are
/// canonical; a routine is the compact reading of them that answers "what is
/// this employee for, what may it do, and when is it next expected?". Storing it
/// would create a second copy that could disagree with the contract.
public struct EmployeeRoutine: Sendable, Equatable {
  /// What recurs: an owner-authored duty, a schedule pointing at a commitment,
  /// or nothing yet.
  public enum Cadence: Sendable, Equatable {
    case duty(title: String, recurrence: String, nextDueAt: Date?)
    case schedule(subject: String, recurrence: String, nextDueAt: Date?)
    /// No recurrence has been set up. Said plainly rather than implied by an
    /// empty section, because "nothing recurs yet" is the honest answer.
    case onRequestOnly

    public var summary: String {
      switch self {
      case .duty(let title, let recurrence, _): "\(title) · \(recurrence)"
      case .schedule(let subject, let recurrence, _): "\(subject) · \(recurrence)"
      case .onRequestOnly: "No recurring cadence. This employee works when you assign an outcome."
      }
    }

    public var nextDueAt: Date? {
      switch self {
      case .duty(_, _, let date), .schedule(_, _, let date): date
      case .onRequestOnly: nil
      }
    }
  }

  public var employeeID: String
  public var employeeName: String
  public var role: String
  public var responsibility: String
  public var contractRevision: Int
  public var cadence: Cadence
  /// What this employee is given to work from.
  public var inputs: [String]
  /// What a completed run is expected to leave behind.
  public var expectedOutputs: [String]
  public var assignedSkillNames: [String]
  public var requiredCapabilityIDs: [String]
  public var declaredConnectionIDs: [String]
  public var boundaries: AutonomyBoundaries
  public var reviewPolicy: PlanReviewPolicy
  public var reviewerName: String?
  public var executionProvider: EmployeeExecutionProvider
  public var modelName: String?
  /// The last run, if there has been one. `nil` means no run has happened —
  /// never "assume it went fine".
  public var lastRun: RunReceipt?
  /// The commitment currently open, if any.
  public var openCommitment: String?
}

extension OrganizationState {
  /// The routine for a currently hired employee, or `nil`.
  ///
  /// Deliberately `nil` for anyone not hired: a paused or retired employee has
  /// no routine, and generating one anyway would describe work that is not going
  /// to happen.
  public func employeeRoutine(for employeeID: String) -> EmployeeRoutine? {
    guard let employee = employee(employeeID), employee.kind == .ai,
      employee.effectiveEmploymentState == .hired
    else { return nil }
    let contract = workingContract(for: employeeID)
    let skills = assignedSkills(employeeID: employeeID)
    return EmployeeRoutine(
      employeeID: employeeID,
      employeeName: employee.name,
      role: contract?.role ?? employee.role,
      responsibility: contract?.responsibility ?? employee.responsibility,
      contractRevision: contract?.revision ?? 0,
      cadence: routineCadence(for: employeeID),
      inputs: routineInputs(for: employeeID, contract: contract),
      expectedOutputs: routineOutputs(for: employeeID, skills: skills),
      assignedSkillNames: skills.map(\.name).sorted(),
      requiredCapabilityIDs: (contract?.capabilityGrants ?? employee.capabilityGrants).sorted(),
      declaredConnectionIDs: (contract?.declaredConnectionIDs ?? []).sorted(),
      boundaries: contract?.boundaries ?? AutonomyBoundaries(),
      reviewPolicy: contract?.reviewPolicy ?? .always,
      reviewerName: routineReviewerName(for: employeeID),
      executionProvider: contract?.executionProvider ?? .auto,
      modelName: contract?.modelName,
      lastRun: latestRunReceipt(forEmployee: employeeID),
      openCommitment: activeEmployeeOutcome(for: employeeID)?.outcome
    )
  }

  /// The most recent receipt for an employee, newest first by creation.
  public func latestRunReceipt(forEmployee employeeID: String) -> RunReceipt? {
    runReceipts
      .filter { $0.work.employeeID == employeeID }
      .sorted { $0.createdAt < $1.createdAt }
      .last
  }

  /// The most recent receipt written for one commitment.
  public func latestRunReceipt(forCommitment commitmentID: String) -> RunReceipt? {
    runReceipts
      .filter { $0.work.subject == .commitment(commitmentID) }
      .sorted { $0.createdAt < $1.createdAt }
      .last
  }

  // MARK: - Internals

  private func routineCadence(for employeeID: String) -> EmployeeRoutine.Cadence {
    if let duty = employeeDuties.first(where: { $0.assigneeID == employeeID }) {
      return .duty(
        title: duty.title,
        recurrence: duty.recurrence.rawValue,
        nextDueAt: duty.nextDueAt
      )
    }
    if let policy = schedulePolicies.first(where: { $0.employeeID == employeeID && !$0.isPaused }) {
      return .schedule(
        subject: policy.subject.id,
        recurrence: Self.describe(policy.plan.recurrence),
        nextDueAt: nextExpectedStart(forPolicy: policy.id)
      )
    }
    return .onRequestOnly
  }

  /// The next window this policy has that has not finished yet.
  private func nextExpectedStart(forPolicy policyID: String) -> Date? {
    occurrences(forPolicy: policyID)
      .first { !$0.status.isTerminal }?
      .window.start
  }

  private func routineInputs(for employeeID: String, contract: WorkingContract?) -> [String] {
    var inputs: [String] = []
    if contract?.boundaries.mayReadOrganizationFiles ?? true {
      inputs.append("The organization folder, read-only")
    }
    inputs.append("This employee's own home at `employees/\(employeeID)`")
    if !productBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      inputs.append("The product brief")
    }
    let memories = knowledge?.memoryEntries.filter { $0.employeeID == employeeID }.count ?? 0
    if memories > 0 {
      inputs.append("\(memories) durable memory entr\(memories == 1 ? "y" : "ies")")
    }
    let inherited = artifacts.filter { $0.authorID != employeeID }.count
    if inherited > 0 { inputs.append("Artifacts other employees have already produced") }
    return inputs
  }

  private func routineOutputs(for employeeID: String, skills: [SkillDefinition]) -> [String] {
    var outputs = ["A local artifact under `employees/\(employeeID)`, one per ticket"]
    outputs.append("A run receipt recording what the run actually amounted to")
    if !skills.isEmpty {
      outputs.append(
        "Work judged against: " + skills.map(\.name).sorted().joined(separator: ", "))
    }
    return outputs
  }

  private func routineReviewerName(for employeeID: String) -> String? {
    if let duty = employeeDuties.first(where: { $0.assigneeID == employeeID }) {
      return employee(duty.reviewerID)?.name ?? duty.reviewerID
    }
    return nil
  }

  private static func describe(_ recurrence: ScheduleRecurrence) -> String {
    switch recurrence {
    case .oneTime: "once"
    case .everyDays(let days): days == 1 ? "every day" : "every \(days) days"
    case .weekly: "weekly"
    }
  }
}

extension EmployeeRoutine {
  /// The `ROUTINES.md` projection.
  ///
  /// Identifiers and availability only — no credential value has a place here,
  /// for the same reason the working-contract projection carries none.
  public var markdown: String {
    var lines: [String] = [
      "# Routine · \(employeeName)",
      "",
      "- Employee ID: `\(employeeID)`",
      "- Role: \(role)",
      "- Working contract revision: \(contractRevision)",
      "",
      "This file is generated from `organization.json` and the working contract.",
      "The contract is canonical; this is a projection, so editing it changes nothing.",
      "",
      "## What recurs",
      "",
      "\(cadence.summary)",
    ]
    if let due = cadence.nextDueAt {
      lines.append("")
      lines.append("- Next expected: \(due.formatted(.iso8601))")
    }
    if let openCommitment {
      lines.append("")
      lines.append("- Currently open: \(openCommitment)")
    }
    lines += [
      "",
      "## Responsibility",
      "",
      responsibility,
      "",
      "## Inputs",
      "",
      bulleted(inputs, empty: "No inputs are available to this employee."),
      "",
      "## Expected outputs",
      "",
      bulleted(expectedOutputs, empty: "No outputs are defined."),
      "",
      "## Assigned skills",
      "",
      bulleted(
        assignedSkillNames,
        empty: "No skills assigned. This is an explicit coverage gap, not a default."),
      "",
      "## Authority",
      "",
      bulleted(
        requiredCapabilityIDs.map { "`\($0)`" },
        empty: "No capabilities granted. Anything needing one blocks and asks."),
      "",
      "Declared connections: "
        + (declaredConnectionIDs.isEmpty
          ? "none" : declaredConnectionIDs.map { "`\($0)`" }.joined(separator: ", ")),
      "",
      "## Boundaries",
      "",
      "- Read the organization folder: \(yesNo(boundaries.mayReadOrganizationFiles))",
      "- Write its own home: \(yesNo(boundaries.mayWriteEmployeeHome))",
      "- Ask a coworker for help: \(yesNo(boundaries.mayDelegate))",
      "- Use external tools: \(yesNo(boundaries.mayUseExternalTools))",
      "- Publish anywhere: \(yesNo(boundaries.mayPublish))",
      "- Maximum revisions: \(boundaries.maximumRevisions)",
      "",
      "## Review",
      "",
      "- Plan review policy: `\(reviewPolicy.rawValue)`",
      "- Reviewer: \(reviewerName ?? "the owner")",
      "",
      "## Execution",
      "",
      "- Agent: `\(executionProvider.rawValue)`",
      "- Model: \(modelName ?? "the runtime's own default")",
      "",
      "## Last run",
      "",
      lastRunSection,
      "",
    ]
    return lines.joined(separator: "\n")
  }

  private var lastRunSection: String {
    guard let lastRun else {
      return "This employee has not run yet. Nothing is being claimed about work it has not done."
    }
    var section = [
      "- \(lastRun.headline)",
      "- Summary: \(lastRun.result.summary)",
      "- \(lastRun.result.evidenceStatement)",
      "- Next: \(lastRun.nextAction.statement)",
    ]
    if let runtimeKind = lastRun.work.runtimeKind {
      section.append("- Ran on: `\(runtimeKind)`")
    }
    if let actual = lastRun.actual {
      section.append("- Started: \(actual.startedAt.formatted(.iso8601))")
    } else {
      section.append("- Started: never")
    }
    return section.joined(separator: "\n")
  }

  private func bulleted(_ values: [String], empty: String) -> String {
    values.isEmpty ? empty : values.map { "- \($0)" }.joined(separator: "\n")
  }

  private func yesNo(_ value: Bool) -> String { value ? "Yes" : "No" }
}
