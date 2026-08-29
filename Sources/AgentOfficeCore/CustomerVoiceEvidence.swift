import Foundation

/// Why a Customer Voice run was refused instead of delivered.
///
/// Thrown from `EmployeeOutcomeEngine` and `OrganizationState.beginDutyOccurrence`.
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

/// The evidence rules a real Customer Voice brief has to pass.
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
