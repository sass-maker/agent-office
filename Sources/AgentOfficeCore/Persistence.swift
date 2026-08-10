import Foundation

public actor LocalOrganizationStore {
    public nonisolated let rootURL: URL

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public var organizationFileURL: URL {
        rootURL.appendingPathComponent("organization.json", isDirectory: false)
    }

    public var productBriefFileURL: URL {
        rootURL.appendingPathComponent("PRODUCT_BRIEF.md", isDirectory: false)
    }

    public var companyProfileFileURL: URL {
        rootURL.appendingPathComponent("COMPANY.md", isDirectory: false)
    }

    public var skillCatalogueFileURL: URL {
        rootURL.appendingPathComponent("SKILLS.md", isDirectory: false)
    }

    public var connectionCatalogueFileURL: URL {
        rootURL.appendingPathComponent("CONNECTIONS.md", isDirectory: false)
    }

    public var researchAssignmentsFileURL: URL {
        rootURL.appendingPathComponent("RESEARCH_ASSIGNMENTS.md", isDirectory: false)
    }

    public var dutiesFileURL: URL {
        rootURL.appendingPathComponent("DUTIES.md", isDirectory: false)
    }

    public var employeeOutcomesFileURL: URL {
        rootURL.appendingPathComponent("EMPLOYEE_OUTCOMES.md", isDirectory: false)
    }

    public nonisolated var feedbackInboxURL: URL {
        rootURL.appendingPathComponent("feedback-inbox", isDirectory: true)
    }

    public func loadOrCreate() throws -> OrganizationState {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: organizationFileURL.path) else {
            let organization = Self.migrated(OrganizationState.seeded())
            try save(organization)
            return organization
        }

        let data = try Data(contentsOf: organizationFileURL)
        var organization = Self.migrated(try decoder.decode(OrganizationState.self, from: data))
        _ = organization.resetInterruptedResearch()
        _ = organization.resetInterruptedDuty()
        _ = organization.resetInterruptedEmployeeOutcome()
        if fileManager.fileExists(atPath: productBriefFileURL.path),
           let brief = try? String(contentsOf: productBriefFileURL, encoding: .utf8),
           !brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            organization.knowledge?.productBrief = brief
        }
        try save(organization)
        return organization
    }

    public func save(_ organization: OrganizationState) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        var snapshot = Self.migrated(organization)
        snapshot.lastSavedAt = Date()
        let data = try encoder.encode(snapshot)
        try data.write(to: organizationFileURL, options: .atomic)
        try materialize(snapshot)
    }

    public func writeArtifact(relativePath: String, content: String) throws {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func readArtifact(relativePath: String) throws -> String {
        let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @discardableResult
    public func ensureFeedbackInbox() throws -> URL {
        try fileManager.createDirectory(at: feedbackInboxURL, withIntermediateDirectories: true)
        return feedbackInboxURL
    }

    public func captureFeedbackSnapshot() throws -> FeedbackInputSnapshot {
        try ensureFeedbackInbox()
        return try LocalFeedbackInboxScanner.capture(at: feedbackInboxURL, fileManager: fileManager)
    }

    public nonisolated func employeeHomeURL(employeeID: String) -> URL {
        rootURL
            .appendingPathComponent("employees", isDirectory: true)
            .appendingPathComponent(Self.safePathComponent(employeeID), isDirectory: true)
    }

    public nonisolated static func migrated(
        _ input: OrganizationState,
        now: Date = Date()
    ) -> OrganizationState {
        var organization = input
        organization.schemaVersion = max(organization.schemaVersion, 8)

        if organization.knowledge == nil {
            organization.knowledge = OrganizationKnowledge(
                productBrief: starterProductBrief(for: organization),
                profile: starterProfile(for: organization)
            )
        } else if organization.productBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let starterBrief = starterProductBrief(for: organization)
            organization.knowledge?.productBrief = starterBrief
        }
        if organization.knowledge?.profile.isEmpty != false {
            let profile = starterProfile(for: organization)
            organization.knowledge?.profile = profile
        }

        if organization.employee("owner") == nil {
            organization.employees.insert(Employee(
                id: "owner",
                name: "Founder",
                kind: .human,
                role: "Owner",
                responsibility: "Set the company's outcomes, make judgment calls, and approve new access.",
                avatarColor: "D9B18E"
            ), at: 0)
        }

        let humans = organization.employees.filter { $0.kind == .human }
        for human in humans where organization.assistant(for: human.id) == nil {
            let assistantID = human.id == "owner" ? "mira" : "assistant-\(safePathComponent(human.id))"
            guard organization.employee(assistantID) == nil else { continue }
            organization.employees.insert(Employee(
                id: assistantID,
                name: human.id == "owner" ? "Mira" : "Avery",
                role: "Executive Assistant",
                responsibility: "Keep \(human.name) oriented, surface decisions, and prepare clear daily handoffs.",
                managerID: human.id,
                assistantForHumanID: human.id,
                avatarColor: "B7A5D8"
            ), at: min(1, organization.employees.count))
            organization.activity.append(Activity(
                id: UUID().uuidString,
                actorID: assistantID,
                kind: .joined,
                message: "\(human.id == "owner" ? "Mira" : "Avery") joined as \(human.name)'s executive assistant.",
                createdAt: now
            ))
        }

        if organization.employee("iris") == nil {
            organization.employees.append(Employee(
                id: "iris",
                name: "Iris",
                role: "Customer Voice Analyst",
                responsibility: "Turn deliberately supplied customer feedback into one cited owner decision each week.",
                managerID: "mira",
                avatarColor: "6E8B62"
            ))
            organization.activity.append(Activity(
                id: UUID().uuidString,
                actorID: "iris",
                kind: .joined,
                message: "Iris joined as the Customer Voice Analyst.",
                createdAt: now
            ))
        }

        let builtInSkills = OrganizationKnowledge.builtInSkills(now: now)
        for skill in builtInSkills where organization.skill(skill.id) == nil {
            organization.knowledge?.skillDefinitions.append(skill)
        }

        let builtInAssignments = OrganizationKnowledge.builtInAssignments(now: now)
        for assignment in builtInAssignments {
            guard organization.employee(assignment.employeeID) != nil,
                  organization.skill(assignment.skillID) != nil,
                  organization.knowledge?.skillAssignments.contains(where: {
                      $0.employeeID == assignment.employeeID && $0.skillID == assignment.skillID
                  }) != true
            else { continue }
            organization.knowledge?.skillAssignments.append(assignment)
        }

        for employee in organization.employees where employee.kind == .ai {
            let assignmentID = "\(employee.id):communication"
            guard organization.skill("communication") != nil,
                  organization.knowledge?.skillAssignments.contains(where: {
                      $0.employeeID == employee.id && $0.skillID == "communication"
                  }) != true
            else { continue }
            organization.knowledge?.skillAssignments.append(EmployeeSkillAssignment(
                id: assignmentID,
                skillID: "communication",
                employeeID: employee.id,
                assignedByActorID: "agent-office",
                assignedAt: now
            ))
        }

        for connection in OrganizationKnowledge.builtInConnections()
            where organization.knowledge?.connectionDefinitions.contains(where: { $0.id == connection.id }) != true {
            organization.knowledge?.connectionDefinitions.append(connection)
        }
        if organization.employeeDuty("customer-voice-weekly") == nil {
            organization.knowledge?.employeeDuties.append(.customerVoiceWeekly(now: now))
        }
        return organization
    }

    public nonisolated static func artifactPath(
        employeeID: String,
        taskID: String,
        kind: ArtifactKind,
        revision: Int = 0
    ) -> String {
        let suffix = revision > 0 ? "-v\(revision + 1)" : ""
        return "employees/\(employeeID)/\(taskID)-\(kind.rawValue)\(suffix).md"
    }

    private func materialize(_ organization: OrganizationState) throws {
        try fileManager.createDirectory(at: feedbackInboxURL, withIntermediateDirectories: true)
        try (organization.productBrief + "\n").write(
            to: productBriefFileURL,
            atomically: true,
            encoding: .utf8
        )

        let profile = organization.knowledge?.profile ?? .empty
        let members = organization.employees.map { employee in
            let manager = employee.managerID.flatMap { organization.employee($0)?.name } ?? "Independent"
            let assistant = employee.assistantForHumanID.map { " · paired with \(organization.employee($0)?.name ?? $0)" } ?? ""
            return "- **\(employee.name)** · \(employee.kind == .human ? "Human" : "AI") · \(employee.role) · reports to \(manager)\(assistant)"
        }.joined(separator: "\n")
        try """
        # \(organization.name)

        ## Purpose

        \(profile.purpose)

        ## Product

        \(profile.product)

        ## Audience

        \(profile.audience)

        ## Current stage

        \(profile.stage)

        ## Current mission

        \(organization.outcome)

        ## Operating principles

        \(profile.operatingPrinciples)

        ## Constraints

        \(profile.constraints)

        ## Members

        \(members)
        """.write(to: companyProfileFileURL, atomically: true, encoding: .utf8)

        let skillCatalogue = (organization.knowledge?.skillDefinitions ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { skill in
                let assignees = organization.employeesWithSkill(skill.id).map(\.name)
                let connections = skill.requiredConnectionIDs.isEmpty ? "None" : skill.requiredConnectionIDs.joined(separator: ", ")
                return """
                ## \(skill.name) · v\(skill.version)

                - Source: \(skill.source == .builtIn ? "Built in" : "Owner-taught guidance")
                - Category: \(skill.category)
                - Assigned employees: \(assignees.isEmpty ? "None" : assignees.joined(separator: ", "))
                - Required connections: \(connections)

                **Purpose:** \(skill.purpose)

                **Instructions:** \(skill.instructions)

                **Success criteria:** \(skill.successCriteria)
                """
            }
            .joined(separator: "\n\n")
        try "# Organization skills\n\n\(skillCatalogue.isEmpty ? "No skills in the catalogue." : skillCatalogue)\n".write(
            to: skillCatalogueFileURL,
            atomically: true,
            encoding: .utf8
        )

        let connectionCatalogue = (organization.knowledge?.connectionDefinitions ?? [])
            .map { connection in
                let grants = connection.capabilityID.map { capability in
                    organization.employees.filter { $0.capabilityGrants.contains(capability) }.map(\.name)
                } ?? []
                return "- **\(connection.name)** (`\(connection.id)`) · \(connection.kind.rawValue)\n  \(connection.summary)\n  Permission grants: \(grants.isEmpty ? "None" : grants.joined(separator: ", "))"
            }
            .joined(separator: "\n")
        try "# Recognized connections\n\nNo credentials are stored in this catalogue.\n\n\(connectionCatalogue)\n".write(
            to: connectionCatalogueFileURL,
            atomically: true,
            encoding: .utf8
        )

        let assignmentHistory = organization.researchAssignments
            .sorted { $0.createdAt > $1.createdAt }
            .map { assignment in
                let briefPath = assignment.briefArtifactID.flatMap { id in
                    organization.artifacts.first { $0.id == id }?.relativePath
                }
                let deliveryPath = assignment.deliveryArtifactID.flatMap { id in
                    organization.artifacts.first { $0.id == id }?.relativePath
                }
                let blocker = assignment.blockingReason.map { "\n- Current blocker: \($0)" } ?? ""
                let brief = briefPath.map { "[Open Nia's brief](\($0))" } ?? "No brief delivered"
                let delivery = deliveryPath.map { "[Open Mira's delivery](\($0))" } ?? "No delivery note"
                return """
                ## \(assignment.outcome)

                - Status: `\(assignment.status.rawValue)`
                - Flow: `\(assignment.requestedByActorID)` → `\(assignment.delegatedByActorID)` → `\(assignment.assigneeID)`
                - Evidence basis: \(assignment.evidenceBasis ?? "Not established")
                - Attempts: \(assignment.attemptCount)
                - Updated: \(assignment.updatedAt.formatted(.iso8601))\(blocker)

                \(brief) · \(delivery)
                """
            }
            .joined(separator: "\n\n")
        try "# Research assignments\n\n\(assignmentHistory.isEmpty ? "No research assignments yet." : assignmentHistory)\n".write(
            to: researchAssignmentsFileURL,
            atomically: true,
            encoding: .utf8
        )

        let dutyHistory = organization.employeeDuties.map { duty in
            let assignee = organization.employee(duty.assigneeID)?.name ?? duty.assigneeID
            let reviewer = organization.employee(duty.reviewerID)?.name ?? duty.reviewerID
            let latest = organization.latestOccurrence(for: duty.id)
            let briefPath = latest?.briefArtifactID.flatMap { id in
                organization.artifacts.first { $0.id == id }?.relativePath
            }
            let deliveryPath = latest?.deliveryArtifactID.flatMap { id in
                organization.artifacts.first { $0.id == id }?.relativePath
            }
            let blocker = latest?.blockingReason.map { "\n- Current blocker: \($0)" } ?? ""
            let status = latest?.status.rawValue ?? (duty.nextDueAt <= Date() ? "due" : "upcoming")
            let brief = briefPath.map { "[Open Iris's brief](\($0))" } ?? "No brief delivered"
            let delivery = deliveryPath.map { "[Open Mira's handoff](\($0))" } ?? "No handoff delivered"
            let coverage: String
            if let latest {
                coverage = "\(latest.includedInputs.count) included · \(latest.excludedInputs.count) excluded"
            } else {
                coverage = "No run captured yet"
            }
            return """
            ## \(duty.title)

            - Employee: \(assignee)
            - Reviewer: \(reviewer)
            - Recurrence: `\(duty.recurrence.rawValue)`
            - Status: `\(status)`
            - Next due: \(duty.nextDueAt.formatted(.iso8601))
            - Latest input coverage: \(coverage)\(blocker)

            **Responsibility:** \(duty.responsibility)

            \(brief) · \(delivery)
            """
        }.joined(separator: "\n\n")
        try "# Employee duties\n\nFeedback inbox: `feedback-inbox/`\n\n\(dutyHistory.isEmpty ? "No recurring duties yet." : dutyHistory)\n".write(
            to: dutiesFileURL,
            atomically: true,
            encoding: .utf8
        )

        let outcomeHistory = organization.employeeOutcomes
            .sorted { $0.createdAt > $1.createdAt }
            .map { outcome in
                let employee = organization.employee(outcome.assigneeID)?.name ?? outcome.assigneeID
                let skills = outcome.selectedSkillIDs.compactMap { organization.skill($0)?.name }
                let tickets = outcome.taskIDs.compactMap { taskID in
                    organization.task(taskID).map { "- [\($0.status == .done ? "x" : " ")] \($0.title) · `\($0.status.rawValue)`" }
                }.joined(separator: "\n")
                let artifacts = outcome.artifactIDs.compactMap { artifactID in
                    organization.artifacts.first { $0.id == artifactID }
                }.map { "[\($0.title)](\($0.relativePath))" }.joined(separator: " · ")
                let help = outcome.helpRequest.map { "\n- Help requested: \($0)" } ?? ""
                let delivery = outcome.deliverySummary.map { "\n\n**Delivery:** \($0)" } ?? ""
                return """
                ## \(outcome.outcome)

                - Employee: \(employee)
                - Status: `\(outcome.status.rawValue)`
                - Skills used: \(skills.isEmpty ? "Not selected yet" : skills.joined(separator: ", "))
                - Attempts: \(outcome.attemptCount)
                - Updated: \(outcome.updatedAt.formatted(.iso8601))\(help)

                ### Tickets

                \(tickets.isEmpty ? "No tickets created yet." : tickets)

                ### Artifacts

                \(artifacts.isEmpty ? "No artifacts delivered yet." : artifacts)\(delivery)
                """
            }
            .joined(separator: "\n\n")
        try "# Employee outcomes\n\n\(outcomeHistory.isEmpty ? "No employee outcomes yet." : outcomeHistory)\n".write(
            to: employeeOutcomesFileURL,
            atomically: true,
            encoding: .utf8
        )

        for employee in organization.employees where employee.kind == .ai {
            let home = employeeHomeURL(employeeID: employee.id)
            try fileManager.createDirectory(at: home, withIntermediateDirectories: true)

            let relationship = employee.assistantForHumanID.map { "\n- Paired with human: `\($0)`" } ?? ""
            try """
            # \(employee.name)

            - Employee ID: `\(employee.id)`
            - Role: \(employee.role)
            - Kind: AI\(relationship)

            This file is generated from `organization.json` so the employee remains inspectable outside the app.
            """.write(to: home.appendingPathComponent("IDENTITY.md"), atomically: true, encoding: .utf8)

            try """
            # Responsibilities

            \(employee.responsibility)

            ## Reports to

            \(employee.managerID ?? "No manager assigned")
            """.write(to: home.appendingPathComponent("RESPONSIBILITIES.md"), atomically: true, encoding: .utf8)

            let memories = organization.knowledge?.memoryEntries
                .filter { $0.employeeID == employee.id }
                .sorted { $0.createdAt < $1.createdAt } ?? []
            let memoryBody = memories.isEmpty
                ? "No durable memories yet."
                : memories.map { entry in
                    let source = entry.sourceArtifactID.map { " · source `\($0)`" } ?? ""
                    return "- Day \(entry.dayNumber) · \(entry.createdAt.formatted(.iso8601)) · by `\(entry.authorID)`\(source)\n  \(entry.summary)"
                }.joined(separator: "\n")
            try "# Memory\n\n\(memoryBody)\n".write(
                to: home.appendingPathComponent("MEMORY.md"),
                atomically: true,
                encoding: .utf8
            )

            let grants = employee.capabilityGrants.sorted()
            let grantBody = grants.isEmpty ? "No external capabilities granted." : grants.map { "- `\($0)`" }.joined(separator: "\n")
            try "# Capabilities\n\n\(grantBody)\n\nExternal writes are unavailable in this version.\n".write(
                to: home.appendingPathComponent("CAPABILITIES.md"),
                atomically: true,
                encoding: .utf8
            )

            let skills = organization.assignedSkills(employeeID: employee.id)
            let skillBody = skills.isEmpty
                ? "No skills assigned. This is an explicit coverage gap."
                : skills.map { skill in
                    "- **\(skill.name)** · v\(skill.version) · \(skill.source == .builtIn ? "Built in" : "Owner-taught guidance")\n  \(skill.purpose)"
                }.joined(separator: "\n")
            try "# Assigned skills\n\n\(skillBody)\n".write(
                to: home.appendingPathComponent("SKILLS.md"),
                atomically: true,
                encoding: .utf8
            )

            let artifacts = organization.artifacts
                .filter { $0.authorID == employee.id }
                .sorted { $0.createdAt < $1.createdAt }
            let artifactBody = artifacts.isEmpty
                ? "No artifacts yet."
                : artifacts.map { "- [\($0.title)](../../\($0.relativePath)) · \($0.kind.rawValue) · day \(organization.dayNumber)" }.joined(separator: "\n")
            try "# Artifacts\n\n\(artifactBody)\n".write(
                to: home.appendingPathComponent("ARTIFACTS.md"),
                atomically: true,
                encoding: .utf8
            )
        }
    }

    private nonisolated static func starterProductBrief(for organization: OrganizationState) -> String {
        """
        # Product brief

        ## Product
        Describe what \(organization.name) is building.

        ## Audience
        Describe who it is for.

        ## Problem
        Describe the painful problem it solves.

        ## Current outcome
        \(organization.outcome)

        ## Claims we can support
        List only claims the team may safely make.
        """
    }

    private nonisolated static func starterProfile(for organization: OrganizationState) -> OrganizationProfile {
        let brief = organization.productBrief
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return OrganizationProfile(
            purpose: organization.goals.first?.title ?? organization.outcome,
            product: brief.isEmpty ? "Describe what \(organization.name) is building." : brief,
            audience: "Describe who the organization serves.",
            stage: "Early stage",
            operatingPrinciples: "Stay grounded in supplied facts and bring the owner in when judgment is required.",
            constraints: "Respect the current local-only permissions and do not invent unsupported claims."
        )
    }

    private nonisolated static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }
}

private extension OrganizationProfile {
    var isEmpty: Bool {
        [purpose, product, audience, stage, operatingPrinciples, constraints]
            .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
