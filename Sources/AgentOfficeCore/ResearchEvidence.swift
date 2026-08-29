import Foundation

/// Why a research brief was refused instead of saved.
///
/// Thrown from `EmployeeOutcomeEngine` when a non-rehearsal research ticket
/// fails the evidence rules below.
public enum ResearchAssignmentRunError: LocalizedError, Equatable {
  case notRunnable
  case permissionRequired
  case missingEmployee
  case missingSourceReference
  case incompleteBrief

  public var errorDescription: String? {
    switch self {
    case .notRunnable:
      "This research assignment is not ready to run."
    case .permissionRequired:
      "Nia needs the read-only web research grant before starting this assignment."
    case .missingEmployee:
      "Nia or Mira is missing from this organization."
    case .missingSourceReference:
      "The research run returned no source URL, so it was not accepted as researched work."
    case .incompleteBrief:
      "The research brief is missing findings, sources, uncertainty, or recommended next actions."
    }
  }
}

/// The evidence rules a real research brief has to pass.
public enum ResearchEvidenceVerifier {
  public static func hasRequiredSections(_ content: String) -> Bool {
    let headings = content.split(separator: "\n")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { $0.hasPrefix("#") }
    return ["findings", "sources", "uncertainty", "recommended next actions"].allSatisfy {
      required in
      headings.contains { $0.contains(required) }
    }
  }

  public static func containsSourceURL(_ content: String) -> Bool {
    let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
    guard
      let sourcesIndex = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
          .localizedCaseInsensitiveContains("sources") && $0.hasPrefix("#")
      })
    else { return false }

    let sourceLines = lines.dropFirst(sourcesIndex + 1).prefix { line in
      let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
      return !trimmed.hasPrefix("#")
    }
    return
      sourceLines
      .flatMap { $0.split(whereSeparator: { $0.isWhitespace }) }
      .contains { token in
        let value = token.trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}.,;\"'"))
        guard let components = URLComponents(string: value),
          let scheme = components.scheme?.lowercased(),
          scheme == "https" || scheme == "http"
        else { return false }
        return components.host?.isEmpty == false
      }
  }
}
