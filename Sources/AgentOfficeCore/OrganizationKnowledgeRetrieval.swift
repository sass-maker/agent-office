import Foundation

/// Where a result came from, and why the employee was allowed to see it.
///
/// Mandatory: a result without a source is an assertion, and retrieval must stay
/// a citation rather than becoming new company truth.
public struct KnowledgeProvenance: Sendable, Equatable {
  public var sourceKind: String
  public var sourceID: String
  public var visibleBecause: String
}

public struct KnowledgeResult: Sendable, Equatable, Identifiable {
  public var id: String
  public var title: String
  public var snippet: String
  public var provenance: KnowledgeProvenance
}

extension OrganizationState {
  /// Searches what this employee is allowed to know.
  ///
  /// Scope is computed per query rather than cached, so a revoked grant cannot
  /// linger in a stale index.
  public func searchKnowledge(
    _ query: String,
    asEmployee employeeID: String,
    commitmentID: String? = nil,
    limit: Int = 20
  ) -> [KnowledgeResult] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !needle.isEmpty else { return [] }

    var results: [KnowledgeResult] = []
    results.append(contentsOf: organizationContextResults(needle))
    results.append(contentsOf: ownMemoryResults(needle, employeeID: employeeID))
    results.append(contentsOf: assignedSkillResults(needle, employeeID: employeeID))
    results.append(contentsOf: ownContractResults(needle, employeeID: employeeID))
    results.append(
      contentsOf: ownCommitmentResults(needle, employeeID: employeeID, commitmentID: commitmentID))
    results.append(contentsOf: ownSupervisionResults(needle, employeeID: employeeID))
    return Array(results.prefix(limit))
  }

  // MARK: - Scopes

  private func organizationContextResults(_ needle: String) -> [KnowledgeResult] {
    var results: [KnowledgeResult] = []
    let brief = productBrief
    if brief.lowercased().contains(needle) {
      results.append(
        KnowledgeResult(
          id: "product-brief",
          title: "Product brief",
          snippet: Self.snippet(brief, around: needle),
          provenance: KnowledgeProvenance(
            sourceKind: "organization-context",
            sourceID: "product-brief",
            visibleBecause: "Organization context is shared with every employee."
          )
        ))
    }
    if outcome.lowercased().contains(needle) {
      results.append(
        KnowledgeResult(
          id: "organization-outcome",
          title: "Organization outcome",
          snippet: outcome,
          provenance: KnowledgeProvenance(
            sourceKind: "organization-context",
            sourceID: "outcome",
            visibleBecause: "Organization context is shared with every employee."
          )
        ))
    }
    return results
  }

  private func ownMemoryResults(_ needle: String, employeeID: String) -> [KnowledgeResult] {
    (knowledge?.memoryEntries ?? [])
      // Another employee's memory is never in scope, regardless of the query.
      .filter { $0.employeeID == employeeID && $0.summary.lowercased().contains(needle) }
      .map { entry in
        KnowledgeResult(
          id: entry.id,
          title: "Memory · day \(entry.dayNumber)",
          snippet: entry.summary,
          provenance: KnowledgeProvenance(
            sourceKind: "employee-memory",
            sourceID: entry.id,
            visibleBecause: "This is \(employeeID)'s own memory."
          )
        )
      }
  }

  private func assignedSkillResults(_ needle: String, employeeID: String) -> [KnowledgeResult] {
    assignedSkills(employeeID: employeeID)
      .filter {
        $0.name.lowercased().contains(needle) || $0.purpose.lowercased().contains(needle)
          || $0.instructions.lowercased().contains(needle)
      }
      .map { skill in
        KnowledgeResult(
          id: skill.id,
          title: "Skill · \(skill.name)",
          snippet: skill.purpose,
          provenance: KnowledgeProvenance(
            sourceKind: "skill",
            sourceID: skill.id,
            visibleBecause: "This skill is assigned to \(employeeID)."
          )
        )
      }
  }

  private func ownContractResults(_ needle: String, employeeID: String) -> [KnowledgeResult] {
    guard let contract = workingContract(for: employeeID) else { return [] }
    let haystack = "\(contract.role) \(contract.responsibility)".lowercased()
    guard haystack.contains(needle) else { return [] }
    return [
      KnowledgeResult(
        id: "contract-\(employeeID)",
        title: "Working contract",
        snippet: contract.responsibility,
        provenance: KnowledgeProvenance(
          sourceKind: "working-contract",
          sourceID: contract.employeeID,
          visibleBecause: "This is \(employeeID)'s own working contract."
        )
      )
    ]
  }

  private func ownCommitmentResults(
    _ needle: String, employeeID: String, commitmentID: String?
  ) -> [KnowledgeResult] {
    let commitments = employeeOutcomes.filter { $0.assigneeID == employeeID }
    var results: [KnowledgeResult] = []
    for commitment in commitments {
      let haystack = "\(commitment.outcome) \(commitment.context)".lowercased()
      if haystack.contains(needle) {
        results.append(
          KnowledgeResult(
            id: commitment.id,
            title: "Commitment · \(commitment.outcome)",
            snippet: commitment.context.isEmpty ? commitment.outcome : commitment.context,
            provenance: KnowledgeProvenance(
              sourceKind: "commitment",
              sourceID: commitment.id,
              visibleBecause: commitment.id == commitmentID
                ? "This is the commitment being worked on."
                : "\(employeeID) owns this commitment."
            )
          ))
      }
      for artifactID in commitment.artifactIDs {
        guard let artifact = artifacts.first(where: { $0.id == artifactID }),
          artifact.title.lowercased().contains(needle)
        else { continue }
        results.append(
          KnowledgeResult(
            id: artifact.id,
            title: "Artifact · \(artifact.title)",
            snippet: artifact.relativePath,
            provenance: KnowledgeProvenance(
              sourceKind: "artifact",
              sourceID: artifact.id,
              visibleBecause: "This artifact belongs to \(employeeID)'s commitment."
            )
          ))
      }
    }
    return results
  }

  private func ownSupervisionResults(_ needle: String, employeeID: String) -> [KnowledgeResult] {
    supervisionEvents
      .filter { $0.employeeID == employeeID && $0.message.lowercased().contains(needle) }
      .map { event in
        KnowledgeResult(
          id: event.id,
          title: "Decision · \(event.kind.rawValue)",
          snippet: event.message,
          provenance: KnowledgeProvenance(
            sourceKind: "supervision-event",
            sourceID: event.id,
            visibleBecause: "This decision was about \(employeeID)."
          )
        )
      }
  }

  private static func snippet(_ text: String, around needle: String, width: Int = 180) -> String {
    guard let range = text.lowercased().range(of: needle) else { return String(text.prefix(width)) }
    let start = text.index(
      range.lowerBound,
      offsetBy: -min(60, text.distance(from: text.startIndex, to: range.lowerBound))
    )
    let end = text.index(
      range.upperBound,
      offsetBy: min(120, text.distance(from: range.upperBound, to: text.endIndex)))
    return String(text[start..<end])
  }
}
