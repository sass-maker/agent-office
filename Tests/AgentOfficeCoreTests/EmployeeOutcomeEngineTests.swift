import XCTest

@testable import AgentOfficeCore

final class EmployeeOutcomeEngineTests: XCTestCase {
  private let epoch = Date(timeIntervalSince1970: 1_000)

  func testOutcomeValidationAndIndependentEmployeeQueues() throws {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

    XCTAssertThrowsError(
      try organization.createEmployeeOutcome(
        employeeID: "maya",
        outcome: "   ",
        context: ""
      )
    ) { XCTAssertEqual($0 as? EmployeeOutcomeError, .emptyOutcome) }
    XCTAssertThrowsError(
      try organization.createEmployeeOutcome(
        employeeID: "owner",
        outcome: "Prepare a decision brief",
        context: ""
      )
    ) { XCTAssertEqual($0 as? EmployeeOutcomeError, .humanAssignee) }

    _ = try organization.createEmployeeOutcome(
      employeeID: "maya",
      outcome: "Prepare a decision brief",
      context: "Use the company profile.",
      now: Date(timeIntervalSince1970: 200)
    )
    let secondID = try organization.createEmployeeOutcome(
      employeeID: "theo",
      outcome: "Write the follow-up",
      context: ""
    )
    XCTAssertEqual(organization.employeeOutcome(secondID)?.assigneeID, "theo")
    XCTAssertEqual(organization.employeeOutcomes.filter { !$0.status.isTerminal }.count, 2)
    XCTAssertEqual(organization.activity.suffix(2).map(\.actorID), ["owner", "theo"])
  }

  func testCommunicationMigratesOnceToEveryAIEmployee() {
    var legacy = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    legacy.schemaVersion = 7
    legacy.knowledge?.skillDefinitions.removeAll { $0.id == "communication" }
    legacy.knowledge?.skillAssignments.removeAll { $0.skillID == "communication" }

    let migrated = LocalOrganizationStore.migrated(legacy, now: Date(timeIntervalSince1970: 200))
    let migratedAgain = LocalOrganizationStore.migrated(
      migrated, now: Date(timeIntervalSince1970: 300))
    let aiIDs = Set(migrated.employees.filter { $0.kind == .ai }.map(\.id))
    let communicationAssignees = Set(
      migrated.knowledge?.skillAssignments
        .filter { $0.skillID == "communication" }.map(\.employeeID) ?? [])

    XCTAssertEqual(migrated.schemaVersion, 9)
    XCTAssertEqual(communicationAssignees, aiIDs)
    XCTAssertTrue(migrated.assignedSkills(employeeID: "owner").isEmpty)
    XCTAssertEqual(
      migratedAgain.knowledge?.skillDefinitions.filter { $0.id == "communication" }.count, 1)
    XCTAssertEqual(
      migratedAgain.knowledge?.skillAssignments.filter { $0.skillID == "communication" }.count,
      aiIDs.count)
  }

  func testEmployeePlansTicketsDeliversArtifactsAndDoesNotDuplicate() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let engine = EmployeeOutcomeEngine()
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let outcomeID = try organization.createEmployeeOutcome(
      employeeID: "theo",
      outcome: "Draft a concise launch note",
      context: "The audience is solo founders.",
      now: Date(timeIntervalSince1970: 200)
    )
    organization = engine.start(
      organization, outcomeID: outcomeID, now: Date(timeIntervalSince1970: 210))

    let result = await engine.run(
      organization,
      outcomeID: outcomeID,
      runner: DeterministicEmployeeRunner(),
      store: store,
      now: Date(timeIntervalSince1970: 300)
    )
    let outcome = try XCTUnwrap(result.employeeOutcome(outcomeID))

    XCTAssertEqual(outcome.status, .delivered)
    XCTAssertEqual(outcome.taskIDs.count, 2)
    XCTAssertEqual(outcome.artifactIDs.count, 2)
    XCTAssertTrue(outcome.selectedSkillIDs.contains("communication"))
    XCTAssertTrue(outcome.taskIDs.allSatisfy { result.task($0)?.status == .done })
    XCTAssertEqual(result.employee("theo")?.status, .resting)
    XCTAssertTrue(
      result.activity.contains { $0.actorID == "theo" && $0.message.contains("tickets") })
    XCTAssertTrue(result.activity.contains { $0.actorID == "theo" && $0.kind == .completed })

    try await store.save(result)
    let projection = try String(
      contentsOf: root.appendingPathComponent("EMPLOYEE_OUTCOMES.md"), encoding: .utf8)
    XCTAssertTrue(projection.contains("Draft a concise launch note"))
    XCTAssertTrue(projection.contains("Communication"))

    let rerun = await engine.run(
      result,
      outcomeID: outcomeID,
      runner: UnexpectedOutcomeRunner(),
      store: store,
      now: Date(timeIntervalSince1970: 400)
    )
    XCTAssertEqual(rerun, result)
    XCTAssertEqual(rerun.artifacts.filter { outcome.artifactIDs.contains($0.id) }.count, 2)
  }

  func testMissingResearchPermissionCreatesPreciseHelpRequest() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    let engine = EmployeeOutcomeEngine()
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    organization.executionMode = .localCodex
    let outcomeID = try organization.createEmployeeOutcome(
      employeeID: "nia",
      outcome: "Research current onboarding patterns",
      context: "Use primary sources.",
      now: Date(timeIntervalSince1970: 200)
    )
    organization = engine.start(
      organization, outcomeID: outcomeID, now: Date(timeIntervalSince1970: 210))

    let result = await engine.run(
      organization,
      outcomeID: outcomeID,
      runner: DeterministicEmployeeRunner(),
      store: store,
      now: Date(timeIntervalSince1970: 300),
      // Codex is installed here, which is what makes the research real and so
      // makes the missing permission worth blocking over.
      runtimeHealth: .localAgents(codex: .available)
    )
    let outcome = try XCTUnwrap(result.employeeOutcome(outcomeID))
    let blockedTask = try XCTUnwrap(
      outcome.taskIDs.compactMap(result.task).first { $0.status == .blocked })

    XCTAssertEqual(outcome.status, .waiting)
    XCTAssertTrue(
      outcome.helpRequest?.localizedCaseInsensitiveContains("web research permission") == true)
    XCTAssertEqual(blockedTask.kind, .research)
    XCTAssertEqual(result.employee("nia")?.status, .blocked)
    XCTAssertEqual(result.blockers.last?.taskID, blockedTask.id)
    XCTAssertEqual(result.activity.last?.actorID, "nia")
    XCTAssertEqual(result.activity.last?.kind, .blocked)
  }

  func testInterruptedOutcomeKeepsPlanAndReturnsToQueued() throws {
    let now = Date(timeIntervalSince1970: 100)
    var organization = OrganizationState.seeded(now: now)
    let outcomeID = try organization.createEmployeeOutcome(
      employeeID: "maya",
      outcome: "Prepare an operating note",
      context: "",
      now: now
    )
    _ = organization.updateEmployeeOutcome(outcomeID, now: now) { outcome in
      outcome.status = .working
      outcome.taskIDs = ["\(outcomeID)-task-1"]
    }
    organization.tasks.append(
      WorkTask(
        id: "\(outcomeID)-task-1",
        title: "Frame the note",
        detail: "Create a useful frame.",
        kind: .analysis,
        status: .doing,
        assigneeID: "maya",
        reviewerID: nil,
        dependencyIDs: [],
        artifactIDs: [],
        revisionCount: 0,
        maxRevisions: 0,
        updatedAt: now
      ))
    let employeeIndex = organization.employees.firstIndex { $0.id == "maya" }!
    organization.employees[employeeIndex].status = .working
    organization.employees[employeeIndex].currentTaskID = "\(outcomeID)-task-1"

    XCTAssertTrue(
      organization.resetInterruptedEmployeeOutcome(now: Date(timeIntervalSince1970: 200)))
    XCTAssertEqual(organization.employeeOutcome(outcomeID)?.status, .queued)
    XCTAssertEqual(organization.task("\(outcomeID)-task-1")?.status, .ready)
    XCTAssertEqual(organization.employee("maya")?.status, .resting)
    XCTAssertEqual(organization.employeeOutcome(outcomeID)?.taskIDs, ["\(outcomeID)-task-1"])
  }

  // MARK: - What a recurring duty actually read

  func testADutyCommitmentReadsTheLocalInboxAndRecordsItsCoverage() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    try await seedFeedbackInbox(store)
    let (organization, occurrenceID, outcomeID) = try dutyCommitment()
    let recorder = ContextRecorder()

    let result = await EmployeeOutcomeEngine().run(
      organization,
      outcomeID: outcomeID,
      runner: RecordingRunner(recorder: recorder),
      store: store,
      now: epoch
    )

    let occurrence = try XCTUnwrap(result.dutyOccurrence(occurrenceID))
    XCTAssertEqual(occurrence.includedInputs.map(\.fileName), ["founder-note.md"])
    XCTAssertEqual(occurrence.includedInputs.map(\.label), ["F1"])
    XCTAssertEqual(occurrence.excludedInputs.map(\.fileName), ["screenshot.png"])
    let contexts = await recorder.contexts
    XCTAssertTrue(
      contexts.contains {
        $0.contains("<feedback_source label=\"F1\" filename=\"founder-note.md\">")
          && $0.contains("Setup was confusing.")
      },
      "The captured feedback must reach the work, not only the coverage counters.")
  }

  func testACommitmentNoDutyOwnsReadsNoFeedbackInbox() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    try await seedFeedbackInbox(store)
    var organization = hiredOrganization()
    try allowUnreviewedPlans(for: "theo", in: &organization)
    let outcomeID = try organization.createEmployeeOutcome(
      employeeID: "theo", outcome: "Draft a concise launch note", context: "", now: epoch)
    organization = EmployeeOutcomeEngine().start(organization, outcomeID: outcomeID, now: epoch)
    let recorder = ContextRecorder()

    _ = await EmployeeOutcomeEngine().run(
      organization,
      outcomeID: outcomeID,
      runner: RecordingRunner(recorder: recorder),
      store: store,
      now: epoch
    )

    let contexts = await recorder.contexts
    XCTAssertFalse(
      contexts.contains { $0.contains("<feedback_source") },
      "Customer feedback is the duty's input, not every employee's.")
  }

  // MARK: - Research has to be verifiable

  func testResearchWithoutASourceURLIsRefusedInsteadOfDelivered() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let (organization, outcomeID) = try researchCommitment()

    let result = await EmployeeOutcomeEngine().run(
      organization,
      outcomeID: outcomeID,
      runner: UncitedResearchRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available)
    )

    let outcome = try XCTUnwrap(result.employeeOutcome(outcomeID))
    XCTAssertEqual(outcome.status, .failed)
    XCTAssertEqual(outcome.helpRequest?.contains("no source URL"), true)
    XCTAssertFalse(
      result.artifacts.contains { $0.kind == .research },
      "Unverifiable research must not be saved as a research artifact.")
    XCTAssertEqual(
      result.knowledge?.capabilityEvents.map(\.kind), [.started, .failed],
      "A refused research run still used the capability, and says so.")
  }

  func testRehearsedResearchIsNotHeldToTheSourceURLRule() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let (organization, outcomeID) = try researchCommitment(provider: .demo)

    let result = await EmployeeOutcomeEngine().run(
      organization,
      outcomeID: outcomeID,
      runner: UncitedResearchRunner(),
      store: LocalOrganizationStore(rootURL: root),
      now: epoch,
      runtimeHealth: .localAgents(codex: .available)
    )

    XCTAssertEqual(result.employeeOutcome(outcomeID)?.status, .delivered)
    XCTAssertEqual(result.knowledge?.capabilityEvents.isEmpty, true)
  }

  // MARK: - The command boundary carries what the run recorded about itself

  func testCapabilityEventsAndInputCoverageSurviveTheCommandBoundary() async throws {
    let root = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let store = LocalOrganizationStore(rootURL: root)
    try await seedFeedbackInbox(store)
    let engine = EmployeeOutcomeEngine()

    var (duty, occurrenceID, dutyOutcomeID) = try dutyCommitment()
    let dutyResult = try await engine.execute(
      EmployeeOutcomeRunRequest(organization: duty, outcomeID: dutyOutcomeID),
      runner: DeterministicEmployeeRunner(), store: store, now: epoch)
    try duty.apply(dutyResult)

    var (research, researchOutcomeID) = try researchCommitment()
    let researchResult = try await engine.execute(
      EmployeeOutcomeRunRequest(organization: research, outcomeID: researchOutcomeID),
      runner: CitedResearchRunner(), store: store, now: epoch,
      runtimeHealth: .localAgents(codex: .available))
    try research.apply(researchResult)

    XCTAssertEqual(
      duty.dutyOccurrence(occurrenceID)?.includedInputs.map(\.fileName), ["founder-note.md"])
    XCTAssertEqual(
      duty.dutyOccurrence(occurrenceID)?.excludedInputs.map(\.fileName), ["screenshot.png"])
    XCTAssertEqual(
      research.knowledge?.capabilityEvents.map(\.kind), [.started, .succeeded],
      "Attribution the engine recorded must not be dropped on the way to saved state.")
  }

  // MARK: - Fixtures

  /// A running Customer Voice occurrence and the canonical commitment it owns.
  private func dutyCommitment() throws -> (
    state: OrganizationState, occurrenceID: String, outcomeID: String
  ) {
    var state = hiredOrganization()
    try allowUnreviewedPlans(for: "iris", in: &state)
    let occurrenceID = try state.beginDutyOccurrence(
      dutyID: CustomerVoiceDutyEngine.dutyID, now: epoch)
    let outcomeID = try XCTUnwrap(state.dutyOccurrence(occurrenceID)?.canonicalOutcomeID)
    state = EmployeeOutcomeEngine().start(state, outcomeID: outcomeID, now: epoch)
    return (state, occurrenceID, outcomeID)
  }

  /// A commitment whose plan contains a research ticket, with the read-only
  /// web-research grant already in the researcher's contract.
  private func researchCommitment(
    provider: EmployeeExecutionProvider = .localCodex
  ) throws -> (state: OrganizationState, outcomeID: String) {
    var state = hiredOrganization()
    try allowUnreviewedPlans(
      for: "nia", in: &state, provider: provider, grants: ["web-research"])
    let outcomeID = try state.createEmployeeOutcome(
      employeeID: "nia", outcome: "Find current onboarding evidence", context: "", now: epoch)
    state = EmployeeOutcomeEngine().start(state, outcomeID: outcomeID, now: epoch)
    return (state, outcomeID)
  }

  /// Lets an employee's plan proceed without owner review, so a test can reach
  /// the ticket work these tests are about rather than stopping at the plan.
  private func allowUnreviewedPlans(
    for employeeID: String,
    in state: inout OrganizationState,
    provider: EmployeeExecutionProvider = .demo,
    grants: [String] = []
  ) throws {
    try state.updateWorkingContract(
      employeeID: employeeID,
      role: state.employee(employeeID)?.role ?? "",
      responsibility: state.employee(employeeID)?.responsibility ?? "",
      managerID: nil,
      assignedSkillIDs: state.assignedSkills(employeeID: employeeID).map(\.id),
      declaredConnectionIDs: [],
      capabilityGrants: grants,
      executionProvider: provider,
      modelName: nil,
      boundaries: AutonomyBoundaries(),
      reviewPolicy: .automaticForLocalWork,
      actorID: "owner",
      reason: "outcome engine fixture"
    )
  }

  private func hiredOrganization() -> OrganizationState {
    var state = LocalOrganizationStore.migrated(.seeded(now: epoch), now: epoch)
    for index in state.employees.indices where state.employees[index].kind == .ai {
      state.employees[index].employmentState = .hired
    }
    return state
  }

  /// One readable feedback file and one the scanner must leave out.
  private func seedFeedbackInbox(_ store: LocalOrganizationStore) async throws {
    let inbox = try await store.ensureFeedbackInbox()
    try "Setup was confusing.".write(
      to: inbox.appendingPathComponent("founder-note.md"), atomically: true, encoding: .utf8)
    try "not text we analyze".write(
      to: inbox.appendingPathComponent("screenshot.png"), atomically: true, encoding: .utf8)
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("AgentOfficeOutcomeTests-\(UUID().uuidString)", isDirectory: true)
  }
}

/// Collects the context every request carried, so a test can assert on what the
/// work was actually given rather than on what the engine intended to give it.
private actor ContextRecorder {
  private(set) var contexts: [String] = []

  func record(_ context: String) {
    contexts.append(context)
  }
}

private struct RecordingRunner: EmployeeRunner {
  let recorder: ContextRecorder

  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    await recorder.record(request.context)
    return try await DeterministicEmployeeRunner().perform(request)
  }
}

/// A well-formed brief that claims permitted web evidence and cites no source.
private struct UncitedResearchRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    guard request.operation == .research else {
      return try await DeterministicEmployeeRunner().perform(request)
    }
    return EmployeeWorkOutput(
      title: "Audience research",
      summary: "Restated what the team already believed.",
      content: """
        # Audience

        ## Findings
        Onboarding confuses new founders.

        ## Sources
        Internal conversations only.

        ## Uncertainty
        Nothing external was checked.

        ## Recommended next actions
        Interview five recent signups.
        """,
      evidenceBasis: "permitted-web-research"
    )
  }
}

private struct CitedResearchRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    guard request.operation == .research else {
      return try await DeterministicEmployeeRunner().perform(request)
    }
    return EmployeeWorkOutput(
      title: "Audience research",
      summary: "Found one primary source.",
      content: """
        # Audience

        ## Findings
        The onboarding drop-off is documented.

        ## Sources
        - https://example.com/onboarding-report

        ## Uncertainty
        One quarter of data only.

        ## Recommended next actions
        Interview five recent signups.
        """,
      evidenceBasis: "permitted-web-research"
    )
  }
}

private struct UnexpectedOutcomeRunner: EmployeeRunner {
  func perform(_ request: EmployeeWorkRequest) async throws -> EmployeeWorkOutput {
    XCTFail("A delivered outcome must not invoke the runner again")
    return EmployeeWorkOutput(title: "Unexpected", summary: "Unexpected", content: "Unexpected")
  }
}
