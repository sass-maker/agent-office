import AgentOfficeCore
import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
  @Published var organization: OrganizationState = .seeded()
  @Published var selectedEmployeeID: String? = "maya"
  @Published var isLoaded = false
  @Published var showsOnboarding = false
  @Published var lastError: String?
  @Published private(set) var runningEmployeeIDs: Set<String> = []

  private var store: LocalOrganizationStore
  private let employeeOutcomeEngine = EmployeeOutcomeEngine()
  private let runtimeRegistry = RuntimeDriverRegistry.builtIn()
  private let runtimeBroker: RuntimeCapabilityBroker
  /// Runtime requests waiting on the owner. Empty unless a runtime has asked
  /// for authority it does not already hold.
  @Published private(set) var pendingRuntimeRequests: [RuntimeAccessRequest] = []
  private let employeeWorkCoordinator = EmployeeWorkCoordinator(concurrencyLimit: 2)
  private var workTask: Task<Void, Never>?

  init() {
    let store = LocalOrganizationStore(rootURL: Self.defaultOrganizationURL)
    self.store = store
    // A decision only counts once it is organization history. If the journal
    // refuses the write, the broker denies — the same fail-closed path its
    // tests cover, now with a real failure mode behind it.
    runtimeBroker = RuntimeCapabilityBroker(recorder: { request, resolution in
      let command = OrganizationCommand(
        actor: .owner(id: "owner"),
        payload: .recordRuntimeDecision(
          RuntimeDecisionReceipt(request: request, resolution: resolution)),
        idempotencyKey: "runtime-decision:\(request.id)"
      )
      let current = try await store.loadOrCreate()
      _ = try await store.submit(command, to: current)
    })
  }

  deinit {
    workTask?.cancel()
    let coordinator = employeeWorkCoordinator
    Task { await coordinator.cancelAll() }
  }

  static var defaultOrganizationURL: URL {
    let applicationSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.homeDirectoryForCurrentUser
    return
      applicationSupport
      .appendingPathComponent("AgentOffice", isDirectory: true)
      .appendingPathComponent("WillowStudioPOC", isDirectory: true)
  }

  var organizationURL: URL { store.rootURL }

  /// Shared so login-shell `PATH` recovery is paid for once, not once per check.
  private var agentDiscovery: LocalAgentDiscovery { LocalAgentDiscovery() }

  var codexAvailable: Bool { agentDiscovery.locate(.codex) != nil }

  var claudeCodeAvailable: Bool { agentDiscovery.locate(.claudeCode) != nil }

  /// Whether an agent choice can be used right now. Auto is offerable whenever
  /// at least one real runtime is healthy — never on the strength of Demo.
  func agentAvailable(_ provider: EmployeeExecutionProvider) -> Bool {
    switch provider {
    case .auto: codexAvailable || claudeCodeAvailable
    case .demo: true
    case .localCodex: codexAvailable
    case .localClaudeCode: claudeCodeAvailable
    }
  }

  /// Why an agent choice cannot be used, for showing beside a disabled option.
  func agentUnavailableReason(_ provider: EmployeeExecutionProvider) -> String? {
    guard !agentAvailable(provider) else { return nil }
    switch provider {
    case .auto:
      return
        "Neither Codex nor Claude Code was found, so there is nothing for Auto to choose. Practice mode is the only remaining option, and it is a rehearsal."
    case .localCodex:
      return agentDiscovery.availability(of: .codex).reason
    case .localClaudeCode:
      return agentDiscovery.availability(of: .claudeCode).reason
    case .demo:
      return nil
    }
  }

  /// Forgets the recovered `PATH` so a CLI installed while the app was open can
  /// be found without a relaunch.
  func recheckAgentInstallations() {
    objectWillChange.send()
    SystemLocalAgentEnvironmentProbe.shared.forgetRecoveredPath()
  }

  var webResearchGranted: Bool {
    organization.hasCapability("web-research", employeeID: "nia")
  }

  var webResearchRequestPending: Bool {
    let events =
      organization.knowledge?.capabilityEvents.filter {
        $0.capability == "web-research" && $0.employeeID == "nia"
      } ?? []
    guard let last = events.last else { return false }
    return last.kind == .requested
  }

  var latestResearchAssignment: ResearchAssignment? {
    organization.latestResearchAssignment
  }

  var activeEmployeeOutcome: EmployeeOutcome? {
    organization.activeEmployeeOutcome
  }

  func latestEmployeeOutcome(for employeeID: String) -> EmployeeOutcome? {
    organization.latestEmployeeOutcome(for: employeeID)
  }

  var customerVoiceDuty: EmployeeDuty? {
    organization.employeeDuty(CustomerVoiceDutyEngine.dutyID)
  }

  var customerVoiceOccurrence: DutyOccurrence? {
    organization.latestOccurrence(for: CustomerVoiceDutyEngine.dutyID)
  }

  var isCustomerVoiceRunning: Bool {
    organization.activeOccurrence(for: CustomerVoiceDutyEngine.dutyID)?.status == .running
  }

  var isEmployeeRunActive: Bool { workTask != nil || !runningEmployeeIDs.isEmpty }

  var canRunCustomerVoiceDuty: Bool {
    workTask == nil
      && runningEmployeeIDs.isEmpty
      && organization.workdayStatus != .active
      && organization.activeResearchAssignment?.status != .researching
      && organization.activeEmployeeOutcome == nil
  }

  var canCreateEmployeeOutcome: Bool {
    organization.activeResearchAssignment == nil
      && !isCustomerVoiceRunning
      && organization.workdayStatus != .active
      && workTask == nil
  }

  var canEditOrganization: Bool {
    workTask == nil && runningEmployeeIDs.isEmpty && organization.workdayStatus != .active
  }

  func load() async {
    guard !isLoaded else { return }
    do {
      organization = try await store.loadOrCreate()
      await employeeWorkCoordinator.setConcurrencyLimit(organization.effectiveConcurrencyLimit)
      if organization.workdayStatus == .active || organization.workdayStatus == .ending {
        organization.workdayStatus = .resting
        for index in organization.employees.indices {
          organization.employees[index].status = .resting
          organization.employees[index].currentTaskID = nil
        }
        try await store.save(organization)
      }
      showsOnboarding = organization.setupCompleted != true
      if organization.employee(selectedEmployeeID ?? "") == nil {
        selectedEmployeeID = organization.employee("maya")?.id ?? organization.employees.first?.id
      }
      isLoaded = true
    } catch {
      lastError = error.localizedDescription
      isLoaded = true
    }
  }

  func completeOnboarding(
    name: String,
    ownerName: String,
    outcome: String,
    productBrief: String,
    profile: OrganizationProfile = .empty,
    executionMode: ExecutionMode? = nil,
    webResearchGranted: Bool? = nil,
    hiredPackageIDs: Set<String>? = nil,
    startImmediately: Bool
  ) async -> Bool {
    let requestedMode = executionMode ?? organization.executionMode
    var next = organization
    next.applyOnboarding(
      name: name,
      ownerName: ownerName,
      outcome: outcome,
      productBrief: productBrief,
      profile: profile,
      executionMode: requestedMode,
      webResearchGranted: webResearchGranted ?? self.webResearchGranted
    )
    let acceptedPackages = hiredPackageIDs ?? Set(next.employeePackages.map(\.id))
    for packageID in acceptedPackages {
      _ = try? next.hireEmployee(packageID: packageID, actorID: "owner")
    }
    next.applyExecutionProvider(
      EmployeeExecutionProvider(requestedMode),
      reason: "Selected during organization setup."
    )
    do {
      try await store.save(next)
      organization = next
      showsOnboarding = false
      lastError = nil
      if startImmediately { startDay() }
      return true
    } catch {
      lastError =
        "The company could not be opened because its local files were not saved: \(error.localizedDescription)"
      return false
    }
  }

  func revisitOnboarding() {
    guard workTask == nil, organization.workdayStatus != .active else { return }
    showsOnboarding = true
  }

  func toggleDay() {
    if organization.workdayStatus == .active {
      endDay()
    } else {
      startDay()
    }
  }

  func startDay() {
    guard workTask == nil, organization.workdayStatus != .active else { return }
    guard organization.activeResearchAssignment == nil else {
      lastError =
        "Nia already has a research commitment. Resolve it before preparing the content mission."
      return
    }
    guard !isCustomerVoiceRunning else {
      lastError =
        "Iris is already running Customer Voice Weekly. Stop or finish it before starting the content workday."
      return
    }
    if organization.executionMode == .localCodex && !organization.hasMeaningfulProductBrief {
      lastError =
        "Mira needs a real product brief before the team can produce honest work. Add the product, audience, problem, and claims first."
      return
    }
    if organization.executionMode == .localCodex && !codexAvailable {
      appendCapabilityEvent(
        kind: .unavailable,
        actorID: "nia",
        detail: "Local Codex is not available, so no external research was attempted."
      )
      lastError =
        "Local Codex is not available on this machine. Reconnect it before real research, or switch to Demo for an owner-context-only rehearsal."
      persistSoon()
      return
    }
    if organization.executionMode == .localCodex && !webResearchGranted {
      requestWebResearch()
      lastError =
        "Nia is asking for read-only web research. Grant it in today's folio, or switch to Demo for an owner-context-only rehearsal."
      return
    }

    do {
      let outcomeIDs = try organization.prepareFirstContentMission()
      organization.activity.append(
        Activity(
          id: UUID().uuidString, actorID: "owner", kind: .started,
          message: "You prepared the first content mission as three employee-owned outcomes.",
          createdAt: Date()))
      lastError = nil
      persistSoon()
      for outcomeID in outcomeIDs { beginEmployeeOutcome(outcomeID) }
    } catch { lastError = error.localizedDescription }
  }

  func endDay() {
    if !runningEmployeeIDs.isEmpty {
      let employeeIDs = runningEmployeeIDs
      runningEmployeeIDs.removeAll()
      Task { [coordinator = employeeWorkCoordinator] in
        for employeeID in employeeIDs { await coordinator.cancel(employeeID: employeeID) }
      }
      for outcome in organization.employeeOutcomes
      where employeeIDs.contains(outcome.assigneeID) && outcome.status.isActivelyRunning {
        _ = organization.updateEmployeeOutcome(outcome.id) { value in
          value.status = .queued
          value.helpRequest = "The owner paused this employee run. It is ready to resume."
          value.outcomeRevision = value.effectiveRevision + 1
        }
      }
      restEmployees()
      persistSoon()
      return
    }
    let previous = organization
    workTask?.cancel()
    workTask = nil
    _ = organization.resetInterruptedResearch()
    _ = organization.resetInterruptedDuty()
    _ = organization.resetInterruptedEmployeeOutcome()
    ExecutiveAssistant.appendInterruptedHandoff(to: &organization)
    organization.workdayStatus = .resting
    for index in organization.employees.indices {
      organization.employees[index].status = .resting
      organization.employees[index].currentTaskID = nil
    }
    organization.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "owner",
        kind: .stopped,
        message: "The owner ended the day. The office is resting.",
        createdAt: Date()
      ))
    let snapshot = organization
    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.store.save(snapshot)
        self.lastError = nil
      } catch {
        var recovery = previous
        _ = recovery.resetInterruptedResearch()
        _ = recovery.resetInterruptedDuty()
        _ = recovery.resetInterruptedEmployeeOutcome()
        recovery.workdayStatus = .resting
        recovery.restAIEmployees()
        self.organization = recovery
        self.lastError =
          "The day could not end because the latest company state was not saved: \(error.localizedDescription)"
      }
    }
  }

  func cancelOnboarding() {
    guard organization.setupCompleted == true else { return }
    showsOnboarding = false
  }

  func setExecutionMode(_ mode: ExecutionMode) {
    guard workTask == nil, organization.workdayStatus != .active else { return }
    if mode == .localCodex && !codexAvailable {
      lastError = "Local Codex is not installed or discoverable. Demo mode remains available."
      organization.executionMode = .demo
      return
    }
    organization.executionMode = mode
    organization.applyExecutionProvider(
      EmployeeExecutionProvider(mode),
      reason: "Changed the default local execution route."
    )
    persistSoon()
    if mode == .demo, let assignment = organization.activeResearchAssignment,
      assignment.status == .waiting
    {
      retryResearchAssignment(assignment.id)
    }
  }

  func updateOutcome(_ outcome: String) async -> Bool {
    guard canEditOrganization else { return false }
    var next = organization
    next.outcome = outcome
    if !next.goals.isEmpty {
      next.goals[0].detail = outcome
    }
    if let profile = next.knowledge?.profile, profile != .empty {
      next.knowledge?.productBrief = Self.productBrief(profile: profile, outcome: outcome)
    }
    do {
      try await store.save(next)
      organization = next
      lastError = nil
      return true
    } catch {
      lastError = "The mission could not be saved: \(error.localizedDescription)"
      return false
    }
  }

  func updateProductBrief(_ brief: String) {
    guard canEditOrganization else {
      lastError = "End the current employee run before changing the product brief."
      return
    }
    if organization.knowledge == nil {
      organization.knowledge = OrganizationKnowledge(productBrief: brief)
    } else {
      organization.knowledge?.productBrief = brief
    }
    persistSoon()
  }

  func updateCompanyProfile(
    name: String,
    ownerName: String,
    outcome: String,
    profile: OrganizationProfile
  ) async -> Bool {
    guard canEditOrganization else {
      lastError = "End the current employee run before changing company memory."
      return false
    }

    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedOwnerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedOutcome = outcome.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty,
      !trimmedOwnerName.isEmpty,
      !trimmedOutcome.isEmpty,
      !profile.product.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !profile.audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      lastError = "Add the company name, owner, mission, product, and audience before saving."
      return false
    }

    var next = organization
    next.name = trimmedName
    next.outcome = trimmedOutcome
    if let ownerIndex = next.employees.firstIndex(where: { $0.id == "owner" }) {
      next.employees[ownerIndex].name = trimmedOwnerName
    }
    if let assistantIndex = next.employees.firstIndex(where: { $0.assistantForHumanID == "owner" })
    {
      next.employees[assistantIndex].responsibility =
        "Keep \(trimmedOwnerName) oriented, surface decisions, and prepare clear daily handoffs."
    }
    if !next.goals.isEmpty {
      next.goals[0].detail = trimmedOutcome
    }

    let normalizedProfile = OrganizationProfile(
      purpose: profile.purpose.trimmingCharacters(in: .whitespacesAndNewlines),
      product: profile.product.trimmingCharacters(in: .whitespacesAndNewlines),
      audience: profile.audience.trimmingCharacters(in: .whitespacesAndNewlines),
      stage: profile.stage.trimmingCharacters(in: .whitespacesAndNewlines),
      operatingPrinciples: profile.operatingPrinciples.trimmingCharacters(
        in: .whitespacesAndNewlines),
      constraints: profile.constraints.trimmingCharacters(in: .whitespacesAndNewlines)
    )
    let brief = Self.productBrief(profile: normalizedProfile, outcome: trimmedOutcome)
    if next.knowledge == nil {
      next.knowledge = OrganizationKnowledge(productBrief: brief, profile: normalizedProfile)
    } else {
      next.knowledge?.profile = normalizedProfile
      next.knowledge?.productBrief = brief
    }
    do {
      try await store.save(next)
      organization = next
      lastError = nil
      return true
    } catch {
      lastError = "The company book could not be saved: \(error.localizedDescription)"
      return false
    }
  }

  func setWebResearchGranted(_ granted: Bool) {
    guard let employeeIndex = organization.employees.firstIndex(where: { $0.id == "nia" }) else {
      return
    }
    let alreadyGranted = organization.employees[employeeIndex].capabilityGrants.contains(
      "web-research")
    guard alreadyGranted != granted else { return }

    let previous = organization
    var next = organization
    if granted {
      next.employees[employeeIndex].capabilityGrants.append("web-research")
    } else {
      next.employees[employeeIndex].capabilityGrants.removeAll { $0 == "web-research" }
    }
    if let contract = next.workingContract(for: "nia") {
      try? next.updateWorkingContract(
        employeeID: "nia",
        role: contract.role,
        responsibility: contract.responsibility,
        managerID: contract.managerID,
        assignedSkillIDs: contract.assignedSkillIDs,
        declaredConnectionIDs: contract.declaredConnectionIDs,
        capabilityGrants: next.employees[employeeIndex].capabilityGrants,
        executionProvider: contract.executionProvider,
        modelName: contract.modelName,
        boundaries: contract.boundaries,
        reviewPolicy: contract.reviewPolicy,
        actorID: "owner",
        reason: granted ? "Granted read-only web research." : "Revoked web research."
      )
    }
    appendCapabilityEvent(
      kind: granted ? .granted : .revoked,
      actorID: "owner",
      detail: granted
        ? "The owner granted Nia read-only web research."
        : "The owner revoked Nia's web research access.",
      state: &next
    )
    if !granted,
      workTask != nil,
      next.activeResearchAssignment?.status == .researching || next.workdayStatus == .active
    {
      workTask?.cancel()
      workTask = nil
      if next.activeResearchAssignment?.status == .researching {
        pauseResearchAfterPermissionRevocation(state: &next)
      } else {
        next.workdayStatus = .resting
        next.restAIEmployees()
        next.activity.append(
          Activity(
            id: UUID().uuidString,
            actorID: "mira",
            kind: .stopped,
            message: "Mira paused the workday after Nia's web access was revoked.",
            createdAt: Date()
          ))
      }
    }
    lastError = nil

    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.store.save(next)
        self.organization = next
        if granted,
          let assignment = next.activeResearchAssignment,
          assignment.status == .waiting
        {
          self.retryResearchAssignment(assignment.id)
        }
      } catch {
        var recovery = previous
        _ = recovery.resetInterruptedResearch()
        recovery.workdayStatus = .resting
        recovery.restAIEmployees()
        self.organization = recovery
        self.lastError =
          granted
          ? "Web research was not granted because the company folder could not be saved: \(error.localizedDescription)"
          : "Web research remains granted because the revocation could not be saved: \(error.localizedDescription)"
      }
    }
  }

  @discardableResult
  func submitResearchAssignment(outcome: String, context: String) -> Bool {
    guard workTask == nil, organization.workdayStatus != .active else {
      lastError = "End the current work before giving Nia another assignment."
      return false
    }
    do {
      let assignmentID = try organization.createResearchAssignment(
        outcome: outcome, context: context)
      lastError = nil
      persistSoon()
      if let outcomeID = organization.researchAssignment(assignmentID)?.canonicalOutcomeID {
        beginEmployeeOutcome(outcomeID)
      }
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  func retryResearchAssignment(_ assignmentID: String) {
    guard workTask == nil, organization.workdayStatus != .active,
      let assignment = organization.researchAssignment(assignmentID),
      let outcomeID = assignment.canonicalOutcomeID
    else { return }
    retryEmployeeOutcome(outcomeID)
  }

  func runCustomerVoiceDuty() {
    guard workTask == nil, organization.workdayStatus != .active else {
      lastError = "End the current employee run before starting Customer Voice Weekly."
      return
    }
    guard organization.activeResearchAssignment?.status != .researching else {
      lastError =
        "Nia is still researching. Let that assignment finish or stop it before Iris begins."
      return
    }
    if organization.executionMode == .localCodex && !codexAvailable {
      lastError =
        "Local Codex is unavailable. Reconnect it or use Practice mode for a synthetic Customer Voice run."
      return
    }

    do {
      let occurrenceID = try organization.beginDutyOccurrence(
        dutyID: CustomerVoiceDutyEngine.dutyID
      )
      lastError = nil
      persistSoon()
      if let outcomeID = organization.dutyOccurrence(occurrenceID)?.canonicalOutcomeID {
        beginEmployeeOutcome(outcomeID)
      }
    } catch {
      lastError = error.localizedDescription
    }
  }

  func stopCustomerVoiceDuty() {
    guard let occurrence = organization.activeOccurrence(for: CustomerVoiceDutyEngine.dutyID) else {
      return
    }
    if let outcomeID = occurrence.canonicalOutcomeID {
      stopEmployeeOutcome(outcomeID)
      _ = organization.stopDutyOccurrence(occurrence.id)
      persistSoon()
      return
    }
    workTask?.cancel()
    workTask = nil
    let previous = organization
    var next = organization
    guard next.stopDutyOccurrence(occurrence.id) else { return }

    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.store.save(next)
        self.organization = next
        self.lastError = nil
      } catch {
        var recovery = previous
        _ = recovery.resetInterruptedDuty()
        recovery.restAIEmployees()
        self.organization = recovery
        self.lastError =
          "Iris stopped, but the resumable duty state could not be saved: \(error.localizedDescription)"
      }
    }
  }

  func cancelResearchAssignment(_ assignmentID: String) {
    guard let assignment = organization.researchAssignment(assignmentID),
      !assignment.status.isTerminal
    else { return }
    if let outcomeID = assignment.canonicalOutcomeID {
      stopEmployeeOutcome(outcomeID)
      _ = organization.cancelResearchAssignment(assignmentID)
      persistSoon()
      return
    }
    let wasResearching = assignment.status == .researching
    if wasResearching {
      workTask?.cancel()
      workTask = nil
    }
    let previous = organization
    var next = organization
    guard next.cancelResearchAssignment(assignmentID) else { return }
    if wasResearching {
      next.workdayStatus = .resting
      next.restAIEmployees()
    }
    lastError = nil

    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.store.save(next)
        self.organization = next
      } catch {
        var recovery = previous
        _ = recovery.resetInterruptedResearch()
        if wasResearching {
          recovery.workdayStatus = .resting
          recovery.restAIEmployees()
        }
        self.organization = recovery
        self.lastError =
          "The assignment was paused but could not be durably stopped because the company folder could not be saved: \(error.localizedDescription)"
      }
    }
  }

  @discardableResult
  func submitEmployeeOutcome(employeeID: String, outcome: String, context: String) async -> Bool {
    guard canCreateEmployeeOutcome else {
      lastError = "Finish the fixed local workflow before assigning an employee outcome."
      return false
    }
    if organization.executionMode == .localCodex && !codexAvailable {
      lastError =
        "Local Codex is unavailable. Reconnect it or choose Demo for a synthetic rehearsal."
      return false
    }
    let command = OrganizationCommand(
      actor: .owner(id: "owner"),
      payload: .assignEmployeeOutcome(
        .init(employeeID: employeeID, outcome: outcome, context: context)),
      idempotencyKey: "assign-outcome:\(employeeID):\(UUID().uuidString)"
    )
    do {
      let applied = try await store.submit(command, to: organization)
      organization = applied.state
      lastError = nil
      if let outcomeID = applied.result.commitmentID { beginEmployeeOutcome(outcomeID) }
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  // MARK: - Scheduled work

  /// Starts scheduled work whose window is open right now.
  ///
  /// Foreground only, deliberately: nothing here claims the Mac will run work
  /// while asleep or while the app is closed. Windows that passed unnoticed are
  /// reconciled as missed rather than run late.
  func dispatchDueScheduledWork(now: Date = Date()) async {
    _ = organization.applyCatchUpPolicies(now: now)
    for occurrence in organization.dueOccurrences(now: now) {
      let sessionID = "scheduled-\(occurrence.id)"
      let binding = organization.effectiveRuntimeBinding(for: occurrence.origin.employeeID)
      let resolution = await runtimeRegistry.resolve(binding)
      let capacity = DispatchCapacity(
        runtimeIsAvailable: resolution.driver != nil,
        runtimeUnavailableReason: resolution.shadow?.reason
      )
      switch organization.beginScheduledWork(
        occurrence.id, now: now, sessionID: sessionID,
        runtimeKind: binding.driverKind.rawValue, capacity: capacity)
      {
      case .dispatched(_, let commitmentID):
        organization.registerRuntimeSession(
          RuntimeSessionPresence(
            id: sessionID,
            employeeID: occurrence.origin.employeeID,
            bindingID: binding.id,
            commitmentID: commitmentID,
            startedAt: now,
            state: .starting
          ))
        beginEmployeeOutcome(commitmentID)
      case .skippedNotReady(let occurrenceID, let reason):
        _ = try? organization.skipOccurrence(occurrenceID, reason: reason)
      case .waiting:
        // A capacity condition, not a refusal: it stays due for the next pass.
        continue
      case .notDue:
        continue
      }
    }
    persistSoon()
  }

  /// Skips an upcoming occurrence. Completed history is never touched.
  func skipScheduledOccurrence(_ occurrenceID: String) async {
    do {
      try organization.skipOccurrence(occurrenceID, reason: "You skipped this occurrence.")
      lastError = nil
      persistSoon()
    } catch {
      lastError = error.localizedDescription
    }
  }

  // MARK: - Runtime authority

  /// Refreshes what the runtime broker is waiting on, expiring anything past
  /// its deadline rather than leaving it open.
  func refreshPendingRuntimeRequests() async {
    await runtimeBroker.expirePending()
    pendingRuntimeRequests = await runtimeBroker.pendingRequests()
  }

  /// Settles a runtime request. Only the owner reaches this path.
  func resolveRuntimeRequest(_ requestID: String, with resolution: RuntimeAccessResolution) async {
    do {
      _ = try await runtimeBroker.resolve(
        requestID: requestID, with: resolution, actor: .owner(id: "owner"))
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
    pendingRuntimeRequests = await runtimeBroker.pendingRequests()
    if let reloaded = try? await store.loadOrCreate() { organization = reloaded }
  }

  func retryEmployeeOutcome(_ outcomeID: String) {
    guard workTask == nil, organization.workdayStatus != .active,
      organization.activeResearchAssignment == nil, !isCustomerVoiceRunning,
      organization.retryEmployeeOutcome(outcomeID)
    else { return }
    lastError = nil
    beginEmployeeOutcome(outcomeID)
  }

  func stopEmployeeOutcome(_ outcomeID: String) {
    guard let outcome = organization.employeeOutcome(outcomeID), !outcome.status.isTerminal else {
      return
    }
    runningEmployeeIDs.remove(outcome.assigneeID)
    Task { await employeeWorkCoordinator.cancel(employeeID: outcome.assigneeID) }
    let previous = organization
    var next = organization
    guard next.cancelEmployeeOutcome(outcomeID) else { return }
    organization = next
    lastError = nil

    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.store.save(next)
      } catch {
        var recovery = previous
        _ = recovery.resetInterruptedEmployeeOutcome()
        self.organization = recovery
        self.lastError =
          "The outcome stopped, but the resumable state could not be saved: \(error.localizedDescription)"
      }
    }
  }

  func approveEmployeeOutcomePlan(_ outcomeID: String) {
    superviseCommitment(.approvePlan(commitmentID: outcomeID, note: "Approved as proposed.")) {
      [weak self] in self?.beginEmployeeOutcome(outcomeID)
    }
  }

  func replyToEmployeeOutcome(_ outcomeID: String, message: String) {
    superviseCommitment(.replyToHelp(commitmentID: outcomeID, message: message)) {
      [weak self] in self?.beginEmployeeOutcome(outcomeID)
    }
  }

  func acceptEmployeeOutcome(_ outcomeID: String, note: String = "") {
    superviseCommitment(.acceptDelivery(commitmentID: outcomeID, note: note)) {
      [weak self] in self?.dispatchEmployeeWork()
    }
  }

  func requestEmployeeOutcomeRevision(_ outcomeID: String, feedback: String) {
    superviseCommitment(.requestRevision(commitmentID: outcomeID, feedback: feedback)) {
      [weak self] in self?.beginEmployeeOutcome(outcomeID)
    }
  }

  func returnEmployeeOutcomePlan(_ outcomeID: String, instruction: String) {
    superviseCommitment(.returnPlan(commitmentID: outcomeID, instruction: instruction)) {
      [weak self] in self?.beginEmployeeOutcome(outcomeID)
    }
  }

  /// Owner decisions travel the same journalled boundary as everything else
  /// consequential, so what the owner decided and when is retained history
  /// rather than a mutation nobody recorded.
  private func superviseCommitment(
    _ decision: SupervisionDecision, then follow: @escaping @MainActor () -> Void
  ) {
    Task {
      do {
        let command = OrganizationCommand(
          actor: .owner(id: "owner"),
          payload: .superviseCommitment(decision),
          idempotencyKey:
            "supervision:\(decision.eventType):\(decision.commitmentID):\(UUID().uuidString)"
        )
        organization = try await store.submit(command, to: organization).state
        lastError = nil
        follow()
      } catch {
        lastError = error.localizedDescription
      }
    }
  }

  func reorderEmployeeOutcome(_ outcomeID: String, offset: Int) {
    guard let outcome = organization.employeeOutcome(outcomeID) else { return }
    let queue = organization.queuedEmployeeOutcomes(for: outcome.assigneeID)
    guard let index = queue.firstIndex(where: { $0.id == outcomeID }) else { return }
    do {
      try organization.reorderOutcome(outcomeID, to: index + offset)
      lastError = nil
      persistSoon()
    } catch { lastError = error.localizedDescription }
  }

  func reassignEmployeeTicket(_ taskID: String, employeeID: String, reason: String) {
    do {
      try organization.reassignTicket(taskID, to: employeeID, reason: reason)
      lastError = nil
      persistSoon()
    } catch { lastError = error.localizedDescription }
  }

  @discardableResult
  func hireEmployee(packageID: String, version: String? = nil) -> Bool {
    decideEmployment(.hire(packageID: packageID, version: version)) { [weak self] produced in
      if let employeeID = produced.first { self?.selectedEmployeeID = employeeID }
    }
    return true
  }

  func pauseEmployee(_ employeeID: String) {
    runningEmployeeIDs.remove(employeeID)
    Task { await employeeWorkCoordinator.cancel(employeeID: employeeID) }
    decideEmployment(.pause(employeeID: employeeID))
  }

  func resumeEmployee(_ employeeID: String) {
    decideEmployment(.resume(employeeID: employeeID)) { [weak self] _ in
      self?.dispatchEmployeeWork()
    }
  }

  func retireEmployee(_ employeeID: String) {
    decideEmployment(.retire(employeeID: employeeID))
  }

  /// Who works here is as consequential as what they are working on, so these
  /// decisions travel the same journalled boundary.
  private func decideEmployment(
    _ decision: EmploymentDecision,
    then follow: @escaping @MainActor ([String]) -> Void = { _ in }
  ) {
    Task {
      do {
        let command = OrganizationCommand(
          actor: .owner(id: "owner"),
          payload: .decideEmployment(decision),
          idempotencyKey: "employment:\(decision.eventType):\(UUID().uuidString)"
        )
        let applied = try await store.submit(command, to: organization)
        organization = applied.state
        lastError = nil
        follow(applied.result.producedIDs)
      } catch {
        lastError = error.localizedDescription
      }
    }
  }

  func importEmployeePackage() {
    let panel = NSOpenPanel()
    panel.title = "Import employee package"
    panel.message =
      "Choose one declarative JSON employee package. Packages cannot contain credentials or executable code."
    panel.prompt = "Import Package"
    panel.allowedContentTypes = [.json]
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowsMultipleSelection = false
    guard panel.runModal() == .OK, let url = panel.url else { return }
    Task { [weak self] in
      guard let self else { return }
      do {
        self.organization = try await self.store.importEmployeePackage(
          from: url, into: self.organization)
        self.lastError = nil
      } catch { self.lastError = error.localizedDescription }
    }
  }

  /// A revision decides an employee's role, skills, connections, grants,
  /// provider, model and boundaries, so it travels the same journalled boundary
  /// as hiring rather than mutating the contract in place.
  func reviseWorkingContract(_ revision: WorkingContractRevision) {
    Task {
      do {
        let command = OrganizationCommand(
          actor: .owner(id: "owner"),
          payload: .reviseWorkingContract(revision),
          idempotencyKey: revision.idempotencyKey
        )
        organization = try await store.submit(command, to: organization).state
        lastError = nil
      } catch {
        lastError = error.localizedDescription
      }
    }
  }

  func artifact(_ id: String?) -> Artifact? {
    guard let id else { return nil }
    return organization.artifacts.first { $0.id == id }
  }

  @discardableResult
  func teachSkill(
    name: String,
    category: String,
    purpose: String,
    instructions: String,
    successCriteria: String,
    requiredConnectionID: String?,
    employeeID: String
  ) -> Bool {
    guard canEditOrganization else {
      lastError = "End the current employee run before teaching a new skill."
      return false
    }
    do {
      _ = try organization.teachSkill(
        name: name,
        category: category,
        purpose: purpose,
        instructions: instructions,
        successCriteria: successCriteria,
        requiredConnectionIDs: requiredConnectionID.map { [$0] } ?? [],
        employeeID: employeeID
      )
      lastError = nil
      persistSoon()
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  @discardableResult
  func assignSkill(_ skillID: String, to employeeID: String) -> Bool {
    guard canEditOrganization else {
      lastError = "End the current employee run before changing skill assignments."
      return false
    }
    let assigned = organization.assignSkill(skillID: skillID, employeeID: employeeID)
    if assigned {
      lastError = nil
      persistSoon()
    }
    return assigned
  }

  func revealEmployeeHome(_ employeeID: String) {
    NSWorkspace.shared.activateFileViewerSelecting([store.employeeHomeURL(employeeID: employeeID)])
  }

  func revealFeedbackInbox() {
    Task { [weak self] in
      guard let self else { return }
      do {
        let url = try await self.store.ensureFeedbackInbox()
        NSWorkspace.shared.activateFileViewerSelecting([url])
        self.lastError = nil
      } catch {
        self.lastError =
          "The local feedback inbox could not be opened: \(error.localizedDescription)"
      }
    }
  }

  func chooseOrganizationFolder() {
    guard workTask == nil, organization.workdayStatus != .active else {
      lastError = "End the current employee run before moving the company home."
      return
    }
    let panel = NSOpenPanel()
    panel.title = "Choose an organization folder"
    panel.message = "State and employee artifacts stay inside this folder."
    panel.prompt = "Use Folder"
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false

    guard panel.runModal() == .OK, let url = panel.url else { return }
    workTask?.cancel()
    workTask = nil
    Task { await switchOrganization(to: url) }
  }

  func revealOrganizationFolder() {
    NSWorkspace.shared.activateFileViewerSelecting([organizationURL])
  }

  func reveal(_ artifact: Artifact) {
    let url = organizationURL.appendingPathComponent(artifact.relativePath)
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  func employeeName(_ id: String) -> String {
    id == "owner" ? "You" : organization.employee(id)?.name ?? id
  }

  func taskTitle(_ id: String?) -> String? {
    guard let id else { return nil }
    return organization.task(id)?.title
      ?? organization.dutyOccurrence(id).flatMap { organization.employeeDuty($0.dutyID)?.title }
  }

  private func switchOrganization(to url: URL) async {
    let nextStore = LocalOrganizationStore(rootURL: url)
    do {
      let next = try await nextStore.loadOrCreate()
      store = nextStore
      organization = next
      selectedEmployeeID = next.employee("maya")?.id ?? next.employees.first?.id
      showsOnboarding = next.setupCompleted != true
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  private func requestWebResearch(taskID: String = "research-audience") {
    guard !webResearchRequestPending else { return }
    appendCapabilityEvent(
      kind: .requested,
      actorID: "nia",
      detail: "Nia requested read-only web research for the current assignment.",
      taskID: taskID
    )
    organization.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "nia",
        kind: .blocked,
        message: "I need your permission to research the web before I begin.",
        createdAt: Date()
      ))
    persistSoon()
  }

  private func appendCapabilityEvent(
    kind: CapabilityEventKind,
    actorID: String,
    detail: String,
    taskID: String = "research-audience"
  ) {
    appendCapabilityEvent(
      kind: kind,
      actorID: actorID,
      detail: detail,
      taskID: taskID,
      state: &organization
    )
  }

  private func appendCapabilityEvent(
    kind: CapabilityEventKind,
    actorID: String,
    detail: String,
    taskID: String = "research-audience",
    state: inout OrganizationState
  ) {
    if state.knowledge == nil {
      state.knowledge = OrganizationKnowledge(productBrief: "")
    }
    state.knowledge?.capabilityEvents.append(
      CapabilityEvent(
        id: UUID().uuidString,
        capability: "web-research",
        employeeID: "nia",
        taskID: taskID,
        actorID: actorID,
        kind: kind,
        detail: detail,
        createdAt: Date()
      ))
  }

  private func beginEmployeeOutcome(_ outcomeID: String) {
    Task { [weak self] in await self?.scheduleEmployeeOutcome(outcomeID) }
  }

  private func dispatchEmployeeWork() {
    Task { [weak self] in await self?.dispatchEligibleEmployeeWork() }
  }

  private func scheduleEmployeeOutcome(_ outcomeID: String) async {
    guard workTask == nil, organization.workdayStatus != .active,
      organization.activeResearchAssignment == nil, !isCustomerVoiceRunning,
      let outcome = organization.employeeOutcome(outcomeID),
      !runningEmployeeIDs.contains(outcome.assigneeID),
      [.queued, .waiting, .failed, .approved, .revision].contains(outcome.status),
      organization.employee(outcome.assigneeID)?.effectiveEmploymentState == .hired,
      await employeeWorkCoordinator.activeCount < organization.effectiveConcurrencyLimit
    else { return }

    if outcome.attemptCount == 0 { organization.dayNumber += 1 }
    organization = employeeOutcomeEngine.start(organization, outcomeID: outcomeID)
    guard organization.employeeOutcome(outcomeID)?.status == .planning else { return }
    do { try await store.save(organization) } catch {
      _ = organization.resetInterruptedEmployeeOutcome()
      lastError =
        "The employee could not start because the organization folder was not saved: \(error.localizedDescription)"
      return
    }

    let request: EmployeeOutcomeRunRequest
    do {
      request = try EmployeeOutcomeRunRequest(organization: organization, outcomeID: outcomeID)
    } catch {
      lastError = error.localizedDescription
      return
    }
    let store = self.store
    let outcomeEngine = self.employeeOutcomeEngine
    let registry = self.runtimeRegistry
    let broker = self.runtimeBroker
    let binding = organization.effectiveRuntimeBinding(for: request.employeeID)
    let submitted = await employeeWorkCoordinator.submit(
      request,
      operation: { request in
        // The runtime an employee works through is resolved from its binding.
        // A missing or unhealthy runtime surfaces its reason instead of
        // silently substituting a different one.
        switch await registry.resolve(binding) {
        case .unavailable(let shadow):
          throw RuntimeUnavailableError(shadow)
        case .resolved(let driver):
          let session = try await driver.openSession(
            employeeID: request.employeeID,
            bindingID: binding.id,
            sessionID: UUID().uuidString
          )
          let runner = RuntimeSessionRunner(
            session: session,
            employeeID: request.employeeID,
            commitmentID: request.outcomeID,
            correlationID: request.outcomeID
          )
          // Work receives what the broker authorizes now, not the employee's
          // whole grant list.
          let authorized = await broker.authorizedCapabilities(
            employeeID: request.employeeID,
            commitmentID: request.outcomeID,
            organization: request.organization
          )
          return try await outcomeEngine.execute(
            request, runner: runner, store: store, authorizedCapabilities: authorized)
        }
      },
      completion: { [weak self] result in
        await self?.handleEmployeeRunResult(result, request: request)
      })
    if submitted {
      runningEmployeeIDs.insert(request.employeeID)
    } else {
      _ = organization.updateEmployeeOutcome(outcomeID) { $0.status = .queued }
      if let index = organization.employees.firstIndex(where: { $0.id == request.employeeID }) {
        organization.employees[index].status = .resting
      }
    }
  }

  private func handleEmployeeRunResult(
    _ result: Result<EmployeeOutcomeRunResult, Error>, request: EmployeeOutcomeRunRequest
  ) async {
    guard runningEmployeeIDs.remove(request.employeeID) != nil else { return }
    do {
      switch result {
      case .success(let runResult):
        // The runtime hands work back through the same command boundary the
        // owner uses, so a retried result cannot apply twice.
        let command = OrganizationCommand(
          actor: .employeeRuntime(employeeID: request.employeeID, sessionID: nil),
          payload: .applyEmployeeRunResult(runResult),
          idempotencyKey:
            "run-result:\(runResult.outcomeID):\(runResult.expectedOutcomeRevision)"
        )
        organization = try await store.submit(command, to: organization).state
        organization.synchronizeLegacyAdapters(outcomeID: request.outcomeID)
      case .failure(let error):
        _ = organization.updateEmployeeOutcome(request.outcomeID) { value in
          value.status = .waiting
          value.helpRequest = "I could not continue: \(error.localizedDescription)"
          value.outcomeRevision = value.effectiveRevision + 1
        }
        if let index = organization.employees.firstIndex(where: { $0.id == request.employeeID }) {
          organization.employees[index].status = .blocked
          organization.employees[index].currentTaskID = nil
        }
      }
      try await store.save(organization)
      lastError = organization.employeeOutcome(request.outcomeID)?.helpRequest
    } catch {
      _ = organization.updateEmployeeOutcome(request.outcomeID) { value in
        value.status = .waiting
        value.helpRequest =
          "The run result could not be applied safely: \(error.localizedDescription)"
        value.outcomeRevision = value.effectiveRevision + 1
      }
      lastError = error.localizedDescription
      try? await store.save(organization)
    }
    await dispatchEligibleEmployeeWork()
  }

  private func dispatchEligibleEmployeeWork() async {
    let candidates = organization.employeeOutcomes
      .filter {
        [.queued, .approved, .revision].contains($0.status)
          && organization.employee($0.assigneeID)?.effectiveEmploymentState == .hired
      }
      .sorted {
        if $0.effectivePriority.rank != $1.effectivePriority.rank {
          return $0.effectivePriority.rank < $1.effectivePriority.rank
        }
        return $0.effectiveQueuePosition < $1.effectiveQueuePosition
      }
    for outcome in candidates {
      guard await employeeWorkCoordinator.activeCount < organization.effectiveConcurrencyLimit
      else { break }
      await scheduleEmployeeOutcome(outcome.id)
    }
  }

  private func pauseResearchAfterPermissionRevocation(state: inout OrganizationState) {
    guard let assignment = state.activeResearchAssignment,
      assignment.status == .researching
    else { return }
    _ = state.updateResearchAssignment(assignment.id) { value in
      value.status = .waiting
      value.blockingReason =
        "Web research was revoked. Grant it again, use Demo, or stop this assignment."
    }
    state.workdayStatus = .resting
    state.restAIEmployees()
    state.activity.append(
      Activity(
        id: UUID().uuidString,
        actorID: "mira",
        kind: .stopped,
        message: "Mira paused Nia's research after web access was revoked.",
        createdAt: Date()
      ))
  }

  private func restEmployees() {
    organization.restAIEmployees()
  }

  private static func productBrief(profile: OrganizationProfile, outcome: String) -> String {
    """
    # Product brief

    ## Organization purpose
    \(profile.purpose)

    ## Product
    \(profile.product)

    ## Audience
    \(profile.audience)

    ## Current stage
    \(profile.stage)

    ## Current outcome
    \(outcome)

    ## Operating principles
    \(profile.operatingPrinciples)

    ## Constraints and claims we can support
    \(profile.constraints)
    """
  }

  private func persistSoon() {
    let snapshot = organization
    Task { [weak self] in
      guard let self else { return }
      do {
        try await self.store.save(snapshot)
        self.lastError = nil
      } catch {
        if let durable = try? await self.store.loadOrCreate() {
          self.organization = durable
        }
        self.lastError =
          "The latest change was not kept because the company folder could not be saved: \(error.localizedDescription)"
      }
    }
  }
}
