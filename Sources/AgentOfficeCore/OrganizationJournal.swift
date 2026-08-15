import Foundation

public enum OrganizationJournalError: LocalizedError, Equatable {
  case missingHeader
  case unsupportedFormat(String)
  case unsupportedSchemaVersion(found: Int, supported: Int)
  case truncatedEntry(line: Int)
  case malformedEntry(line: Int, reason: String)
  case duplicateSequence(Int, line: Int)
  case outOfOrderSequence(expected: Int, found: Int, line: Int)

  public var errorDescription: String? {
    switch self {
    case .missingHeader:
      "The organization history is missing its header line, so it cannot be trusted."
    case .unsupportedFormat(let format):
      "The organization history declares an unknown format ‘\(format)’."
    case .unsupportedSchemaVersion(let found, let supported):
      "The organization history uses schema version \(found); this app understands version \(supported). Update the app instead of continuing."
    case .truncatedEntry(let line):
      "The organization history is truncated at line \(line). The last write did not finish."
    case .malformedEntry(let line, let reason):
      "The organization history could not be read at line \(line): \(reason)"
    case .duplicateSequence(let sequence, let line):
      "The organization history repeats sequence \(sequence) at line \(line)."
    case .outOfOrderSequence(let expected, let found, let line):
      "The organization history expected sequence \(expected) but found \(found) at line \(line)."
    }
  }
}

/// Append-only local history for one organization.
///
/// One JSON object per line: a header, then one line per accepted event. A
/// crash can only truncate the final line, which is reported rather than
/// skipped — silently dropping a partial write would present a plausible but
/// wrong organization.
public struct OrganizationJournal: Sendable {
  public static let formatIdentifier = "agent-office-organization-journal"
  public static let schemaVersion = 1

  public let fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  private var fileManager: FileManager { .default }

  private struct Header: Codable {
    var format: String
    var schemaVersion: Int
    var createdAt: Date
  }

  private static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  private static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }

  public var exists: Bool { fileManager.fileExists(atPath: fileURL.path) }

  /// Appends one event and returns it with its assigned sequence number.
  ///
  /// The sequence comes from the file itself rather than from the caller, so
  /// two callers cannot disagree about order.
  @discardableResult
  public func append(
    _ makeEvent: (Int) -> OrganizationEvent,
    now: Date = Date()
  ) throws -> OrganizationEvent {
    try createIfNeeded(now: now)
    let next = try lastSequence() + 1
    let event = makeEvent(next)
    var line = try Self.encoder().encode(event)
    line.append(contentsOf: [0x0A])

    let handle = try FileHandle(forWritingTo: fileURL)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: line)
    try handle.synchronize()
    return event
  }

  /// Every recorded event, in sequence order.
  public func events() throws -> [OrganizationEvent] {
    guard exists else { return [] }
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    guard !contents.isEmpty else { throw OrganizationJournalError.missingHeader }

    let endsCleanly = contents.hasSuffix("\n")
    var lines = contents.components(separatedBy: "\n")
    if endsCleanly { lines.removeLast() }

    guard let headerLine = lines.first else { throw OrganizationJournalError.missingHeader }
    try Self.validateHeader(headerLine)
    return try Self.decodeEntries(Array(lines.dropFirst()), endsCleanly: endsCleanly)
  }

  private static func validateHeader(_ line: String) throws {
    guard let data = line.data(using: .utf8),
      let header = try? decoder().decode(Header.self, from: data)
    else { throw OrganizationJournalError.missingHeader }
    guard header.format == formatIdentifier else {
      throw OrganizationJournalError.unsupportedFormat(header.format)
    }
    guard header.schemaVersion <= schemaVersion else {
      throw OrganizationJournalError.unsupportedSchemaVersion(
        found: header.schemaVersion, supported: schemaVersion)
    }
  }

  private static func decodeEntries(_ lines: [String], endsCleanly: Bool) throws
    -> [OrganizationEvent]
  {
    let decoder = decoder()
    var events: [OrganizationEvent] = []
    var seenSequences: Set<Int> = []
    for (offset, line) in lines.enumerated() {
      // Line 1 is the header, so entry offsets start at line 2.
      let lineNumber = offset + 2
      let isFinalLine = offset == lines.count - 1
      let event = try decodeEntry(
        line, lineNumber: lineNumber, truncationSuspected: isFinalLine && !endsCleanly,
        decoder: decoder)
      guard seenSequences.insert(event.sequence).inserted else {
        throw OrganizationJournalError.duplicateSequence(event.sequence, line: lineNumber)
      }
      let expected = (events.last?.sequence ?? 0) + 1
      guard event.sequence == expected else {
        throw OrganizationJournalError.outOfOrderSequence(
          expected: expected, found: event.sequence, line: lineNumber)
      }
      events.append(event)
    }
    return events
  }

  private static func decodeEntry(
    _ line: String,
    lineNumber: Int,
    truncationSuspected: Bool,
    decoder: JSONDecoder
  ) throws -> OrganizationEvent {
    if line.isEmpty { throw OrganizationJournalError.truncatedEntry(line: lineNumber) }
    guard let data = line.data(using: .utf8) else {
      throw OrganizationJournalError.malformedEntry(line: lineNumber, reason: "invalid text")
    }
    let event: OrganizationEvent
    do {
      event = try decoder.decode(OrganizationEvent.self, from: data)
    } catch {
      if truncationSuspected { throw OrganizationJournalError.truncatedEntry(line: lineNumber) }
      throw OrganizationJournalError.malformedEntry(
        line: lineNumber, reason: error.localizedDescription)
    }
    guard event.schemaVersion <= schemaVersion else {
      throw OrganizationJournalError.unsupportedSchemaVersion(
        found: event.schemaVersion, supported: schemaVersion)
    }
    return event
  }

  /// Events recorded after a given sequence, for replaying onto a snapshot.
  public func events(after sequence: Int) throws -> [OrganizationEvent] {
    try events().filter { $0.sequence > sequence }
  }

  /// Events concerning one durable entity, in sequence order.
  public func events(referencing reference: OrganizationEntityReference) throws
    -> [OrganizationEvent]
  {
    try events().filter { $0.references(reference) }
  }

  /// The event already recorded for an idempotency key, if any.
  public func recordedEvent(idempotencyKey: String) throws -> OrganizationEvent? {
    try events().first { $0.idempotencyKey == idempotencyKey }
  }

  public func lastSequence() throws -> Int {
    try events().last?.sequence ?? 0
  }

  /// When this organization first recorded history, for provenance.
  public func createdAt() throws -> Date? {
    guard exists else { return nil }
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    guard let headerLine = contents.components(separatedBy: "\n").first,
      let data = headerLine.data(using: .utf8),
      let header = try? Self.decoder().decode(Header.self, from: data)
    else { throw OrganizationJournalError.missingHeader }
    return header.createdAt
  }

  private func createIfNeeded(now: Date) throws {
    guard !exists else { return }
    try fileManager.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let header = Header(
      format: Self.formatIdentifier, schemaVersion: Self.schemaVersion, createdAt: now)
    var data = try Self.encoder().encode(header)
    data.append(contentsOf: [0x0A])
    try data.write(to: fileURL, options: .atomic)
  }
}
