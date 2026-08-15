import Foundation

/// The layer that refused a request. Fixed order, so a denial reason is stable
/// and a broader limit can never mask a narrower one.
public enum RuntimeAuthorityLayer: String, Codable, Sendable, CaseIterable {
  case request
  case runtime
  case package
  case workingContract
  case organizationGrant
  case commitment
  case reviewPolicy
}

public enum RuntimeAuthorityDecision: Sendable, Equatable {
  /// Within authority, and policy does not require a person.
  case permitted
  /// Within authority, but a person must decide before the runtime proceeds.
  case requiresOwnerDecision
  case refused(layer: RuntimeAuthorityLayer, reason: String)

  public var refusal: (layer: RuntimeAuthorityLayer, reason: String)? {
    if case .refused(let layer, let reason) = self { return (layer, reason) }
    return nil
  }
}

/// Computes what a running employee may actually do.
///
/// Authority is the intersection of every limit: runtime support, package
/// boundaries, working-contract scope, organization grant, commitment scope, and
/// review policy. This type only reads those; it never widens them.
public struct RuntimeAuthorityEvaluator: Sendable {
  public init() {}

  public func evaluate(
    _ request: RuntimeAccessRequest,
    organization: OrganizationState,
    runtimeCapabilities: Set<RuntimeCapability>,
    now: Date = Date()
  ) -> RuntimeAuthorityDecision {
    if let refusal = requestRefusal(request, now: now) { return refusal }

    // A question is never auto-answered: judgment is the owner's, always.
    if request.need.isQuestion {
      if let refusal = commitmentRefusal(request, organization: organization) { return refusal }
      return .requiresOwnerDecision
    }

    guard let capabilityID = request.need.capabilityID else {
      return .refused(layer: .request, reason: "The request named no capability.")
    }
    if !runtimeCapabilities.contains(.toolInvocation) {
      return .refused(
        layer: .runtime,
        reason: "This employee's runtime does not support invoking tools.")
    }
    if let refusal = packageRefusal(request, organization: organization) { return refusal }
    if let refusal = contractRefusal(capabilityID, request: request, organization: organization) {
      return refusal
    }
    guard organization.hasCapability(capabilityID, employeeID: request.origin.employeeID) else {
      return .refused(
        layer: .organizationGrant,
        reason:
          "‘\(capabilityID)’ is not granted to this employee. Grant it deliberately if the work needs it."
      )
    }
    if let refusal = commitmentRefusal(request, organization: organization) { return refusal }
    return reviewPolicyDecision(request, organization: organization)
  }

  // MARK: - Layers

  private func requestRefusal(_ request: RuntimeAccessRequest, now: Date)
    -> RuntimeAuthorityDecision?
  {
    if request.isMalformed {
      return .refused(layer: .request, reason: "The runtime request was incomplete.")
    }
    if request.hasExpired(at: now) {
      return .refused(
        layer: .request, reason: "This request expired before it was answered.")
    }
    return nil
  }

  private func packageRefusal(_ request: RuntimeAccessRequest, organization: OrganizationState)
    -> RuntimeAuthorityDecision?
  {
    guard let contract = organization.workingContract(for: request.origin.employeeID) else {
      return .refused(
        layer: .workingContract,
        reason: "This employee has no working contract, so it has no authority to use tools.")
    }
    guard
      let package = organization.knowledge?.employeePackages.first(where: {
        $0.id == contract.packageID
      })
    else { return nil }
    guard package.boundaries.mayUseExternalTools else {
      return .refused(
        layer: .package,
        reason: "\(package.name) does not declare external tool use, so it cannot be granted here.")
    }
    return nil
  }

  private func contractRefusal(
    _ capabilityID: String, request: RuntimeAccessRequest, organization: OrganizationState
  ) -> RuntimeAuthorityDecision? {
    guard let contract = organization.workingContract(for: request.origin.employeeID) else {
      return .refused(
        layer: .workingContract,
        reason: "This employee has no working contract, so it has no authority to use tools.")
    }
    guard contract.boundaries.mayUseExternalTools else {
      return .refused(
        layer: .workingContract,
        reason: "This employee's working contract does not allow external tool use.")
    }
    guard contract.capabilityGrants.contains(capabilityID) else {
      return .refused(
        layer: .workingContract,
        reason:
          "‘\(capabilityID)’ is outside this employee's working contract. Revise the contract to change that."
      )
    }
    return nil
  }

  private func commitmentRefusal(
    _ request: RuntimeAccessRequest, organization: OrganizationState
  ) -> RuntimeAuthorityDecision? {
    guard let outcome = organization.employeeOutcome(request.origin.commitmentID) else {
      return .refused(
        layer: .commitment, reason: "The commitment this request belongs to no longer exists.")
    }
    guard !outcome.status.isTerminal else {
      return .refused(
        layer: .commitment,
        reason: "This commitment has already finished, so nothing more can be authorized under it.")
    }
    guard outcome.assigneeID == request.origin.employeeID else {
      return .refused(
        layer: .commitment,
        reason: "This request came from an employee who does not own that commitment.")
    }
    return nil
  }

  private func reviewPolicyDecision(
    _ request: RuntimeAccessRequest, organization: OrganizationState
  ) -> RuntimeAuthorityDecision {
    let policy = organization.workingContract(for: request.origin.employeeID)?.reviewPolicy
    switch policy {
    case .automaticForLocalWork where request.requestedScope == .once:
      return .permitted
    default:
      return .requiresOwnerDecision
    }
  }
}
