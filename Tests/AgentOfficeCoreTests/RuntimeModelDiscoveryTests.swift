import Foundation
import XCTest

@testable import AgentOfficeCore

/// A machine on which the test decides which CLIs exist.
private struct InstalledProbe: LocalAgentEnvironmentProbe {
  var executables: Set<String> = []

  func processSearchPaths() -> [String] { ["/fake/bin"] }
  func loginShellSearchPaths() -> [String] { [] }
  func isExecutable(atPath path: String) -> Bool { executables.contains(path) }

  static func with(_ clis: LocalAgentCLI...) -> InstalledProbe {
    InstalledProbe(executables: Set(clis.map { "/fake/bin/\($0.executableName)" }))
  }
}

/// A CLI whose answer the test decides, and which records whether it was asked
/// at all.
private final class StubListingRunner: RuntimeModelListingRunner, @unchecked Sendable {
  private let answer: Result<String, RuntimeModelListingFailure>
  private let lock = NSLock()
  private var invocations: [(path: String, arguments: [String])] = []

  init(_ answer: Result<String, RuntimeModelListingFailure>) { self.answer = answer }

  var calls: [(path: String, arguments: [String])] {
    lock.lock()
    defer { lock.unlock() }
    return invocations
  }

  func listModels(executableURL: URL, arguments: [String]) async
    -> Result<String, RuntimeModelListingFailure>
  {
    record(path: executableURL.path, arguments: arguments)
    return answer
  }

  private func record(path: String, arguments: [String]) {
    lock.lock()
    invocations.append((path, arguments))
    lock.unlock()
  }
}

private func codexCatalog(_ entries: String) -> String { "{\"models\":[\(entries)]}" }

final class RuntimeModelListingTests: XCTestCase {

  // MARK: - Which CLIs can be asked at all

  /// The listing command must be free and offline. Codex renders its bundled
  /// catalogue locally; Claude Code has no listing command, and the arguments
  /// that look like one are forwarded to the model as a prompt.
  func testOnlyACLIWithAFreeLocalListingCommandIsAsked() {
    XCTAssertEqual(
      RuntimeModelListing.arguments(for: .codex), ["debug", "models", "--bundled"])
    // `--bundled` is the part that keeps the ask offline; losing it would make
    // discovery refresh the catalogue over the network.
    XCTAssertTrue(RuntimeModelListing.arguments(for: .codex)?.contains("--bundled") == true)
    XCTAssertNil(RuntimeModelListing.arguments(for: .claudeCode))
  }

  /// A CLI that can be asked never carries an assumed list: if the ask was
  /// possible and failed, a guess would dress the failure up as an answer.
  func testOnlyACLIThatCannotBeAskedCarriesAnAssumedList() {
    for cli in LocalAgentCLI.allCases {
      let assumed = RuntimeModelListing.assumedNames(for: cli)
      if RuntimeModelListing.arguments(for: cli) == nil {
        XCTAssertFalse(assumed.isEmpty, "\(cli) cannot be asked, so it needs an assumed list.")
      } else {
        XCTAssertTrue(assumed.isEmpty, "\(cli) can be asked, so it must not fall back to a guess.")
      }
    }
  }

  func testEachCLIExplainsWhyItsListIsOrIsNotAnAssumption() {
    for cli in LocalAgentCLI.allCases {
      XCTAssertFalse(RuntimeModelListing.assumptionReason(for: cli).isEmpty)
    }
  }

  // MARK: - Reading the Codex catalogue

  func testCodexModelsAreOrderedByPriorityAndDeduplicated() {
    let output = codexCatalog(
      """
      {"slug":"third","priority":9},
      {"slug":"first","priority":1},
      {"slug":"second","priority":4},
      {"slug":"first","priority":1}
      """)

    XCTAssertEqual(
      try? RuntimeModelListing.parse(output, for: .codex).get(), ["first", "second", "third"])
  }

  /// An entry without a priority sorts last rather than first, so a catalogue
  /// that gains an unranked model does not silently promote it.
  func testAnUnrankedModelSortsAfterTheRankedOnes() {
    let output = codexCatalog(
      """
      {"slug":"unranked"},
      {"slug":"ranked","priority":2}
      """)

    XCTAssertEqual(
      try? RuntimeModelListing.parse(output, for: .codex).get(), ["ranked", "unranked"])
  }

  /// Only the two explicit exclusion signals withhold a model. A field that is
  /// absent must narrow nothing, so a catalogue that renames or drops a key
  /// loses entries rather than becoming empty.
  func testOnlyExplicitlyHiddenOrUnsupportedModelsAreWithheld() {
    let output = codexCatalog(
      """
      {"slug":"offered","priority":1,"visibility":"list","supported_in_api":true},
      {"slug":"hidden","priority":2,"visibility":"hide","supported_in_api":true},
      {"slug":"unsupported","priority":3,"visibility":"list","supported_in_api":false},
      {"slug":"unlabelled","priority":4}
      """)

    XCTAssertEqual(
      try? RuntimeModelListing.parse(output, for: .codex).get(), ["offered", "unlabelled"])
  }

  func testSurroundingWhitespaceAndBlankSlugsAreDiscarded() {
    let output = codexCatalog(
      """
      {"slug":"  spaced  ","priority":1},
      {"slug":"   ","priority":2}
      """)

    XCTAssertEqual(try? RuntimeModelListing.parse(output, for: .codex).get(), ["spaced"])
  }

  /// Silence is not an answer. A catalogue that names nothing Office OS can
  /// offer is a failed ask, not an empty runtime.
  func testACatalogueThatNamesNothingIsAFailureRatherThanAnEmptyOffer() {
    let empty = RuntimeModelListing.parse(codexCatalog(""), for: .codex)
    let allHidden = RuntimeModelListing.parse(
      codexCatalog("{\"slug\":\"hidden\",\"visibility\":\"hide\"}"), for: .codex)

    XCTAssertEqual(empty, .failure(.reportedNoModels))
    XCTAssertEqual(allHidden, .failure(.reportedNoModels))
  }

  func testOutputThatIsNotTheExpectedCatalogueIsReportedAsUnreadable() {
    XCTAssertEqual(
      RuntimeModelListing.parse("not json at all", for: .codex), .failure(.unreadableOutput))
    XCTAssertEqual(
      RuntimeModelListing.parse("{\"models\":\"a string\"}", for: .codex),
      .failure(.unreadableOutput))
  }

  /// Claude Code is never asked, so nothing can claim to have read its answer.
  func testClaudeCodeOutputIsNeverReadAsAModelList() {
    XCTAssertEqual(
      RuntimeModelListing.parse(codexCatalog("{\"slug\":\"opus\"}"), for: .claudeCode),
      .failure(.unreadableOutput))
  }

  // MARK: - What the owner is told

  func testEveryFailureExplainsItselfInTheOwnersTerms() {
    let failures: [RuntimeModelListingFailure] = [
      .notInstalled, .commandFailed(status: 3, detail: "boom"),
      .commandFailed(status: 3, detail: ""),
      .timedOut(seconds: 10), .unreadableOutput, .reportedNoModels,
    ]

    for failure in failures { XCTAssertFalse(failure.explanation.isEmpty) }
    XCTAssertTrue(
      RuntimeModelListingFailure.commandFailed(status: 3, detail: "boom").explanation
        .contains("boom"))
    XCTAssertFalse(
      RuntimeModelListingFailure.commandFailed(status: 3, detail: "").explanation.hasSuffix(" "))
  }

  /// A screen must be able to tell "your CLI reported these" from "we could not
  /// ask, so here is what we assumed" without reading a log.
  func testAReportedListAndAnAssumedListDoNotReadTheSame() {
    let reported = offer(names: ["a"], provenance: .reportedByCLI)
    let assumed = offer(names: ["a"], provenance: .assumed(reason: "no listing command."))
    let failed = offer(names: [], provenance: .unavailable(.timedOut(seconds: 10)))

    XCTAssertTrue(reported.provenance.isReported)
    XCTAssertFalse(assumed.provenance.isReported)
    XCTAssertFalse(failed.provenance.isReported)
    XCTAssertTrue(reported.explanation.contains("reported"))
    XCTAssertTrue(assumed.explanation.contains("assumes"))
    XCTAssertNotEqual(reported.explanation, assumed.explanation)
    XCTAssertTrue(failed.explanation.contains("Auto"))
  }

  private func offer(names: [String], provenance: RuntimeModelProvenance) -> RuntimeModelOffer {
    RuntimeModelOffer(
      cli: .codex, names: names, provenance: provenance, executablePath: "/fake/bin/codex",
      observedAt: Date(timeIntervalSince1970: 0))
  }
}

final class RuntimeModelInquiryTests: XCTestCase {
  private func inquiry(_ probe: InstalledProbe, _ runner: StubListingRunner) -> RuntimeModelInquiry
  {
    RuntimeModelInquiry(discovery: LocalAgentDiscovery(probe: probe), runner: runner)
  }

  private let now = Date(timeIntervalSince1970: 1_000)

  func testAnUninstalledCLIIsReportedAsUnaskedRatherThanAsOfferingNothing() async {
    let runner = StubListingRunner(.success(codexCatalog("{\"slug\":\"anything\"}")))
    let offer = await inquiry(InstalledProbe(), runner).offer(for: .codex, now: now)

    XCTAssertEqual(offer.provenance, .unavailable(.notInstalled))
    XCTAssertTrue(offer.names.isEmpty)
    XCTAssertNil(offer.executablePath)
    // Nothing was found, so nothing was run.
    XCTAssertTrue(runner.calls.isEmpty)
  }

  func testAnInstalledCLIIsAskedAndItsAnswerIsRecordedAsReported() async {
    let runner = StubListingRunner(
      .success(
        codexCatalog("{\"slug\":\"newest\",\"priority\":1},{\"slug\":\"older\",\"priority\":2}"))
    )
    let offer = await inquiry(.with(.codex), runner).offer(for: .codex, now: now)

    XCTAssertEqual(offer.names, ["newest", "older"])
    XCTAssertEqual(offer.provenance, .reportedByCLI)
    XCTAssertEqual(offer.executablePath, "/fake/bin/codex")
    XCTAssertEqual(offer.observedAt, now)
    XCTAssertEqual(runner.calls.first?.path, "/fake/bin/codex")
    XCTAssertEqual(runner.calls.first?.arguments, ["debug", "models", "--bundled"])
  }

  /// The whole point of the change: a failed ask must not be dressed up as a
  /// successful one by quietly substituting a hardcoded list.
  func testAFailedAskOffersNothingRatherThanFallingBackToAGuess() async {
    let runner = StubListingRunner(.failure(.timedOut(seconds: 10)))
    let offer = await inquiry(.with(.codex), runner).offer(for: .codex, now: now)

    XCTAssertTrue(offer.names.isEmpty)
    XCTAssertEqual(offer.provenance, .unavailable(.timedOut(seconds: 10)))
  }

  func testAnUnreadableAnswerIsAFailureRatherThanAnEmptyReport() async {
    let runner = StubListingRunner(.success("not a catalogue"))
    let offer = await inquiry(.with(.codex), runner).offer(for: .codex, now: now)

    XCTAssertEqual(offer.provenance, .unavailable(.unreadableOutput))
    XCTAssertTrue(offer.names.isEmpty)
  }

  /// Claude Code has no listing command, so it is never run — and what is shown
  /// says so.
  func testACLIWithNoListingCommandIsNotRunAndItsListSaysItIsAssumed() async {
    let runner = StubListingRunner(.success("ignored"))
    let offer = await inquiry(.with(.claudeCode), runner).offer(for: .claudeCode, now: now)

    XCTAssertTrue(runner.calls.isEmpty)
    XCTAssertEqual(offer.names, RuntimeModelListing.assumedNames(for: .claudeCode))
    XCTAssertFalse(offer.names.isEmpty)
    XCTAssertEqual(
      offer.provenance, .assumed(reason: RuntimeModelListing.assumptionReason(for: .claudeCode)))
    XCTAssertEqual(offer.executablePath, "/fake/bin/claude")
  }

  /// Each runtime answers for itself; one CLI's models never stand in for
  /// another's.
  func testEachRuntimeAnswersOnlyForItself() async {
    let runner = StubListingRunner(.success(codexCatalog("{\"slug\":\"gpt-example\"}")))
    let both = inquiry(.with(.codex, .claudeCode), runner)

    let codex = await both.offer(for: .codex, now: now)
    let claude = await both.offer(for: .claudeCode, now: now)

    XCTAssertEqual(codex.cli, .codex)
    XCTAssertEqual(claude.cli, .claudeCode)
    XCTAssertTrue(Set(codex.names).isDisjoint(with: Set(claude.names)))
  }
}

final class RuntimeModelOfferCacheTests: XCTestCase {
  private let start = Date(timeIntervalSince1970: 10_000)

  private func offer(
    _ cli: LocalAgentCLI = .codex,
    provenance: RuntimeModelProvenance = .reportedByCLI,
    path: String? = "/fake/bin/codex",
    at date: Date? = nil
  ) -> RuntimeModelOffer {
    RuntimeModelOffer(
      cli: cli, names: ["one"], provenance: provenance, executablePath: path,
      observedAt: date ?? start)
  }

  func testARememberedAnswerIsReusedSoAPickerStartsNoProcess() {
    var cache = RuntimeModelOfferCache()
    cache.record(offer())

    XCTAssertEqual(
      cache.offer(for: .codex, executablePath: "/fake/bin/codex", now: start.addingTimeInterval(5)),
      offer())
  }

  func testAnAnswerAboutADifferentBinaryIsNotReusedForThisOne() {
    var cache = RuntimeModelOfferCache()
    cache.record(offer())

    XCTAssertNil(cache.offer(for: .codex, executablePath: "/elsewhere/codex", now: start))
    XCTAssertNil(cache.offer(for: .codex, executablePath: nil, now: start))
    XCTAssertNil(cache.offer(for: .claudeCode, executablePath: "/fake/bin/codex", now: start))
  }

  /// A report is worth keeping until the owner changes their installation; a
  /// failure is worth retrying soon. One lifetime could not do both.
  func testAFailureIsForgottenLongBeforeAReportIs() {
    let failed = offer(provenance: .unavailable(.timedOut(seconds: 10)))

    XCTAssertEqual(
      RuntimeModelOfferCache.lifetime(of: offer()), RuntimeModelOfferCache.reportedLifetime)
    XCTAssertEqual(
      RuntimeModelOfferCache.lifetime(of: offer(provenance: .assumed(reason: "none."))),
      RuntimeModelOfferCache.reportedLifetime)
    XCTAssertEqual(
      RuntimeModelOfferCache.lifetime(of: failed), RuntimeModelOfferCache.failedLifetime)
    XCTAssertLessThan(
      RuntimeModelOfferCache.failedLifetime, RuntimeModelOfferCache.reportedLifetime)
  }

  func testAnAnswerIsAskedAgainOnceItsLifetimeHasPassed() {
    var cache = RuntimeModelOfferCache()
    cache.record(offer())
    cache.record(offer(.claudeCode, provenance: .unavailable(.unreadableOutput), path: "/c"))

    let justBefore = start.addingTimeInterval(RuntimeModelOfferCache.failedLifetime - 1)
    let justAfter = start.addingTimeInterval(RuntimeModelOfferCache.failedLifetime)

    XCTAssertNotNil(cache.offer(for: .claudeCode, executablePath: "/c", now: justBefore))
    XCTAssertNil(cache.offer(for: .claudeCode, executablePath: "/c", now: justAfter))
    // The report is still fresh at the moment the failure expires.
    XCTAssertNotNil(cache.offer(for: .codex, executablePath: "/fake/bin/codex", now: justAfter))
    XCTAssertNil(
      cache.offer(
        for: .codex, executablePath: "/fake/bin/codex",
        now: start.addingTimeInterval(RuntimeModelOfferCache.reportedLifetime)))
  }

  /// A clock that moved backwards makes an answer look impossibly fresh. Treat
  /// that as stale rather than as newly observed.
  func testAnAnswerFromTheFutureIsTreatedAsStale() {
    var cache = RuntimeModelOfferCache()
    cache.record(offer())

    XCTAssertTrue(RuntimeModelOfferCache.isStale(offer(), now: start.addingTimeInterval(-1)))
    XCTAssertNil(
      cache.offer(
        for: .codex, executablePath: "/fake/bin/codex", now: start.addingTimeInterval(-1)))
  }

  /// The owner-driven recheck already forgets the recovered `PATH`; the model
  /// answers describe the same installation and must go with it.
  func testTheOwnerCanForgetEveryRememberedAnswerAtOnce() {
    var cache = RuntimeModelOfferCache()
    cache.record(offer())
    cache.record(offer(.claudeCode, path: "/fake/bin/claude"))

    cache.forgetAll()

    XCTAssertNil(cache.offer(for: .codex, executablePath: "/fake/bin/codex", now: start))
    XCTAssertNil(cache.offer(for: .claudeCode, executablePath: "/fake/bin/claude", now: start))
  }
}

/// Exercises the one part that must touch a real process, using ordinary POSIX
/// tools so the suite proves the plumbing without either CLI installed.
final class SystemRuntimeModelListingRunnerTests: XCTestCase {
  private let runner = SystemRuntimeModelListingRunner()

  func testStandardOutputIsReturnedWhenTheCommandSucceeds() async {
    let answer = await runner.listModels(
      executableURL: URL(fileURLWithPath: "/bin/echo"), arguments: ["catalogue"])

    XCTAssertEqual(try? answer.get(), "catalogue\n")
  }

  func testANonZeroExitIsReportedWithItsStatusAndItsComplaint() async {
    let answer = await runner.listModels(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "echo unhappy >&2; exit 4"])

    XCTAssertEqual(answer, .failure(.commandFailed(status: 4, detail: "unhappy")))
  }

  func testAnExecutableThatCannotBeStartedIsAFailureRatherThanACrash() async {
    let answer = await runner.listModels(
      executableURL: URL(fileURLWithPath: "/nonexistent/cli"), arguments: [])

    guard case .failure(.commandFailed(let status, _)) = answer else {
      return XCTFail("Starting a missing executable must be reported, not thrown.")
    }
    XCTAssertEqual(status, -1)
  }

  /// A CLI that never finishes must not hold the screen that asked it.
  func testACommandThatOverstaysItsBudgetIsAbandonedAndSaysSo() async {
    let impatient = SystemRuntimeModelListingRunner(timeoutSeconds: 1)

    let answer = await impatient.listModels(
      executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 30"])

    XCTAssertEqual(answer, .failure(.timedOut(seconds: 1)))
  }

  /// Both streams are drained concurrently. A command that fills one while the
  /// reader waits on the other would otherwise deadlock rather than answer.
  func testALargeAnswerOnBothStreamsStillCompletes() async {
    let answer = await runner.listModels(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: [
        "-c",
        "for i in $(seq 1 4000); do echo 'out-padding-line-for-the-pipe-buffer'; "
          + "echo 'err-padding-line-for-the-pipe-buffer' >&2; done",
      ])

    XCTAssertGreaterThan((try? answer.get())?.count ?? 0, 64 * 1024)
  }

  /// Standard input is closed, so a CLI that would wait for a person is told
  /// there is nobody there instead of hanging.
  func testStandardInputIsClosedSoNothingCanWaitForAPerson() async {
    let answer = await runner.listModels(
      executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "cat; echo done"])

    XCTAssertEqual(try? answer.get(), "done\n")
  }
}
