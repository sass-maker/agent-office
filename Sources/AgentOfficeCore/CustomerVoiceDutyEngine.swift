import Foundation

public enum CustomerVoiceDutyError: LocalizedError, Equatable {
  case notRunnable
  case missingEmployee
  case emptyInbox
  case incompleteBrief
  case missingSourceLabel

  public var errorDescription: String? {
    switch self {
    case .notRunnable:
      "Customer Voice Weekly is not ready to run."
    case .missingEmployee:
      "Iris or Mira is missing from this organization."
    case .emptyInbox:
      "Add a .txt, .md, or .csv feedback file to the local inbox before running Iris."
    case .incompleteBrief:
      "Iris's brief is missing input coverage, themes, evidence, uncertainty, owner decision, or next occurrence."
    case .missingSourceLabel:
      "Iris's brief did not reference any captured feedback source, so it was not accepted as evidence-linked work."
    }
  }
}

public struct FeedbackInputFile: Sendable, Equatable {
  public var reference: DutyInputReference
  public var content: String

  public init(reference: DutyInputReference, content: String) {
    self.reference = reference
    self.content = content
  }
}

public struct FeedbackInputSnapshot: Sendable, Equatable {
  public var files: [FeedbackInputFile]
  public var exclusions: [DutyInputExclusion]

  public init(files: [FeedbackInputFile], exclusions: [DutyInputExclusion]) {
    self.files = files
    self.exclusions = exclusions
  }

  public var references: [DutyInputReference] { files.map(\.reference) }

  public var promptContext: String {
    let input = files.map { file in
      """
      <feedback_source label="\(file.reference.label)" filename="\(file.reference.fileName)">
      \(file.content)
      </feedback_source>
      """
    }.joined(separator: "\n\n")
    let excluded =
      exclusions.isEmpty
      ? "None."
      : exclusions.map { "- \($0.fileName): \($0.reason)" }.joined(separator: "\n")
    return """
      Included feedback sources:
      \(input)

      Excluded inbox entries:
      \(excluded)
      """
  }
}

public enum LocalFeedbackInboxScanner {
  public static let maximumFileCount = 25
  public static let maximumByteCount = 250 * 1_024
  private static let supportedExtensions = Set(["txt", "md", "csv"])

  public static func capture(
    at inboxURL: URL,
    fileManager: FileManager = .default
  ) throws -> FeedbackInputSnapshot {
    let keys: Set<URLResourceKey> = [
      .isRegularFileKey,
      .isSymbolicLinkKey,
      .isHiddenKey,
      .fileSizeKey,
    ]
    let entries = try fileManager.contentsOfDirectory(
      at: inboxURL,
      includingPropertiesForKeys: Array(keys),
      options: []
    ).sorted {
      $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent)
        == .orderedAscending
    }

    var files: [FeedbackInputFile] = []
    var exclusions: [DutyInputExclusion] = []
    var capturedBytes = 0

    for url in entries {
      let name = url.lastPathComponent
      let values = try url.resourceValues(forKeys: keys)
      if values.isHidden == true || name.hasPrefix(".") {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "Hidden entries are not analyzed."))
        continue
      }
      if values.isSymbolicLink == true {
        exclusions.append(
          DutyInputExclusion(
            fileName: name, reason: "Symbolic links are outside the inbox boundary."))
        continue
      }
      guard values.isRegularFile == true else {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "Only direct regular files are analyzed."))
        continue
      }
      guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
        exclusions.append(DutyInputExclusion(fileName: name, reason: "Unsupported file type."))
        continue
      }
      guard files.count < maximumFileCount else {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "The 25-file run limit was reached."))
        continue
      }
      guard let fileSize = values.fileSize else {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "The file size could not be verified."))
        continue
      }
      guard fileSize > 0 else {
        exclusions.append(DutyInputExclusion(fileName: name, reason: "The file is empty."))
        continue
      }
      guard capturedBytes + fileSize <= maximumByteCount else {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "The 250-KB run limit was reached."))
        continue
      }

      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard capturedBytes + data.count <= maximumByteCount else {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "The 250-KB run limit was reached."))
        continue
      }
      guard let content = String(data: data, encoding: .utf8) else {
        exclusions.append(
          DutyInputExclusion(fileName: name, reason: "The file is not valid UTF-8 text."))
        continue
      }

      let label = "F\(files.count + 1)"
      files.append(
        FeedbackInputFile(
          reference: DutyInputReference(label: label, fileName: name, byteCount: data.count),
          content: content
        ))
      capturedBytes += data.count
    }

    return FeedbackInputSnapshot(files: files, exclusions: exclusions)
  }
}

public enum CustomerVoiceEvidenceVerifier {
  public static func hasRequiredSections(_ content: String) -> Bool {
    let headings = content.split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { $0.hasPrefix("#") }
    return [
      "input coverage", "themes", "evidence", "uncertainty", "owner decision", "next occurrence",
    ]
    .allSatisfy { required in headings.contains { $0.contains(required) } }
  }

  public static func containsValidSourceLabel(
    _ content: String,
    references: [DutyInputReference]
  ) -> Bool {
    references.contains { content.contains("[\($0.label)]") }
  }
}

public struct CustomerVoiceDutyEngine: Sendable {
  public static let dutyID = "customer-voice-weekly"

  public init() {}

  public func run(
    _ input: OrganizationState,
    occurrenceID: String,
    runner: any EmployeeRunner,
    store: LocalOrganizationStore,
    now: Date = Date()
  ) async -> OrganizationState {
    guard let occurrence = input.dutyOccurrence(occurrenceID),
      occurrence.status == .running,
      let duty = input.employeeDuty(occurrence.dutyID),
      let analyst = input.employee(occurrence.assigneeID),
      let reviewer = input.employee(occurrence.reviewerID)
    else { return input }

    var state = input
    do {
      let snapshot = try await store.captureFeedbackSnapshot()
      _ = state.updateDutyOccurrence(occurrenceID, now: now) { value in
        value.includedInputs = snapshot.references
        value.excludedInputs = snapshot.exclusions
      }
      guard !snapshot.files.isEmpty else { throw CustomerVoiceDutyError.emptyInbox }

      let task = WorkTask(
        id: occurrenceID,
        title: duty.title,
        detail: duty.responsibility,
        kind: .analysis,
        status: .doing,
        assigneeID: analyst.id,
        reviewerID: reviewer.id,
        dependencyIDs: [],
        artifactIDs: [],
        revisionCount: 0,
        maxRevisions: 0,
        updatedAt: now
      )
      let request = EmployeeWorkRequest(
        operation: .customerVoice,
        employee: analyst,
        task: task,
        organizationName: state.name,
        outcome: duty.responsibility,
        productBrief: state.productBrief,
        context: snapshot.promptContext,
        memory: state.recentMemoryContext(for: analyst.id),
        skills: state.assignedSkills(employeeID: analyst.id),
        capabilityGrants: analyst.capabilityGrants,
        workspaceURL: store.employeeHomeURL(employeeID: analyst.id)
      )

      let output = try await runner.perform(request)
      try Task.checkCancellation()
      guard CustomerVoiceEvidenceVerifier.hasRequiredSections(output.content) else {
        throw CustomerVoiceDutyError.incompleteBrief
      }
      guard
        CustomerVoiceEvidenceVerifier.containsValidSourceLabel(
          output.content,
          references: snapshot.references
        )
      else { throw CustomerVoiceDutyError.missingSourceLabel }

      let completedAt = Date()
      let evidenceBasis =
        state.executionMode == .localCodex
        ? "local-feedback-analysis"
        : "synthetic-demo"
      let brief = Artifact(
        id: UUID().uuidString,
        title: "Customer Voice Weekly — Iris's brief",
        kind: .analysis,
        relativePath: LocalOrganizationStore.artifactPath(
          employeeID: analyst.id,
          taskID: occurrenceID,
          kind: .analysis
        ),
        authorID: analyst.id,
        taskID: occurrenceID,
        createdAt: completedAt,
        evidenceBasis: evidenceBasis
      )
      let notice =
        state.executionMode == .localCodex
        ? "This brief analyzed only the captured local feedback sources listed below."
        : "This is a synthetic practice analysis of the captured local feedback."
      try await store.writeArtifact(
        relativePath: brief.relativePath,
        content: "> Evidence basis: `\(evidenceBasis)`\n> \(notice)\n\n\(output.content)"
      )

      let delivery = Artifact(
        id: UUID().uuidString,
        title: "Mira's Customer Voice handoff",
        kind: .report,
        relativePath: LocalOrganizationStore.artifactPath(
          employeeID: reviewer.id,
          taskID: occurrenceID,
          kind: .report
        ),
        authorID: reviewer.id,
        taskID: occurrenceID,
        createdAt: completedAt,
        sourceArtifactIDs: [brief.id],
        evidenceBasis: evidenceBasis
      )
      try await store.writeArtifact(
        relativePath: delivery.relativePath,
        content: deliveryContent(
          duty: duty,
          brief: brief,
          output: output,
          snapshot: snapshot,
          evidenceBasis: evidenceBasis
        )
      )

      state.artifacts.append(contentsOf: [brief, delivery])
      state.knowledge?.memoryEntries.append(
        EmployeeMemoryEntry(
          id: UUID().uuidString,
          employeeID: analyst.id,
          authorID: analyst.id,
          dayNumber: state.dayNumber,
          summary: output.summary,
          sourceArtifactID: brief.id,
          createdAt: completedAt
        ))
      _ = state.updateDutyOccurrence(occurrenceID, now: completedAt) { value in
        value.status = .delivered
        value.blockingReason = nil
        value.evidenceBasis = evidenceBasis
        value.briefArtifactID = brief.id
        value.deliveryArtifactID = delivery.id
      }
      _ = state.updateDuty(duty.id) { value in
        value.lastCompletedAt = completedAt
        value.nextDueAt =
          Calendar.current.date(byAdding: .day, value: 7, to: value.nextDueAt)
          ?? value.nextDueAt.addingTimeInterval(7 * 24 * 60 * 60)
      }
      state.activity.append(
        Activity(
          id: UUID().uuidString,
          actorID: analyst.id,
          kind: .handoff,
          message: "Iris delivered the cited Customer Voice Weekly brief to Mira.",
          createdAt: completedAt
        ))
      state.activity.append(
        Activity(
          id: UUID().uuidString,
          actorID: reviewer.id,
          kind: .completed,
          message: "Mira left the weekly customer decision on your desk.",
          createdAt: completedAt
        ))
      restEmployees(occurrence, state: &state)
      return state
    } catch is CancellationError {
      let stoppedAt = Date()
      _ = state.updateDutyOccurrence(occurrenceID, now: stoppedAt) { value in
        value.status = .queued
        value.blockingReason = "The run stopped before delivery. It is ready to resume."
      }
      restEmployees(occurrence, state: &state)
      return state
    } catch {
      let failedAt = Date()
      _ = state.updateDutyOccurrence(occurrenceID, now: failedAt) { value in
        value.status = .blocked
        value.blockingReason = error.localizedDescription
      }
      state.activity.append(
        Activity(
          id: UUID().uuidString,
          actorID: analyst.id,
          kind: .blocked,
          message: "Iris could not deliver Customer Voice Weekly: \(error.localizedDescription)",
          createdAt: failedAt
        ))
      restEmployees(occurrence, state: &state)
      return state
    }
  }

  private func restEmployees(_ occurrence: DutyOccurrence, state: inout OrganizationState) {
    for employeeID in [occurrence.assigneeID, occurrence.reviewerID] {
      guard let index = state.employees.firstIndex(where: { $0.id == employeeID }) else { continue }
      state.employees[index].status = .resting
      state.employees[index].currentTaskID = nil
    }
  }

  private func deliveryContent(
    duty: EmployeeDuty,
    brief: Artifact,
    output: EmployeeWorkOutput,
    snapshot: FeedbackInputSnapshot,
    evidenceBasis: String
  ) -> String {
    """
    # Customer Voice delivery

    ## Duty
    \(duty.title)

    ## Delivered by
    Iris analyzed \(snapshot.files.count) local feedback source\(snapshot.files.count == 1 ? "" : "s") and Mira prepared this handoff.

    ## Evidence
    - Basis: `\(evidenceBasis)`
    - Iris's brief: `\(brief.relativePath)`
    - Included files: \(snapshot.references.map(\.fileName).joined(separator: ", "))
    - Excluded entries: \(snapshot.exclusions.count)

    ## Iris's summary
    \(output.summary)

    ## Your next decision
    Read Iris's evidence, make the single recommended decision, and add new feedback before the next occurrence.
    """
  }
}
