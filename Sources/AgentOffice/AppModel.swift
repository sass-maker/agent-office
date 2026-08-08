import AgentOfficeCore
import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var organization: OrganizationState = .seeded()
    @Published var selectedEmployeeID: String? = "maya"
    @Published var isLoaded = false
    @Published var lastError: String?

    private var store: LocalOrganizationStore
    private let engine = WorkdayEngine()
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
            isLoaded = true
        } catch {
            lastError = error.localizedDescription
            isLoaded = true
        }
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
        guard organization.tasks.contains(where: { $0.status != .done && $0.status != .blocked }) else {
            lastError = "This POC workday is already complete. Its artifacts are ready to inspect."
            return
        }

        organization.workdayStatus = .active
        organization.dayNumber += 1
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
            await self.runWorkday(sessionID: sessionID)
        }
    }

    func endDay() {
        workTask?.cancel()
        workTask = nil
        workdaySessionID = nil
        organization.workdayStatus = .resting
        for index in organization.employees.indices {
            organization.employees[index].status = .resting
            organization.employees[index].currentTaskID = nil
        }
        organization.activity.append(Activity(
            id: UUID().uuidString,
            actorID: "owner",
            kind: .stopped,
            message: "The owner ended the day. Progress is saved for next time.",
            createdAt: Date()
        ))
        let snapshot = organization
        Task { try? await store.save(snapshot) }
    }

    func setExecutionMode(_ mode: ExecutionMode) {
        guard organization.workdayStatus != .active else { return }
        if mode == .localCodex && !codexAvailable {
            lastError = "Local Codex is not installed or discoverable. Demo mode remains available."
            organization.executionMode = .demo
            return
        }
        organization.executionMode = mode
        persistSoon()
    }

    func updateOutcome(_ outcome: String) {
        organization.outcome = outcome
        persistSoon()
    }

    func chooseOrganizationFolder() {
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
    }

    private func switchOrganization(to url: URL) async {
        let nextStore = LocalOrganizationStore(rootURL: url)
        do {
            let next = try await nextStore.loadOrCreate()
            store = nextStore
            organization = next
            selectedEmployeeID = next.employees.first?.id
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
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
                try await Task.sleep(for: .milliseconds(1_100))
            } catch {
                break
            }
        }
    }

    private func persistSoon() {
        let snapshot = organization
        Task { try? await store.save(snapshot) }
    }
}
