import Foundation
import XCTest

@testable import AgentOfficeCore

final class ResourceLeaseTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 10_000)
  private let artifact = OrganizationResource.artifact("artifact-1")

  private func organization() -> OrganizationState {
    LocalOrganizationStore.migrated(
      .seeded(now: Date(timeIntervalSince1970: 1_000)), now: Date(timeIntervalSince1970: 1_000))
  }

  // MARK: - Shape

  func testALeaseRecordsWhoHoldsWhatAndUntilWhen() throws {
    var state = organization()

    let lease = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite,
      purpose: "Revising the launch note", now: now, duration: 600)

    XCTAssertEqual(lease.resource, artifact)
    XCTAssertEqual(lease.holderEmployeeID, "theo")
    XCTAssertEqual(lease.mode, .exclusiveWrite)
    XCTAssertEqual(lease.purpose, "Revising the launch note")
    XCTAssertEqual(lease.expiresAt, now.addingTimeInterval(600))
    XCTAssertTrue(lease.isLive(at: now))
  }

  func testLeasesWorkOverNonFileResources() throws {
    var state = organization()

    XCTAssertNoThrow(
      try state.acquireLease(
        on: .connection("connection-1"), holderEmployeeID: "nia", mode: .sharedRead,
        purpose: "Reading the research proxy", now: now))
    XCTAssertNoThrow(
      try state.acquireLease(
        on: .commitment("commitment-1"), holderEmployeeID: "nia", mode: .exclusiveWrite,
        purpose: "Delivering", now: now))

    XCTAssertEqual(state.resourceLeases.count, 2)
  }

  // MARK: - Contention

  func testTwoSharedReadsCoexist() throws {
    var state = organization()
    _ = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .sharedRead, purpose: "Reading", now: now)

    XCTAssertNoThrow(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .sharedRead, purpose: "Reading too", now: now))
    XCTAssertEqual(state.liveLeases(on: artifact, now: now).count, 2)
  }

  func testExclusiveIsRefusedWhileOthersHold() throws {
    var state = organization()
    _ = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .sharedRead, purpose: "Reading", now: now,
      duration: 600)

    XCTAssertThrowsError(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .exclusiveWrite, purpose: "Rewriting",
        now: now)
    ) { error in
      XCTAssertEqual(
        error as? LeaseError, .heldByOthers(count: 1, until: now.addingTimeInterval(600)))
    }
  }

  func testSharedIsRefusedWhileHeldExclusively() throws {
    var state = organization()
    _ = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite, purpose: "Rewriting",
      now: now, duration: 600)

    XCTAssertThrowsError(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .sharedRead, purpose: "Reading", now: now)
    ) { error in
      XCTAssertEqual(
        error as? LeaseError,
        .heldExclusively(
          by: "theo", until: now.addingTimeInterval(600), purpose: "Rewriting"))
    }
  }

  func testARefusalNamesTheHolderAndTakesNothing() throws {
    var state = organization()
    let held = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite, purpose: "Rewriting",
      now: now, duration: 600)

    XCTAssertThrowsError(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .exclusiveWrite, purpose: "Also rewriting",
        now: now))

    // The original lease is untouched: nothing is ever preempted.
    XCTAssertEqual(state.liveLeases(on: artifact, now: now).map(\.id), [held.id])
    XCTAssertEqual(state.liveLeases(on: artifact, now: now).first?.holderEmployeeID, "theo")
  }

  // MARK: - Lifecycle

  func testExpiryFreesTheResourceAndKeepsTheHistory() throws {
    var state = organization()
    _ = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite, purpose: "Rewriting",
      now: now, duration: 60)
    let later = now.addingTimeInterval(600)

    XCTAssertNoThrow(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .exclusiveWrite, purpose: "Now mine",
        now: later))

    XCTAssertEqual(state.liveLeases(on: artifact, now: later).map(\.holderEmployeeID), ["nia"])
    XCTAssertEqual(state.expiredLeases(now: later).map(\.holderEmployeeID), ["theo"])
    XCTAssertEqual(state.resourceLeases.count, 2, "expired leases stay inspectable")
  }

  func testRenewalHoldsTheResource() throws {
    var state = organization()
    let lease = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite, purpose: "Rewriting",
      now: now, duration: 60)
    let later = now.addingTimeInterval(50)

    let renewed = try state.renewLease(
      lease.id, holderEmployeeID: "theo", now: later, duration: 600)

    XCTAssertEqual(renewed.expiresAt, later.addingTimeInterval(600))
    XCTAssertEqual(renewed.renewedAt, later)
    XCTAssertThrowsError(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .exclusiveWrite, purpose: "Mine now",
        now: later.addingTimeInterval(100)))
  }

  func testReleaseFreesTheResourceImmediately() throws {
    var state = organization()
    let lease = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite, purpose: "Rewriting",
      now: now, duration: 600)

    try state.releaseLease(lease.id, holderEmployeeID: "theo", now: now.addingTimeInterval(10))

    XCTAssertTrue(state.liveLeases(on: artifact, now: now.addingTimeInterval(20)).isEmpty)
    XCTAssertNoThrow(
      try state.acquireLease(
        on: artifact, holderEmployeeID: "nia", mode: .exclusiveWrite, purpose: "Mine now",
        now: now.addingTimeInterval(20)))
    XCTAssertNotNil(state.resourceLeases.first { $0.id == lease.id }?.releasedAt)
  }

  func testOnlyTheHolderCanRenewOrRelease() throws {
    var state = organization()
    let lease = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite, purpose: "Rewriting",
      now: now)

    XCTAssertThrowsError(try state.renewLease(lease.id, holderEmployeeID: "nia", now: now)) {
      XCTAssertEqual($0 as? LeaseError, .notHolder("nia"))
    }
    XCTAssertThrowsError(try state.releaseLease(lease.id, holderEmployeeID: "nia", now: now)) {
      XCTAssertEqual($0 as? LeaseError, .notHolder("nia"))
    }
  }

  func testContentionIsReadable() throws {
    var state = organization()
    _ = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .exclusiveWrite,
      purpose: "Revising the launch note", now: now, duration: 600)

    let holder = state.liveLeases(on: artifact, now: now).first

    XCTAssertEqual(holder?.holderEmployeeID, "theo")
    XCTAssertEqual(holder?.purpose, "Revising the launch note")
    XCTAssertEqual(holder?.expiresAt, now.addingTimeInterval(600))
  }

  func testLeasesSurviveEncodingAndDecoding() throws {
    var state = organization()
    _ = try state.acquireLease(
      on: artifact, holderEmployeeID: "theo", mode: .sharedRead, purpose: "Reading", now: now)

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(OrganizationState.self, from: try encoder.encode(state))

    XCTAssertEqual(decoded.liveLeases(on: artifact, now: now).count, 1)
    XCTAssertEqual(decoded.resourceLeases.first?.mode, .sharedRead)
  }
}
