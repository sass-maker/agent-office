import XCTest

@testable import AgentOfficeCore

/// The owner-directed research assignment, minus the engine that used to run it.
///
/// What survives the retired `ResearchAssignmentEngine` is the part production
/// still uses: the assignment's own state rules, the evidence rules
/// `EmployeeOutcomeEngine` now enforces through `ResearchEvidenceVerifier`, and
/// the structured research brief a real runtime is asked for.
final class ResearchAssignmentTests: XCTestCase {
  // MARK: - What the owner may create and stop

  func testAssignmentRequiresOutcomeDelegatesAndAllowsOnlyOneActiveAssignment() throws {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))

    XCTAssertThrowsError(try organization.createResearchAssignment(outcome: "  ", context: "")) {
      error in
      XCTAssertEqual(error as? ResearchAssignmentError, .emptyOutcome)
    }

    let assignmentID = try organization.createResearchAssignment(
      outcome: "  Compare three onboarding approaches  ",
      context: "  Focus on first-run clarity.  ",
      now: Date(timeIntervalSince1970: 200)
    )
    let assignment = try XCTUnwrap(organization.researchAssignment(assignmentID))

    XCTAssertEqual(assignment.outcome, "Compare three onboarding approaches")
    XCTAssertEqual(assignment.context, "Focus on first-run clarity.")
    XCTAssertEqual(assignment.requestedByActorID, "owner")
    XCTAssertEqual(assignment.delegatedByActorID, "mira")
    XCTAssertEqual(assignment.assigneeID, "nia")
    XCTAssertEqual(assignment.reviewerID, "mira")
    XCTAssertEqual(Array(organization.activity.suffix(2).map(\.actorID)), ["owner", "mira"])

    XCTAssertThrowsError(
      try organization.createResearchAssignment(outcome: "Another question", context: "")
    ) { error in
      XCTAssertEqual(error as? ResearchAssignmentError, .activeAssignmentExists)
    }
  }

  func testOwnerCanStopBlockedAssignmentAndCreateAnother() throws {
    var organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let firstID = try organization.createResearchAssignment(
      outcome: "A question that needs permission",
      context: "",
      now: Date(timeIntervalSince1970: 200)
    )
    _ = organization.updateResearchAssignment(firstID) { value in
      value.status = .waiting
      value.blockingReason = "Permission required"
    }

    XCTAssertTrue(
      organization.cancelResearchAssignment(firstID, now: Date(timeIntervalSince1970: 300)))
    XCTAssertEqual(organization.researchAssignment(firstID)?.status, .cancelled)
    XCTAssertNil(organization.activeResearchAssignment)
    XCTAssertEqual(organization.activity.last?.actorID, "owner")
    XCTAssertNoThrow(
      try organization.createResearchAssignment(outcome: "A new question", context: ""))
  }

  // MARK: - What counts as cited research

  func testSourceVerifierRequiresValidURLInsideSourcesSection() {
    XCTAssertFalse(
      ResearchEvidenceVerifier.containsSourceURL(
        "A link https://example.com outside any source section."))
    XCTAssertFalse(ResearchEvidenceVerifier.containsSourceURL("## Sources\n- https://"))
    XCTAssertTrue(
      ResearchEvidenceVerifier.containsSourceURL("## Sources\n- https://example.com/official"))
    XCTAssertFalse(
      ResearchEvidenceVerifier.hasRequiredSections(
        "## Findings\nUseful\n\n## Sources\n- https://example.com"))
    XCTAssertTrue(
      ResearchEvidenceVerifier.hasRequiredSections(
        "## Findings\nUseful\n\n## Sources\n- https://example.com\n\n## Uncertainty\nLimited sample.\n\n## Recommended next actions\nValidate."
      ))
  }

  func testAssignmentCodexArgumentsRequireGrantAndSearchPrompt() {
    let organization = OrganizationState.seeded(now: Date(timeIntervalSince1970: 100))
    let employee = organization.employee("nia")!
    let assignmentTask = WorkTask(
      id: "research-assignment-example",
      title: "Research current onboarding patterns",
      detail: "Return primary sources.",
      kind: .research,
      status: .doing,
      assigneeID: "nia",
      reviewerID: "mira",
      dependencyIDs: [],
      artifactIDs: [],
      revisionCount: 0,
      maxRevisions: 0,
      updatedAt: Date(timeIntervalSince1970: 200)
    )
    var request = EmployeeWorkRequest(
      operation: .research,
      employee: employee,
      task: assignmentTask,
      organizationName: organization.name,
      outcome: "Find current evidence",
      productBrief: organization.productBrief,
      context: "",
      capabilityGrants: [],
      workspaceURL: temporaryDirectory()
    )

    XCTAssertFalse(CodexEmployeeRunner.commandArguments(for: request).contains("--search"))
    request.capabilityGrants = ["web-research"]
    XCTAssertEqual(CodexEmployeeRunner.commandArguments(for: request).first, "--search")
    let prompt = CodexEmployeeRunner.prompt(for: request)
    XCTAssertTrue(prompt.contains("Sources"))
    XCTAssertTrue(prompt.contains("full HTTP(S) source URL"))
    XCTAssertTrue(prompt.contains("Recommended next actions"))
  }

  private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("agent-office-research-tests-\(UUID().uuidString)", isDirectory: true)
  }

}
