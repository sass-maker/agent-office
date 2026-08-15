import Foundation
import XCTest

@testable import AgentOfficeCore

final class RuntimeCapabilityBrokerTests: XCTestCase {
  private let toolRuntime: Set<RuntimeCapability> = [.execution, .toolInvocation]

  // MARK: - Fixtures

  /// An organization where Theo may use web research: package allows external
  /// tools, contract scopes and the organization grants the capability, and one
  /// commitment is open.
  private func authorizedOrganization(
    contractGrants: [String] = ["web-research"],
    organizationGrants: [String] = ["web-research"],
    contractAllowsTools: Bool = true,
    packageAllowsTools: Bool = true,
    reviewPolicy: PlanReviewPolicy = .always
  ) throws -> (state: OrganizationState, commitmentID: String) {
    // migrated() is what creates the working contracts hiring depends on.
    var state = LocalOrganizationStore.migrated(
      .seeded(now: Date(timeIntervalSince1970: 1_000)), now: Date(timeIntervalSince1970: 1_000))
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    if knowledgeIndex(of: "starter.theo", in: state) == nil {
      state.knowledge?.employeePackages.append(
        EmployeePackage(
          id: "starter.theo",
          version: "1.0.0",
          creator: "Office OS",
          name: "Theo",
          role: "Content Writer",
          responsibility: "Write",
          avatarColor: "7395A8",
          skills: [],
          boundaries: AutonomyBoundaries(mayUseExternalTools: packageAllowsTools)
        ))
    } else if let index = knowledgeIndex(of: "starter.theo", in: state) {
      state.knowledge?.employeePackages[index].boundaries = AutonomyBoundaries(
        mayUseExternalTools: packageAllowsTools)
    }

    try state.updateWorkingContract(
      employeeID: "theo",
      role: "Content Writer",
      responsibility: "Write",
      managerID: nil,
      assignedSkillIDs: ["communication"],
      declaredConnectionIDs: [],
      capabilityGrants: contractGrants,
      executionProvider: .demo,
      modelName: nil,
      boundaries: AutonomyBoundaries(mayUseExternalTools: contractAllowsTools),
      reviewPolicy: reviewPolicy,
      actorID: "owner",
      reason: "test fixture"
    )
    // Set the organization-level grant after the contract: updating a contract
    // syncs its grants onto the employee, and these tests need the two layers to
    // be able to disagree.
    if let index = state.employees.firstIndex(where: { $0.id == "theo" }) {
      state.employees[index].capabilityGrants = organizationGrants
    }

    let commitmentID = try state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft the launch note", context: "")
    return (state, commitmentID)
  }

  private func knowledgeIndex(of packageID: String, in state: OrganizationState) -> Int? {
    state.knowledge?.employeePackages.firstIndex { $0.id == packageID }
  }

  private func request(
    commitmentID: String,
    capability: String = "web-research",
    id: String = "request-1",
    sessionID: String = "session-1",
    occurrenceID: String? = "occurrence-1",
    scope: RuntimeApprovalScope = .once,
    summary: String = "Search two sources",
    createdAt: Date = Date(timeIntervalSince1970: 2_000),
    expiresAfter: TimeInterval = 300,
    providerSuggestsAlwaysAllow: Bool = false
  ) -> RuntimeAccessRequest {
    RuntimeAccessRequest(
      id: id,
      origin: RuntimeAccessOrigin(
        employeeID: "theo", bindingID: "binding-theo", sessionID: sessionID,
        commitmentID: commitmentID, occurrenceID: occurrenceID),
      need: .capability(id: capability, action: "search the web"),
      context: RuntimeAccessContext(
        inputSummary: summary,
        riskNote: "Reads public pages only.",
        providerSuggestedAlwaysAllow: providerSuggestsAlwaysAllow
      ),
      requestedScope: scope,
      createdAt: createdAt,
      expiresAfter: expiresAfter
    )
  }

  private var now: Date { Date(timeIntervalSince1970: 2_100) }

  // MARK: - Containment

  func testAuthorizedCapabilityStillWaitsForTheOwner() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    XCTAssertEqual(outcome, .awaitingOwner(requestID: "request-1"))
    let pending = await broker.pendingRequests()
    XCTAssertEqual(pending.map(\.id), ["request-1"])
  }

  func testQuestionIsNeverAnsweredAutomatically() async throws {
    let fixture = try authorizedOrganization(reviewPolicy: .automaticForLocalWork)
    let broker = RuntimeCapabilityBroker()
    let question = RuntimeAccessRequest(
      id: "question-1",
      origin: RuntimeAccessOrigin(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
        commitmentID: fixture.commitmentID),
      need: .question(prompt: "Should I contact the customer directly?"),
      createdAt: Date(timeIntervalSince1970: 2_000)
    )

    let outcome = await broker.submit(
      question, organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    XCTAssertEqual(outcome, .awaitingOwner(requestID: "question-1"))
  }

  // MARK: - Authority layers

  func testRuntimeWithoutToolSupportIsRefused() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: [.execution], now: now)

    XCTAssertEqual(
      outcome, .denied(reason: "This employee's runtime does not support invoking tools."))
  }

  func testPackageThatDoesNotDeclareToolsRefuses() async throws {
    let fixture = try authorizedOrganization(packageAllowsTools: false)
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    guard case .denied(let reason) = outcome else { return XCTFail("expected a denial") }
    XCTAssertTrue(reason.contains("does not declare external tool use"))
  }

  func testGrantedButOutOfContractIsRefused() async throws {
    let fixture = try authorizedOrganization(contractGrants: [])
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    guard case .denied(let reason) = outcome else { return XCTFail("expected a denial") }
    XCTAssertTrue(reason.contains("outside this employee's working contract"))
  }

  func testInContractButUngrantedIsRefused() async throws {
    let fixture = try authorizedOrganization(organizationGrants: [])
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    guard case .denied(let reason) = outcome else { return XCTFail("expected a denial") }
    XCTAssertTrue(reason.contains("is not granted to this employee"))
  }

  func testFinishedCommitmentIsRefused() async throws {
    var fixture = try authorizedOrganization()
    _ = fixture.state.updateEmployeeOutcome(fixture.commitmentID) { $0.status = .accepted }
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    guard case .denied(let reason) = outcome else { return XCTFail("expected a denial") }
    XCTAssertTrue(reason.contains("already finished"))
  }

  func testUnknownCapabilityIsRefused() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()

    let outcome = await broker.submit(
      request(commitmentID: fixture.commitmentID, capability: "delete-production-database"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    guard case .denied = outcome else { return XCTFail("an unrecognized capability must deny") }
  }

  func testMalformedRequestIsRefused() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    let malformed = RuntimeAccessRequest(
      id: "malformed-1",
      origin: RuntimeAccessOrigin(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
        commitmentID: fixture.commitmentID),
      need: .capability(id: "  ", action: ""),
      createdAt: Date(timeIntervalSince1970: 2_000)
    )

    let outcome = await broker.submit(
      malformed, organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    XCTAssertEqual(outcome, .denied(reason: "The runtime request was incomplete."))
  }

  // MARK: - Scopes

  func testAllowOnceDoesNotCoverASecondUse() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    _ = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .once), actor: .owner(id: "owner"), now: now)

    let second = await broker.submit(
      request(commitmentID: fixture.commitmentID, id: "request-2"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    XCTAssertEqual(second, .awaitingOwner(requestID: "request-2"))
  }

  func testAllowForCommitmentCoversLaterRequestsInThatCommitmentOnly() async throws {
    var fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    _ = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .commitment), actor: .owner(id: "owner"),
      now: now)

    let sameCommitment = await broker.submit(
      request(commitmentID: fixture.commitmentID, id: "request-2", sessionID: "session-2"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    XCTAssertEqual(sameCommitment, .allowed)

    _ = fixture.state.updateEmployeeOutcome(fixture.commitmentID) { $0.status = .accepted }
    let otherCommitmentID = try fixture.state.createEmployeeOutcome(
      employeeID: "theo", outcome: "Another outcome", context: "")
    let otherCommitment = await broker.submit(
      request(commitmentID: otherCommitmentID, id: "request-3"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    XCTAssertEqual(otherCommitment, .awaitingOwner(requestID: "request-3"))
  }

  func testProviderAlwaysAllowSuggestionCreatesNoDurableGrant() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    let suggested = request(commitmentID: fixture.commitmentID, providerSuggestsAlwaysAllow: true)

    _ = await broker.submit(
      suggested, organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    _ = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .once), actor: .owner(id: "owner"), now: now)

    // The employee's durable authority is untouched by the suggestion.
    XCTAssertEqual(
      fixture.state.workingContract(for: "theo")?.capabilityGrants, ["web-research"])
    let next = await broker.submit(
      request(commitmentID: fixture.commitmentID, id: "request-2"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    XCTAssertEqual(next, .awaitingOwner(requestID: "request-2"))
  }

  // MARK: - Failing closed

  func testExpiredRequestDenies() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID, expiresAfter: 60),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    await broker.expirePending(now: Date(timeIntervalSince1970: 9_000))

    let recorded = await broker.recordedResolution(for: "request-1")
    XCTAssertEqual(
      recorded, .denied(reason: "This request expired before it was answered."))
    let pending = await broker.pendingRequests()
    XCTAssertTrue(pending.isEmpty)
  }

  func testUnrecordableDecisionDeniesAndStoresNoApproval() async throws {
    let fixture = try authorizedOrganization()
    struct RecorderDown: Error {}
    let broker = RuntimeCapabilityBroker(recorder: { _, _ in throw RecorderDown() })

    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    let resolution = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .commitment), actor: .owner(id: "owner"),
      now: now)

    XCTAssertEqual(
      resolution,
      .denied(reason: "The decision could not be recorded, so access was refused."))
    let next = await broker.submit(
      request(commitmentID: fixture.commitmentID, id: "request-2"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    XCTAssertNotEqual(next, .allowed)
  }

  func testOnlyTheOwnerCanResolve() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)

    do {
      _ = try await broker.resolve(
        requestID: "request-1", with: .allowed(scope: .commitment),
        actor: .employeeRuntime(employeeID: "theo", sessionID: "session-1"), now: now)
      XCTFail("a runtime must not answer its own request")
    } catch {
      XCTAssertEqual(error as? RuntimeBrokerError, .notOwner)
    }
  }

  // MARK: - Idempotency and staleness

  func testDuplicateRequestIdentifierProducesNoSecondEffect() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    _ = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .once), actor: .owner(id: "owner"), now: now)

    let repeated = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    let resolvedAgain = try await broker.resolve(
      requestID: "request-1", with: .denied(reason: "changed my mind"),
      actor: .owner(id: "owner"), now: now)

    XCTAssertEqual(repeated, .allowed)
    XCTAssertEqual(resolvedAgain, .allowed(scope: .once))
  }

  func testResolutionForAnEndedSessionIsRejected() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    await broker.endSession("session-1")

    do {
      _ = try await broker.resolve(
        requestID: "request-1", with: .allowed(scope: .commitment), actor: .owner(id: "owner"),
        now: now)
      XCTFail("a late answer must not authorize an ended session")
    } catch {
      XCTAssertEqual(error as? RuntimeBrokerError, .resolutionForEndedSession("request-1"))
    }
  }

  // MARK: - Injection and revocation

  func testSessionReceivesOnlyCurrentlyAuthorizedCapabilities() async throws {
    let fixture = try authorizedOrganization(
      contractGrants: ["web-research", "publishing"], organizationGrants: ["web-research"])
    let broker = RuntimeCapabilityBroker()

    let injected = await broker.authorizedCapabilities(
      employeeID: "theo", commitmentID: fixture.commitmentID, organization: fixture.state)

    XCTAssertEqual(injected, ["web-research"])
  }

  func testRevocationRejectsLaterUseAndInterruptsAffectedWork() async throws {
    let fixture = try authorizedOrganization()
    let broker = RuntimeCapabilityBroker()
    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    _ = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .commitment), actor: .owner(id: "owner"),
      now: now)

    await broker.revoke(capabilityID: "web-research", employeeID: "theo")

    let afterRevocation = await broker.submit(
      request(commitmentID: fixture.commitmentID, id: "request-2"),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    let interrupted = await broker.isInterrupted(commitmentID: fixture.commitmentID)

    XCTAssertEqual(afterRevocation, .awaitingOwner(requestID: "request-2"))
    XCTAssertTrue(interrupted)
  }

  func testFinishedCommitmentInjectsNothing() async throws {
    var fixture = try authorizedOrganization()
    _ = fixture.state.updateEmployeeOutcome(fixture.commitmentID) { $0.status = .accepted }
    let broker = RuntimeCapabilityBroker()

    let injected = await broker.authorizedCapabilities(
      employeeID: "theo", commitmentID: fixture.commitmentID, organization: fixture.state)

    XCTAssertTrue(injected.isEmpty)
  }

  // MARK: - Secrets

  func testSecretShapedContentIsRedactedFromRequests() throws {
    let fixture = try authorizedOrganization()
    let leaky = request(
      commitmentID: fixture.commitmentID,
      summary: "call with api_key=sk-live-9f8a7b6c5d4e3f2a and Bearer ghp_ABCDEFGH12345678")

    XCTAssertFalse(leaky.inputSummary.contains("sk-live-9f8a7b6c5d4e3f2a"))
    XCTAssertFalse(leaky.inputSummary.contains("ghp_ABCDEFGH12345678"))
    XCTAssertTrue(leaky.inputSummary.contains("[redacted]"))
  }

  func testConnectionsTravelAsHandles() throws {
    let fixture = try authorizedOrganization()
    let withConnection = RuntimeAccessRequest(
      id: "request-connection",
      origin: RuntimeAccessOrigin(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
        commitmentID: fixture.commitmentID),
      need: .capability(id: "web-research", action: "search"),
      context: RuntimeAccessContext(connectionHandles: ["connection://research-proxy"]),
      createdAt: Date(timeIntervalSince1970: 2_000)
    )

    XCTAssertEqual(withConnection.connectionHandles, ["connection://research-proxy"])
    XCTAssertFalse(withConnection.inputSummary.contains("://"))
  }

  // MARK: - Receipts

  func testEveryDecisionProducesOneCorrelatedReceipt() async throws {
    let fixture = try authorizedOrganization()
    actor Receipts {
      var entries: [(String, RuntimeAccessResolution)] = []
      func append(_ id: String, _ resolution: RuntimeAccessResolution) {
        entries.append((id, resolution))
      }
      func all() -> [(String, RuntimeAccessResolution)] { entries }
    }
    let receipts = Receipts()
    let broker = RuntimeCapabilityBroker(recorder: { request, resolution in
      let id = request.id
      Task { await receipts.append(id, resolution) }
    })

    _ = await broker.submit(
      request(commitmentID: fixture.commitmentID),
      organization: fixture.state, runtimeCapabilities: toolRuntime, now: now)
    _ = try await broker.resolve(
      requestID: "request-1", with: .allowed(scope: .once), actor: .owner(id: "owner"), now: now)
    try await Task.sleep(for: .milliseconds(50))

    let entries = await receipts.all()
    XCTAssertEqual(entries.map(\.0), ["request-1"])
    XCTAssertEqual(entries.first?.1, .allowed(scope: .once))
  }
}
