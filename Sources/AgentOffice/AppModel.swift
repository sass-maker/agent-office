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

    private var store: LocalOrganizationStore
    private let engine = WorkdayEngine()
    private let researchEngine = ResearchAssignmentEngine()
    private let customerVoiceEngine = CustomerVoiceDutyEngine()
    private let employeeOutcomeEngine = EmployeeOutcomeEngine()
    private var workTask: Task<Void, Never>?
    private var workdaySessionID: UUID?

    init() {
        store = LocalOrganizationStore(rootURL: Self.defaultOrganizationURL)
    }

    deinit {
        workTask?.cancel()
    }

    static var defaultOrganizationURL: URL {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        return applicationSupport
            .appendingPathComponent("AgentOffice", isDirectory: true)
            .appendingPathComponent("WillowStudioPOC", isDirectory: true)
    }

    var organizationURL: URL { store.rootURL }

    var codexAvailable: Bool { CodexEmployeeRunner.discover() != nil }

    var assistantBrief: AssistantBrief? {
        ExecutiveAssistant.morningBrief(for: organization)
    }

    var webResearchGranted: Bool {
        organization.hasCapability("web-research", employeeID: "nia")
    }

    var webResearchRequestPending: Bool {
        let events = organization.knowledge?.capabilityEvents.filter {
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

    var isEmployeeRunActive: Bool { workTask != nil }

    var canRunCustomerVoiceDuty: Bool {
        workTask == nil
            && organization.workdayStatus != .active
            && organization.activeResearchAssignment?.status != .researching
            && organization.activeEmployeeOutcome == nil
    }

    var canCreateResearchAssignment: Bool {
        organization.activeResearchAssignment == nil
            && organization.activeEmployeeOutcome == nil
            && workTask == nil
    }

    var canCreateEmployeeOutcome: Bool {
        organization.activeEmployeeOutcome == nil
            && organization.activeResearchAssignment == nil
            && !isCustomerVoiceRunning
            && organization.workdayStatus != .active
            && workTask == nil
    }

    var canEditOrganization: Bool {
        workTask == nil && organization.workdayStatus != .active
    }

    func load() async {
        guard !isLoaded else { return }
        do {
            organization = try await store.loadOrCreate()
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
        do {
            try await store.save(next)
            organization = next
            showsOnboarding = false
            lastError = nil
            if startImmediately { startDay() }
            return true
        } catch {
            lastError = "The company could not be opened because its local files were not saved: \(error.localizedDescription)"
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
        guard organization.activeEmployeeOutcome == nil else {
            lastError = "An employee already owns an active outcome. Finish or stop it before starting the fixed content workday."
            return
        }
        guard organization.activeResearchAssignment == nil else {
            lastError = "Nia already has an active research assignment. Resolve it from the research desk before starting the fixed content workday."
            return
        }
        guard !isCustomerVoiceRunning else {
            lastError = "Iris is already running Customer Voice Weekly. Stop or finish it before starting the content workday."
            return
        }
        guard organization.tasks.contains(where: {
            !$0.id.hasPrefix("employee-outcome-") && $0.status != .done && $0.status != .blocked
        }) else {
            lastError = "This POC workday is already complete. Its artifacts are ready to inspect."
            return
        }

        if organization.executionMode == .localCodex && !organization.hasMeaningfulProductBrief {
            lastError = "Mira needs a real product brief before the team can produce honest work. Add the product, audience, problem, and claims first."
            return
        }
        if organization.executionMode == .localCodex && !codexAvailable {
            appendCapabilityEvent(
                kind: .unavailable,
                actorID: "nia",
                detail: "Local Codex is not available, so no external research was attempted."
            )
            lastError = "Local Codex is not available on this machine. Reconnect it before real research, or switch to Demo for an owner-context-only rehearsal."
            persistSoon()
            return
        }
        if organization.executionMode == .localCodex && !webResearchGranted {
            requestWebResearch()
            lastError = "Nia is asking for read-only web research. Grant it in today's folio, or switch to Demo for an owner-context-only rehearsal."
            return
        }

        organization.workdayStatus = .active
        organization.dayNumber += 1
        if let firstTask = organization.tasks.first(where: { $0.status == .ready }),
           let employeeIndex = organization.employees.firstIndex(where: { $0.id == firstTask.assigneeID }) {
            organization.employees[employeeIndex].status = .planning
            organization.employees[employeeIndex].currentTaskID = firstTask.id
        }
        organization.activity.append(Activity(
            id: UUID().uuidString,
            actorID: "owner",
            kind: .started,
            message: "Day \(organization.dayNumber) started in \(organization.executionMode == .demo ? "Demo" : "Local Codex") mode.",
            createdAt: Date()
        ))
        lastError = nil

        let sessionID = UUID()
        workdaySessionID = sessionID
        workTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(650))
            await self.runWorkday(sessionID: sessionID)
        }
    }

    func endDay() {
        let previous = organization
        workTask?.cancel()
        workTask = nil
        workdaySessionID = nil
        _ = organization.resetInterruptedResearch()
        _ = organization.resetInterruptedDuty()
        _ = organization.resetInterruptedEmployeeOutcome()
        ExecutiveAssistant.appendInterruptedHandoff(to: &organization)
        organization.workdayStatus = .resting
        for index in organization.employees.indices {
            organization.employees[index].status = .resting
            organization.employees[index].currentTaskID = nil
        }
        organization.activity.append(Activity(
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
                self.restEmployees(state: &recovery)
                self.organization = recovery
                self.lastError = "The day could not end because the latest company state was not saved: \(error.localizedDescription)"
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
        persistSoon()
        if mode == .demo, let assignment = organization.activeResearchAssignment, assignment.status == .waiting {
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
        if let assistantIndex = next.employees.firstIndex(where: { $0.assistantForHumanID == "owner" }) {
            next.employees[assistantIndex].responsibility = "Keep \(trimmedOwnerName) oriented, surface decisions, and prepare clear daily handoffs."
        }
        if !next.goals.isEmpty {
            next.goals[0].detail = trimmedOutcome
        }

        let normalizedProfile = OrganizationProfile(
            purpose: profile.purpose.trimmingCharacters(in: .whitespacesAndNewlines),
            product: profile.product.trimmingCharacters(in: .whitespacesAndNewlines),
            audience: profile.audience.trimmingCharacters(in: .whitespacesAndNewlines),
            stage: profile.stage.trimmingCharacters(in: .whitespacesAndNewlines),
            operatingPrinciples: profile.operatingPrinciples.trimmingCharacters(in: .whitespacesAndNewlines),
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
        guard let employeeIndex = organization.employees.firstIndex(where: { $0.id == "nia" }) else { return }
        let alreadyGranted = organization.employees[employeeIndex].capabilityGrants.contains("web-research")
        guard alreadyGranted != granted else { return }

        let previous = organization
        var next = organization
        if granted {
            next.employees[employeeIndex].capabilityGrants.append("web-research")
        } else {
            next.employees[employeeIndex].capabilityGrants.removeAll { $0 == "web-research" }
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
           next.activeResearchAssignment?.status == .researching || next.workdayStatus == .active {
            workTask?.cancel()
            workTask = nil
            workdaySessionID = nil
            if next.activeResearchAssignment?.status == .researching {
                pauseResearchAfterPermissionRevocation(state: &next)
            } else {
                next.workdayStatus = .resting
                restEmployees(state: &next)
                next.activity.append(Activity(
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
                   assignment.status == .waiting {
                    self.retryResearchAssignment(assignment.id)
                }
            } catch {
                var recovery = previous
                _ = recovery.resetInterruptedResearch()
                recovery.workdayStatus = .resting
                self.restEmployees(state: &recovery)
                self.organization = recovery
                self.lastError = granted
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
        guard organization.activeEmployeeOutcome == nil else {
            lastError = "An employee already owns an active outcome. Finish or stop it before assigning research."
            return false
        }
        do {
            let assignmentID = try organization.createResearchAssignment(outcome: outcome, context: context)
            lastError = nil
            persistSoon()
            prepareResearchAssignment(assignmentID)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func retryResearchAssignment(_ assignmentID: String) {
        guard workTask == nil, organization.workdayStatus != .active,
              let assignment = organization.researchAssignment(assignmentID),
              assignment.status == .failed || assignment.status == .waiting || assignment.status == .queued
        else { return }
        _ = organization.updateResearchAssignment(assignmentID) { value in
            value.status = .queued
            value.blockingReason = nil
        }
        lastError = nil
        persistSoon()
        prepareResearchAssignment(assignmentID)
    }

    func runCustomerVoiceDuty() {
        guard workTask == nil, organization.workdayStatus != .active else {
            lastError = "End the current employee run before starting Customer Voice Weekly."
            return
        }
        guard organization.activeResearchAssignment?.status != .researching else {
            lastError = "Nia is still researching. Let that assignment finish or stop it before Iris begins."
            return
        }
        guard organization.activeEmployeeOutcome == nil else {
            lastError = "An employee already owns an active outcome. Finish or stop it before Iris begins."
            return
        }
        if organization.executionMode == .localCodex && !codexAvailable {
            lastError = "Local Codex is unavailable. Reconnect it or use Practice mode for a synthetic Customer Voice run."
            return
        }

        do {
            let occurrenceID = try organization.beginDutyOccurrence(
                dutyID: CustomerVoiceDutyEngine.dutyID
            )
            lastError = nil
            beginCustomerVoiceDuty(occurrenceID)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopCustomerVoiceDuty() {
        guard let occurrence = organization.activeOccurrence(for: CustomerVoiceDutyEngine.dutyID) else { return }
        workTask?.cancel()
        workTask = nil
        workdaySessionID = nil
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
                self.restEmployees(state: &recovery)
                self.organization = recovery
                self.lastError = "Iris stopped, but the resumable duty state could not be saved: \(error.localizedDescription)"
            }
        }
    }

    func cancelResearchAssignment(_ assignmentID: String) {
        guard let assignment = organization.researchAssignment(assignmentID),
              !assignment.status.isTerminal
        else { return }
        let wasResearching = assignment.status == .researching
        if wasResearching {
            workTask?.cancel()
            workTask = nil
            workdaySessionID = nil
        }
        let previous = organization
        var next = organization
        guard next.cancelResearchAssignment(assignmentID) else { return }
        if wasResearching {
            next.workdayStatus = .resting
            restEmployees(state: &next)
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
                    self.restEmployees(state: &recovery)
                }
                self.organization = recovery
                self.lastError = "The assignment was paused but could not be durably stopped because the company folder could not be saved: \(error.localizedDescription)"
            }
        }
    }

    @discardableResult
    func submitEmployeeOutcome(employeeID: String, outcome: String, context: String) -> Bool {
        guard canCreateEmployeeOutcome else {
            lastError = "Finish or stop the current employee work before assigning another outcome."
            return false
        }
        if organization.executionMode == .localCodex && !codexAvailable {
            lastError = "Local Codex is unavailable. Reconnect it or choose Demo for a synthetic rehearsal."
            return false
        }
        do {
            let outcomeID = try organization.createEmployeeOutcome(
                employeeID: employeeID,
                outcome: outcome,
                context: context
            )
            lastError = nil
            beginEmployeeOutcome(outcomeID)
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
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
        guard let outcome = organization.employeeOutcome(outcomeID), !outcome.status.isTerminal else { return }
        workTask?.cancel()
        workTask = nil
        workdaySessionID = nil
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
                self.lastError = "The outcome stopped, but the resumable state could not be saved: \(error.localizedDescription)"
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
                self.lastError = "The local feedback inbox could not be opened: \(error.localizedDescription)"
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
        workdaySessionID = nil
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
        organization.activity.append(Activity(
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
        state.knowledge?.capabilityEvents.append(CapabilityEvent(
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

    private func runWorkday(sessionID: UUID) async {
        defer {
            if workdaySessionID == sessionID {
                workTask = nil
                workdaySessionID = nil
            }
        }

        while !Task.isCancelled && organization.workdayStatus == .active {
            let runner: any EmployeeRunner
            if organization.executionMode == .localCodex, let codex = CodexEmployeeRunner.discover() {
                runner = codex
            } else {
                runner = DeterministicEmployeeRunner()
            }

            let next = await engine.advance(organization, runner: runner, store: store)
            guard !Task.isCancelled, workdaySessionID == sessionID else {
                try? await store.save(organization)
                return
            }
            organization = next
            if organization.workdayStatus != .active { break }

            do {
                try await Task.sleep(for: .milliseconds(1_900))
            } catch {
                break
            }
        }
    }

    private func prepareResearchAssignment(_ assignmentID: String) {
        guard let assignment = organization.researchAssignment(assignmentID), assignment.status == .queued else { return }
        if organization.executionMode == .localCodex && !codexAvailable {
            _ = organization.updateResearchAssignment(assignmentID) { value in
                value.status = .waiting
                value.blockingReason = "Local Codex is unavailable. Reconnect it or choose Demo for a synthetic rehearsal."
            }
            appendCapabilityEvent(
                kind: .unavailable,
                actorID: "nia",
                detail: "Local Codex was unavailable, so Nia did not begin the owner-directed research.",
                taskID: assignmentID
            )
            lastError = "Local Codex is unavailable. Reconnect it or switch to Demo to rehearse this assignment without external research."
            persistSoon()
            return
        }
        if organization.executionMode == .localCodex && !webResearchGranted {
            _ = organization.updateResearchAssignment(assignmentID) { value in
                value.status = .waiting
                value.blockingReason = "Nia needs your read-only web research grant before starting."
            }
            requestWebResearch(taskID: assignmentID)
            lastError = "Nia is waiting for read-only web research permission."
            persistSoon()
            return
        }
        beginResearchAssignment(assignmentID)
    }

    private func beginResearchAssignment(_ assignmentID: String) {
        guard workTask == nil, organization.workdayStatus != .active else { return }
        organization.dayNumber += 1
        organization = researchEngine.start(organization, assignmentID: assignmentID)
        guard organization.researchAssignment(assignmentID)?.status == .researching else { return }
        lastError = nil

        let sessionID = UUID()
        workdaySessionID = sessionID
        let initial = organization
        let store = self.store
        let researchEngine = self.researchEngine
        workTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await store.save(initial)
            } catch {
                guard self.workdaySessionID == sessionID else { return }
                self.handleResearchPersistenceFailure(assignmentID: assignmentID, error: error)
                return
            }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, self.workdaySessionID == sessionID else { return }
            let runner: any EmployeeRunner
            if initial.executionMode == .localCodex, let codex = CodexEmployeeRunner.discover() {
                runner = codex
            } else {
                runner = DeterministicEmployeeRunner()
            }
            let next = await researchEngine.run(
                initial,
                assignmentID: assignmentID,
                runner: runner,
                store: store
            )
            guard !Task.isCancelled, self.workdaySessionID == sessionID else { return }
            do {
                try await store.save(next)
            } catch {
                guard self.workdaySessionID == sessionID else { return }
                self.handleResearchPersistenceFailure(assignmentID: assignmentID, error: error)
                return
            }
            guard self.workdaySessionID == sessionID else { return }
            self.organization = next
            self.workTask = nil
            self.workdaySessionID = nil
        }
    }

    private func beginCustomerVoiceDuty(_ occurrenceID: String) {
        guard workTask == nil,
              organization.dutyOccurrence(occurrenceID)?.status == .running
        else { return }

        let sessionID = UUID()
        workdaySessionID = sessionID
        let initial = organization
        let store = self.store
        let dutyEngine = self.customerVoiceEngine
        workTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await store.save(initial)
            } catch {
                guard self.workdaySessionID == sessionID else { return }
                self.handleDutyPersistenceFailure(occurrenceID: occurrenceID, error: error)
                return
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, self.workdaySessionID == sessionID else { return }
            let runner: any EmployeeRunner
            if initial.executionMode == .localCodex, let codex = CodexEmployeeRunner.discover() {
                runner = codex
            } else {
                runner = DeterministicEmployeeRunner()
            }
            let next = await dutyEngine.run(
                initial,
                occurrenceID: occurrenceID,
                runner: runner,
                store: store
            )
            guard !Task.isCancelled, self.workdaySessionID == sessionID else { return }
            do {
                try await store.save(next)
            } catch {
                guard self.workdaySessionID == sessionID else { return }
                self.handleDutyPersistenceFailure(occurrenceID: occurrenceID, error: error)
                return
            }
            guard self.workdaySessionID == sessionID else { return }
            self.organization = next
            self.workTask = nil
            self.workdaySessionID = nil
        }
    }

    private func beginEmployeeOutcome(_ outcomeID: String) {
        guard workTask == nil, organization.workdayStatus != .active,
              organization.activeResearchAssignment == nil, !isCustomerVoiceRunning,
              let outcome = organization.employeeOutcome(outcomeID),
              [.queued, .waiting, .failed].contains(outcome.status)
        else { return }

        if outcome.attemptCount == 0 {
            organization.dayNumber += 1
        }
        organization = employeeOutcomeEngine.start(organization, outcomeID: outcomeID)
        guard organization.employeeOutcome(outcomeID)?.status == .planning else { return }

        let sessionID = UUID()
        workdaySessionID = sessionID
        let initial = organization
        let store = self.store
        let outcomeEngine = self.employeeOutcomeEngine
        workTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await store.save(initial)
            } catch {
                guard self.workdaySessionID == sessionID else { return }
                self.organization = initial
                _ = self.organization.resetInterruptedEmployeeOutcome()
                self.workTask = nil
                self.workdaySessionID = nil
                self.lastError = "The employee could not start because the organization folder was not saved: \(error.localizedDescription)"
                return
            }

            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, self.workdaySessionID == sessionID else { return }
            let runner: any EmployeeRunner
            if initial.executionMode == .localCodex, let codex = CodexEmployeeRunner.discover() {
                runner = codex
            } else {
                runner = DeterministicEmployeeRunner()
            }
            let next = await outcomeEngine.run(
                initial,
                outcomeID: outcomeID,
                runner: runner,
                store: store
            )
            guard !Task.isCancelled, self.workdaySessionID == sessionID else { return }
            do {
                try await store.save(next)
            } catch {
                guard self.workdaySessionID == sessionID else { return }
                var recovery = initial
                _ = recovery.resetInterruptedEmployeeOutcome()
                self.organization = recovery
                self.workTask = nil
                self.workdaySessionID = nil
                self.lastError = "The employee finished a step, but the organization could not save it: \(error.localizedDescription)"
                return
            }
            guard self.workdaySessionID == sessionID else { return }
            self.organization = next
            self.workTask = nil
            self.workdaySessionID = nil
            if let help = next.employeeOutcome(outcomeID)?.helpRequest {
                self.lastError = help
            } else {
                self.lastError = nil
            }
        }
    }

    private func pauseResearchAfterPermissionRevocation(state: inout OrganizationState) {
        guard let assignment = state.activeResearchAssignment,
              assignment.status == .researching
        else { return }
        _ = state.updateResearchAssignment(assignment.id) { value in
            value.status = .waiting
            value.blockingReason = "Web research was revoked. Grant it again, use Demo, or stop this assignment."
        }
        state.workdayStatus = .resting
        restEmployees(state: &state)
        state.activity.append(Activity(
            id: UUID().uuidString,
            actorID: "mira",
            kind: .stopped,
            message: "Mira paused Nia's research after web access was revoked.",
            createdAt: Date()
        ))
    }

    private func handleResearchPersistenceFailure(assignmentID: String, error: Error) {
        _ = organization.updateResearchAssignment(assignmentID) { value in
            value.status = .failed
            value.blockingReason = "The research state could not be saved. Check the company folder, then try again."
        }
        organization.workdayStatus = .resting
        restEmployees()
        workTask = nil
        workdaySessionID = nil
        lastError = "Nia's research was not marked delivered because the company folder could not be saved: \(error.localizedDescription)"
    }

    private func handleDutyPersistenceFailure(occurrenceID: String, error: Error) {
        _ = organization.updateDutyOccurrence(occurrenceID) { value in
            value.status = .blocked
            value.blockingReason = "The duty state could not be saved. Check the company folder, then retry."
        }
        restEmployees()
        workTask = nil
        workdaySessionID = nil
        lastError = "Iris's duty was not marked delivered because the company folder could not be saved: \(error.localizedDescription)"
    }

    private func restEmployees() {
        restEmployees(state: &organization)
    }

    private func restEmployees(state: inout OrganizationState) {
        for index in state.employees.indices where state.employees[index].kind == .ai {
            state.employees[index].status = .resting
            state.employees[index].currentTaskID = nil
        }
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
                self.lastError = "The latest change was not kept because the company folder could not be saved: \(error.localizedDescription)"
            }
        }
    }
}
