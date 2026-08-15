import Foundation
import XCTest

@testable import AgentOfficeCore

/// A third-party runtime that Office OS did not write, used to prove the seam
/// holds for drivers the host knows nothing about.
private struct FakeRuntimeDriver: RuntimeDriver {
  let kind = RuntimeDriverKind("test.fake")
  let version: Int
  let declaredCapabilities: Set<RuntimeCapability>
  let secretConfigurationFields: Set<String>
  let requiredConfigurationFields: Set<String>
  let health: RuntimeAvailability
  let acceptsCursor: Bool

  init(
    version: Int = 1,
    capabilities: Set<RuntimeCapability> = [.planning, .execution, .review, .resumption],
    secretFields: Set<String> = ["apiKey"],
    requiredFields: Set<String> = [],
    health: RuntimeAvailability = .available,
    acceptsCursor: Bool = true
  ) {
    self.version = version
    self.declaredCapabilities = capabilities
    self.secretConfigurationFields = secretFields
    self.requiredConfigurationFields = requiredFields
    self.health = health
    self.acceptsCursor = acceptsCursor
  }

  func availability() async -> RuntimeAvailability { health }

  func openSession(employeeID: String, bindingID: String, sessionID: String) async throws
    -> any RuntimeSession
  {
    FakeSession(sessionID: sessionID, bindingID: bindingID, acceptsCursor: acceptsCursor)
  }
}

private struct FakeSession: RuntimeSession {
  let sessionID: String
  let bindingID: String
  let acceptsCursor: Bool

  func run(_ turn: RuntimeTurn) async throws -> RuntimeTurnResult {
    if turn.resumeCursor != nil, !acceptsCursor { throw RuntimeSessionError.staleResumeCursor }
    var log = RuntimeEventLog(bindingID: bindingID, sessionID: sessionID)
    try log.record(
      RuntimeEvent(
        kind: .turnStarted,
        origin: RuntimeEventOrigin(
          employeeID: turn.employeeID, bindingID: bindingID, sessionID: sessionID,
          commitmentID: turn.commitmentID, correlationID: turn.correlationID),
        summary: "fake turn"))
    return RuntimeTurnResult(
      output: EmployeeWorkOutput(title: "fake", summary: "fake", content: "fake"),
      events: log.events,
      resumeCursor: "cursor-\(sessionID)",
      rawDiagnostics: "provider-native noise"
    )
  }

  func interrupt() async {}
  func stop() async {}
}

final class RuntimeDriverTests: XCTestCase {
  private func binding(
    kind: RuntimeDriverKind,
    version: Int = 1,
    configuration: RuntimeConfiguration = .empty,
    employeeID: String = "theo"
  ) -> RuntimeBinding {
    RuntimeBinding(
      id: "binding-\(employeeID)",
      employeeID: employeeID,
      driver: RuntimeDriverIdentity(kind: kind, version: version),
      configuration: configuration
    )
  }

  fileprivate func work() -> EmployeeWorkRequest {
    let state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    return EmployeeWorkRequest(
      operation: .plan,
      employee: state.employee("theo") ?? state.employees[0],
      task: WorkTask(
        id: "task-1", title: "Draft", detail: "", kind: .draft, status: .ready,
        assigneeID: "theo", reviewerID: nil, dependencyIDs: [], artifactIDs: [],
        revisionCount: 0, maxRevisions: 1, updatedAt: Date(timeIntervalSince1970: 1_000)),
      organizationName: "Willow Studio",
      outcome: "Draft the launch note",
      context: "",
      workspaceURL: URL(fileURLWithPath: NSTemporaryDirectory())
    )
  }

  // MARK: - Contract parity

  func testBuiltInAndThirdPartyDriversSatisfyTheSameContract() async throws {
    let drivers: [any RuntimeDriver] = [
      DemoRuntimeDriver(), FakeRuntimeDriver(),
    ]
    for driver in drivers {
      XCTAssertFalse(driver.kind.rawValue.isEmpty)
      XCTAssertGreaterThan(driver.version, 0)
      XCTAssertTrue(driver.supports(.execution))
      let availability = await driver.availability()
      XCTAssertEqual(availability, .available)

      let session = try await driver.openSession(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1")
      XCTAssertEqual(session.sessionID, "session-1")
      XCTAssertEqual(session.bindingID, "binding-theo")

      let result = try await session.run(
        RuntimeTurn(
          employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
          commitmentID: "commitment-1", correlationID: "correlation-1", work: work()))
      XCTAssertFalse(result.output.summary.isEmpty)
      XCTAssertTrue(result.events.allSatisfy { $0.sessionID == "session-1" })
    }
  }

  func testUnknownDriverRunsWithoutDomainModelChanges() async throws {
    let registry = RuntimeDriverRegistry()
    await registry.register(FakeRuntimeDriver())
    let resolution = await registry.resolve(binding(kind: RuntimeDriverKind("test.fake")))

    let driver = try XCTUnwrap(resolution.driver)
    let session = try await driver.openSession(
      employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1")
    let result = try await session.run(
      RuntimeTurn(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
        commitmentID: "commitment-1", correlationID: "correlation-1", work: work()))
    XCTAssertEqual(result.output.summary, "fake")
  }

  // MARK: - Configuration

  func testSecretValueInASecretFieldIsRejected() throws {
    let driver = FakeRuntimeDriver()
    let configuration = RuntimeConfiguration(values: ["apiKey": .literal("sk-real-secret")])

    XCTAssertThrowsError(try driver.validate(configuration)) { error in
      XCTAssertEqual(
        error as? RuntimeConfigurationError, .secretValueSuppliedDirectly(field: "apiKey"))
    }
  }

  func testSecretReferenceIsAccepted() throws {
    let driver = FakeRuntimeDriver()
    let configuration = RuntimeConfiguration(
      values: ["apiKey": .secretReference("keychain://office/theo")])
    XCTAssertNoThrow(try driver.validate(configuration))
  }

  func testMissingRequiredFieldIsRejected() throws {
    let driver = FakeRuntimeDriver(requiredFields: ["endpoint"])
    XCTAssertThrowsError(try driver.validate(.empty)) { error in
      XCTAssertEqual(error as? RuntimeConfigurationError, .missingRequiredField("endpoint"))
    }
  }

  // MARK: - Unavailable shadows

  func testMissingDriverProducesANamedShadow() async {
    let registry = RuntimeDriverRegistry()
    let resolution = await registry.resolve(binding(kind: RuntimeDriverKind("test.absent")))

    let shadow = resolution.shadow
    XCTAssertEqual(shadow?.cause, .driverNotInstalled(RuntimeDriverKind("test.absent")))
    XCTAssertEqual(shadow?.employeeID, "theo")
    XCTAssertTrue(shadow?.reason.contains("test.absent") == true)
  }

  func testDriverOlderThanTheBindingIsIncompatible() async {
    let registry = RuntimeDriverRegistry(drivers: [FakeRuntimeDriver(version: 1)])
    let resolution = await registry.resolve(
      binding(kind: RuntimeDriverKind("test.fake"), version: 4))

    XCTAssertEqual(
      resolution.shadow?.cause, .driverOlderThanBinding(installed: 1, required: 4))
  }

  func testMisconfiguredDriverIsShadowedNotRun() async {
    let registry = RuntimeDriverRegistry(drivers: [FakeRuntimeDriver()])
    let resolution = await registry.resolve(
      binding(
        kind: RuntimeDriverKind("test.fake"),
        configuration: RuntimeConfiguration(values: ["apiKey": .literal("sk-real-secret")])))

    guard case .misconfigured = resolution.shadow?.cause else {
      return XCTFail(
        "expected a misconfigured shadow, got \(String(describing: resolution.shadow))")
    }
    XCTAssertNil(resolution.driver)
  }

  func testUnhealthyDriverDoesNotDisableOtherEmployees() async {
    let registry = RuntimeDriverRegistry(drivers: [
      FakeRuntimeDriver(health: .unavailable(reason: "the fake runtime is down")),
      DemoRuntimeDriver(),
    ])

    let broken = await registry.resolve(binding(kind: RuntimeDriverKind("test.fake")))
    let working = await registry.resolve(binding(kind: .demo, employeeID: "nia"))

    XCTAssertEqual(broken.shadow?.cause, .unhealthy("the fake runtime is down"))
    XCTAssertNotNil(working.driver)
  }

  func testCodexDriverReportsUnavailableInsteadOfSubstitutingTheDemoRuntime() async {
    let driver = LocalCodexRuntimeDriver()
    let availability = await driver.availability()
    if CodexEmployeeRunner.discover() == nil {
      XCTAssertFalse(availability.isAvailable)
      XCTAssertTrue(availability.reason?.contains("Codex") == true)
    } else {
      XCTAssertTrue(availability.isAvailable)
    }
  }

  // MARK: - Event origin

  func testEventsFromAnotherSessionAreRejected() throws {
    var log = RuntimeEventLog(bindingID: "binding-theo", sessionID: "session-1")
    let foreign = RuntimeEvent(
      kind: .assistantOutput,
      origin: RuntimeEventOrigin(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-2",
        correlationID: "correlation-1"),
      summary: "not mine")

    XCTAssertThrowsError(try log.record(foreign)) { error in
      XCTAssertEqual(
        error as? RuntimeEventError,
        .foreignOrigin(expectedBinding: "binding-theo", expectedSession: "session-1"))
    }
    XCTAssertTrue(log.events.isEmpty)
  }

  func testRuntimeEvidenceStaysDistinctFromOrganizationTruth() async throws {
    let driver = FakeRuntimeDriver()
    let session = try await driver.openSession(
      employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1")
    let result = try await session.run(
      RuntimeTurn(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
        commitmentID: "commitment-1", correlationID: "correlation-1", work: work()))

    // Three layers, three carriers: provider noise, normalized events, and the
    // organization journal, which this turn did not touch.
    XCTAssertEqual(result.rawDiagnostics, "provider-native noise")
    XCTAssertEqual(result.events.map(\.kind), [.turnStarted])
    XCTAssertFalse(result.events.contains { $0.summary.contains("provider-native noise") })
  }

  func testProposedCommandIsAttributedToTheRuntimeAndStillNeedsAuthorization() {
    let proposal = ProposedOrganizationCommand(
      payload: .assignEmployeeOutcome(
        .init(employeeID: "theo", outcome: "Give myself work", context: "")),
      employeeID: "theo",
      sessionID: "session-1",
      correlationID: "correlation-1",
      idempotencyKey: "proposal-1"
    )

    let command = proposal.command()
    XCTAssertEqual(command.actor, .employeeRuntime(employeeID: "theo", sessionID: "session-1"))
    XCTAssertFalse(command.actor.isOwner)
  }

  // MARK: - Bindings

  func testReboundEmployeeKeepsIdentityAndGainsProvenance() {
    let original = binding(kind: .demo)
    let moved = original.rebound(
      to: RuntimeDriverIdentity(kind: RuntimeDriverKind("test.fake"), version: 2),
      reason: "Owner moved Theo to the fake runtime",
      now: Date(timeIntervalSince1970: 10_000)
    )

    XCTAssertEqual(moved.employeeID, original.employeeID)
    XCTAssertEqual(moved.id, original.id)
    XCTAssertEqual(moved.driverKind, RuntimeDriverKind("test.fake"))
    XCTAssertEqual(moved.provenance.count, 1)
    XCTAssertEqual(moved.provenance[0].driver.kind, .demo)
    XCTAssertNil(moved.resume)
  }

  func testOrganizationWithoutBindingsDerivesOneFromItsExecutionProvider() {
    var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    state.knowledge?.runtimeBindings = []

    let derived = state.effectiveRuntimeBinding(for: "theo")
    XCTAssertEqual(derived.employeeID, "theo")
    XCTAssertEqual(derived.driverVersion, 1)
    XCTAssertTrue([RuntimeDriverKind.demo, .localCodex].contains(derived.driverKind))
    XCTAssertTrue(state.runtimeBindings.isEmpty, "deriving a binding must not mutate state")
  }

  func testResumeCursorIsStoredOnTheBindingNotEmployeeMemory() {
    var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    state.setRuntimeBinding(binding(kind: .demo))
    let memoryBefore = state.knowledge?.memoryEntries.count ?? 0

    XCTAssertTrue(
      state.recordRuntimeResume(employeeID: "theo", sessionID: "session-1", cursor: "cursor-1"))

    XCTAssertEqual(state.runtimeBinding(for: "theo")?.resume?.cursor, "cursor-1")
    XCTAssertEqual(state.runtimeBinding(for: "theo")?.resume?.sessionID, "session-1")
    XCTAssertEqual(state.knowledge?.memoryEntries.count, memoryBefore)
  }

  func testStaleCursorFailsRecoverablyAndAFreshSessionWorks() async throws {
    let driver = FakeRuntimeDriver(acceptsCursor: false)
    let session = try await driver.openSession(
      employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1")

    do {
      _ = try await session.run(
        RuntimeTurn(
          employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
          commitmentID: "commitment-1", correlationID: "correlation-1", work: work(),
          resumeCursor: "stale"))
      XCTFail("a stale cursor should not be accepted")
    } catch {
      XCTAssertEqual(error as? RuntimeSessionError, .staleResumeCursor)
    }

    var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    state.setRuntimeBinding(binding(kind: .demo))
    state.recordRuntimeResume(employeeID: "theo", sessionID: "session-1", cursor: "stale")
    state.recordRuntimeResume(employeeID: "theo", sessionID: nil, cursor: nil)

    XCTAssertNil(state.runtimeBinding(for: "theo")?.resume)
    XCTAssertNotNil(state.employee("theo"), "identity survives a discarded cursor")

    let fresh = try await session.run(
      RuntimeTurn(
        employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1",
        commitmentID: "commitment-1", correlationID: "correlation-1", work: work()))
    XCTAssertEqual(fresh.output.summary, "fake")
  }

  func testBindingsSurviveEncodingAndDecoding() throws {
    var state = OrganizationState.seeded(now: Date(timeIntervalSince1970: 1_000))
    state.setRuntimeBinding(
      binding(
        kind: RuntimeDriverKind("test.fake"),
        configuration: RuntimeConfiguration(
          values: ["apiKey": .secretReference("keychain://office/theo")])))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(
      OrganizationState.self, from: try encoder.encode(state))

    XCTAssertEqual(decoded.runtimeBinding(for: "theo")?.driverKind, RuntimeDriverKind("test.fake"))
    XCTAssertEqual(
      decoded.runtimeBinding(for: "theo")?.configuration.values["apiKey"],
      .secretReference("keychain://office/theo"))
  }
}

extension RuntimeDriverTests {
  func testSessionRefusesAnotherEmployeesTurn() async throws {
    let driver = DemoRuntimeDriver()
    let session = try await driver.openSession(
      employeeID: "theo", bindingID: "binding-theo", sessionID: "session-1")

    do {
      _ = try await session.run(
        RuntimeTurn(
          employeeID: "nia", bindingID: "binding-theo", sessionID: "session-1",
          commitmentID: "commitment-1", correlationID: "correlation-1", work: work()))
      XCTFail("a session must not run another employee's turn")
    } catch {
      XCTAssertEqual(
        error as? RuntimeSessionError, .employeeMismatch(expected: "theo", found: "nia"))
    }
  }
}
