import Foundation

/// A permission that exists only for a single use, occurrence, or commitment.
///
/// Deliberately not a grant and deliberately not persisted: restarting the app
/// must not silently retain permission.
public struct RuntimeScopedApproval: Sendable, Equatable {
  public var capabilityID: String
  public var employeeID: String
  public var scope: RuntimeApprovalScope
  public var sessionID: String
  public var commitmentID: String
  public var occurrenceID: String?

  public func covers(_ request: RuntimeAccessRequest) -> Bool {
    guard capabilityID == request.need.capabilityID,
      employeeID == request.origin.employeeID,
      commitmentID == request.origin.commitmentID
    else { return false }
    switch scope {
    case .once:
      // `once` never becomes a standing approval, so nothing is covered by it.
      return false
    case .occurrence:
      return occurrenceID != nil && occurrenceID == request.origin.occurrenceID
    case .commitment:
      return true
    }
  }
}

public enum RuntimeBrokerError: LocalizedError, Equatable {
  case unknownRequest(String)
  case resolutionForEndedSession(String)
  case notOwner

  public var errorDescription: String? {
    switch self {
    case .unknownRequest(let id):
      "There is no open runtime request \(id) to answer."
    case .resolutionForEndedSession(let id):
      "Request \(id) belongs to a session that has ended, so this answer cannot be applied."
    case .notOwner:
      "Only the owner can answer a runtime request."
    }
  }
}

/// The one place that decides what a running employee may actually do.
///
/// The broker reads the durable authority model — package boundaries, working
/// contracts, organization grants, commitment scope, review policy — and never
/// writes a new one. Everything it cannot confirm, it denies.
public actor RuntimeCapabilityBroker {
  /// Writes the receipt for a decision. Returning normally is what makes a
  /// resolution valid; throwing means the decision was never recorded, so the
  /// request is denied and no approval is retained.
  public typealias ReceiptRecorder =
    @Sendable (RuntimeAccessRequest, RuntimeAccessResolution)
    async throws -> Void

  private let evaluator = RuntimeAuthorityEvaluator()
  private let recorder: ReceiptRecorder
  private var pending: [String: RuntimeAccessRequest] = [:]
  private var resolutions: [String: RuntimeAccessResolution] = [:]
  private var approvals: [RuntimeScopedApproval] = []
  private var endedSessions: Set<String> = []
  private var interruptedCommitments: Set<String> = []

  public init(recorder: @escaping ReceiptRecorder = { _, _ in }) {
    self.recorder = recorder
  }

  // MARK: - Submitting

  /// Asks for permission. A pending result means the runtime must wait.
  public enum Outcome: Sendable, Equatable {
    case allowed
    case denied(reason: String)
    case awaitingOwner(requestID: String)
  }

  public func submit(
    _ request: RuntimeAccessRequest,
    organization: OrganizationState,
    runtimeCapabilities: Set<RuntimeCapability>,
    now: Date = Date()
  ) async -> Outcome {
    // A repeated request identifier can never produce a second effect.
    if let existing = resolutions[request.id] { return outcome(for: existing) }
    if pending[request.id] != nil { return .awaitingOwner(requestID: request.id) }

    if let approval = approvals.first(where: { $0.covers(request) }) {
      return await record(request, .allowed(scope: approval.scope))
    }

    switch evaluator.evaluate(
      request, organization: organization, runtimeCapabilities: runtimeCapabilities, now: now)
    {
    case .refused(_, let reason):
      return await record(request, .denied(reason: reason))
    case .permitted:
      return await record(request, .allowed(scope: .once))
    case .requiresOwnerDecision:
      pending[request.id] = request
      return .awaitingOwner(requestID: request.id)
    }
  }

  // MARK: - Resolving

  /// Settles a pending request. Only the owner may do this, and only for the
  /// session the request belongs to.
  @discardableResult
  public func resolve(
    requestID: String,
    with resolution: RuntimeAccessResolution,
    actor: OrganizationActor,
    now: Date = Date()
  ) async throws -> RuntimeAccessResolution {
    if let existing = resolutions[requestID] { return existing }
    guard actor.isOwner else { throw RuntimeBrokerError.notOwner }
    guard let request = pending[requestID] else {
      throw RuntimeBrokerError.unknownRequest(requestID)
    }
    guard !endedSessions.contains(request.origin.sessionID) else {
      pending[requestID] = nil
      throw RuntimeBrokerError.resolutionForEndedSession(requestID)
    }

    var settled = resolution
    if request.hasExpired(at: now) {
      settled = .denied(reason: "This request expired before it was answered.")
    }
    do {
      try await recorder(request, settled)
    } catch {
      // Fail closed: an unrecorded decision is not a decision.
      let denial = RuntimeAccessResolution.denied(
        reason: "The decision could not be recorded, so access was refused.")
      pending[requestID] = nil
      resolutions[requestID] = denial
      return denial
    }

    pending[requestID] = nil
    resolutions[requestID] = settled
    // `once` authorizes the request being answered and nothing after it, so it
    // leaves no standing approval behind.
    if case .allowed(let scope) = settled, scope != .once {
      store(scope: scope, for: request)
    }
    return settled
  }

  public func pendingRequests() -> [RuntimeAccessRequest] {
    pending.values.sorted { $0.createdAt < $1.createdAt }
  }

  public func recordedResolution(for requestID: String) -> RuntimeAccessResolution? {
    resolutions[requestID]
  }

  /// Expires anything past its deadline, denying rather than leaving it open.
  public func expirePending(now: Date = Date()) async {
    for (id, request) in pending where request.hasExpired(at: now) {
      let denial = RuntimeAccessResolution.denied(
        reason: "This request expired before it was answered.")
      try? await recorder(request, denial)
      pending[id] = nil
      resolutions[id] = denial
    }
  }

  // MARK: - Injection and revocation

  /// The capabilities a session may be given right now — not a catalogue.
  public func authorizedCapabilities(
    employeeID: String,
    commitmentID: String,
    organization: OrganizationState
  ) -> Set<String> {
    guard let contract = organization.workingContract(for: employeeID),
      contract.boundaries.mayUseExternalTools,
      let outcome = organization.employeeOutcome(commitmentID),
      !outcome.status.isTerminal
    else { return [] }

    let contractScoped = Set(contract.capabilityGrants)
    let granted = contractScoped.filter { organization.hasCapability($0, employeeID: employeeID) }
    let approved =
      approvals
      .filter { $0.employeeID == employeeID && $0.commitmentID == commitmentID }
      .map(\.capabilityID)
    return Set(granted).union(approved)
  }

  /// Withdraws access. Later use is rejected and work already relying on it is
  /// marked interrupted rather than allowed to finish.
  public func revoke(capabilityID: String, employeeID: String) {
    let affected = approvals.filter {
      $0.capabilityID == capabilityID && $0.employeeID == employeeID
    }
    approvals.removeAll { $0.capabilityID == capabilityID && $0.employeeID == employeeID }
    for approval in affected { interruptedCommitments.insert(approval.commitmentID) }
  }

  public func isInterrupted(commitmentID: String) -> Bool {
    interruptedCommitments.contains(commitmentID)
  }

  public func endSession(_ sessionID: String) {
    endedSessions.insert(sessionID)
    approvals.removeAll { $0.scope == .once && $0.sessionID == sessionID }
  }

  // MARK: - Internals

  private func record(
    _ request: RuntimeAccessRequest, _ resolution: RuntimeAccessResolution
  ) async -> Outcome {
    do {
      try await recorder(request, resolution)
    } catch {
      let denial = RuntimeAccessResolution.denied(
        reason: "The decision could not be recorded, so access was refused.")
      resolutions[request.id] = denial
      return outcome(for: denial)
    }
    resolutions[request.id] = resolution
    if case .allowed(let scope) = resolution, scope != .once,
      approvals.first(where: { $0.covers(request) }) == nil
    {
      store(scope: scope, for: request)
    }
    return outcome(for: resolution)
  }

  private func outcome(for resolution: RuntimeAccessResolution) -> Outcome {
    switch resolution {
    case .allowed: .allowed
    case .denied(let reason): .denied(reason: reason)
    case .answered: .allowed
    case .contractRevisionRequested(let reason): .denied(reason: reason)
    }
  }

  private func store(scope: RuntimeApprovalScope, for request: RuntimeAccessRequest) {
    guard let capabilityID = request.need.capabilityID else { return }
    // A provider's "always allow" suggestion is recorded on the request and
    // ignored here: widening authority stays an owner action on the contract.
    approvals.append(
      RuntimeScopedApproval(
        capabilityID: capabilityID,
        employeeID: request.origin.employeeID,
        scope: scope,
        sessionID: request.origin.sessionID,
        commitmentID: request.origin.commitmentID,
        occurrenceID: request.origin.occurrenceID
      ))
  }
}
