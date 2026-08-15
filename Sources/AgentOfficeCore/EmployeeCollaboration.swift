import Foundation

/// What one employee can ask another for.
///
/// Consultation, proposal, and message stay separate: only the first produces
/// work, and none of them move accountability.
public enum CollaborationOperation: Sendable, Equatable {
  /// A bounded question answered by the target, in the target's own runtime.
  case consultation(question: String)
  /// A suggestion that existing work move. Recorded for review, never applied.
  case delegationProposal(commitmentID: String, reason: String)
  /// A structured note through the existing communication path.
  case handoffMessage(String)

  public var verb: String {
    switch self {
    case .consultation: "consultation"
    case .delegationProposal: "delegation proposal"
    case .handoffMessage: "handoff message"
    }
  }
}

/// The least context a target needs: a question and references it may already
/// see. Never transcripts, hidden prompts, or unrelated history.
public struct CollaborationContext: Sendable, Equatable {
  public var commitmentID: String
  public var artifactIDs: [String]
  public var note: String

  public init(commitmentID: String, artifactIDs: [String] = [], note: String = "") {
    self.commitmentID = commitmentID
    self.artifactIDs = artifactIDs
    self.note = note
  }
}

/// Who is asking, and what they are bringing with them.
public struct CollaborationSource: Sendable, Equatable {
  public var employeeID: String
  public var sessionID: String
  /// Employees already in this call path, oldest first. Depth and cycles are
  /// decided from this rather than broker bookkeeping, so a restarted broker
  /// cannot forget how deep a call already is.
  public var chain: [String]
  /// Capabilities the source offers to lend. Any value here is a rejection.
  public var offeredCapabilities: [String]

  public init(
    employeeID: String,
    sessionID: String,
    chain: [String] = [],
    offeredCapabilities: [String] = []
  ) {
    self.employeeID = employeeID
    self.sessionID = sessionID
    self.chain = chain
    self.offeredCapabilities = offeredCapabilities
  }
}

/// How much a collaboration may spend before it is refused.
public struct CollaborationBudget: Sendable, Equatable {
  public var deadline: Date
  public var turns: Int

  public init(deadline: Date, turns: Int = 1) {
    self.deadline = deadline
    self.turns = turns
  }
}

/// One employee asking another for something.
public struct CollaborationRequest: Sendable, Equatable {
  public var id: String
  public var correlationID: String
  public var source: CollaborationSource
  public var targetEmployeeID: String
  public var operation: CollaborationOperation
  public var context: CollaborationContext
  public var budget: CollaborationBudget

  public init(
    id: String = UUID().uuidString,
    correlationID: String,
    source: CollaborationSource,
    targetEmployeeID: String,
    operation: CollaborationOperation,
    context: CollaborationContext,
    budget: CollaborationBudget
  ) {
    self.id = id
    self.correlationID = correlationID
    self.source = source
    self.targetEmployeeID = targetEmployeeID
    self.operation = operation
    self.context = context
    self.budget = budget
  }

  public var sourceEmployeeID: String { source.employeeID }
  public var chain: [String] { source.chain }
  public var offeredCapabilities: [String] { source.offeredCapabilities }
}

public enum CollaborationRejection: LocalizedError, Equatable {
  case selfCall
  case cycle(employeeID: String)
  case depthExceeded(maximum: Int)
  case expired
  case exhaustedTurnBudget
  case borrowedCapabilities([String])
  case targetNotVisible(String)
  case targetUnavailable(reason: String)
  case missingCommitment

  public var errorDescription: String? {
    switch self {
    case .selfCall:
      "An employee cannot consult itself."
    case .cycle(let employeeID):
      "\(employeeID) is already part of this request, so continuing would loop."
    case .depthExceeded(let maximum):
      "Collaboration is limited to \(maximum) hop. Ask the owner to involve anyone further."
    case .expired:
      "This collaboration request passed its deadline before it ran."
    case .exhaustedTurnBudget:
      "This collaboration has no turns left."
    case .borrowedCapabilities(let capabilities):
      "An employee cannot lend \(capabilities.joined(separator: ", ")) to a coworker. Each employee works under its own contract."
    case .targetNotVisible(let employeeID):
      "\(employeeID) is not available to this employee for this commitment."
    case .targetUnavailable(let reason):
      reason
    case .missingCommitment:
      "The commitment this request belongs to no longer exists."
    }
  }
}

/// A coworker a runtime may ask for help, as the runtime sees them.
public struct CollaborationDirectoryEntry: Sendable, Equatable, Identifiable {
  public var id: String
  public var name: String
  public var role: String
  public var skillIDs: [String]
  public var status: EmployeeStatus
  public var isAvailable: Bool
  public var availabilityNote: String
  public var supportedOperations: [String]
}

extension OrganizationState {
  /// Coworkers visible to one employee for one commitment.
  ///
  /// The requester is never included, and an employee who is not hired is
  /// omitted entirely rather than described — availability is safe to share,
  /// employment state is not.
  public func collaborationDirectory(for employeeID: String, commitmentID: String)
    -> [CollaborationDirectoryEntry]
  {
    guard employeeOutcome(commitmentID)?.assigneeID == employeeID else { return [] }
    return
      employees
      .filter { $0.id != employeeID && $0.kind == .ai }
      .filter { $0.effectiveEmploymentState == .hired }
      .map { employee in
        let busy = activeEmployeeOutcome(for: employee.id) != nil
        return CollaborationDirectoryEntry(
          id: employee.id,
          name: employee.name,
          role: employee.role,
          skillIDs: assignedSkills(employeeID: employee.id).map(\.id),
          status: employee.status,
          isAvailable: !busy,
          availabilityNote: busy
            ? "\(employee.name) is working on their own commitment right now."
            : "Available for a bounded consultation.",
          supportedOperations: ["consultation", "delegation proposal", "handoff message"]
        )
      }
  }
}

/// One collaboration as the owner reads it back: who asked, of whom, why, and
/// what came of it.
public struct CollaborationRecord: Sendable, Equatable, Identifiable {
  public var id: String
  public var commitmentID: String
  public var respondingEmployeeID: String
  public var respondingEmployeeName: String
  public var summary: String
  public var occurredAt: Date
}

extension OrganizationState {
  /// Collaboration exchanges recorded against a commitment.
  ///
  /// Read back out of the existing management messages rather than a parallel
  /// log, so there is exactly one place cross-employee work lives.
  public func collaborationRecords(forCommitment commitmentID: String) -> [CollaborationRecord] {
    guard let outcome = employeeOutcome(commitmentID) else { return [] }
    return outcome.effectiveManagementMessages
      .filter { $0.id.hasPrefix("collaboration-") }
      .map { message in
        CollaborationRecord(
          id: message.id,
          commitmentID: commitmentID,
          respondingEmployeeID: message.actorID,
          respondingEmployeeName: employee(message.actorID)?.name ?? message.actorID,
          summary: message.message,
          occurredAt: message.createdAt
        )
      }
      .sorted { $0.occurredAt < $1.occurredAt }
  }
}
