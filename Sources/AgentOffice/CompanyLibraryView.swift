import AgentOfficeCore
import SwiftUI

struct CompanyLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var section: LibrarySection = .employees
    @State private var selectedEmployeeID = "maya"
    @State private var selectedSkillID = "outcome-ownership"
    @State private var showsTeachSkill = false

    init(initialSection: LibrarySection = .employees) {
        _section = State(initialValue: initialSection)
    }

    private let ink = EditorialOfficeTheme.ink
    private let spruce = EditorialOfficeTheme.sidebarInk
    private let paper = EditorialOfficeTheme.paper
    private let plaster = EditorialOfficeTheme.bone
    private let apricot = EditorialOfficeTheme.graphite

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.45)
            Group {
                switch section {
                case .employees: employeeCatalogue
                case .skills: skillCatalogue
                case .connections: connectionCatalogue
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(ink)
        .tint(spruce)
        .background(plaster)
        .frame(minWidth: 820, minHeight: 620)
        .sheet(isPresented: $showsTeachSkill) {
            TeachSkillView()
                .environmentObject(model)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("The company library")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("Who is here, what the company knows, and which keys make the work possible.")
                        .font(.callout)
                        .foregroundStyle(ink.opacity(0.62))
                }
                Spacer()
                Button {
                    showsTeachSkill = true
                } label: {
                    Label("Teach a skill", systemImage: "book.pages.fill")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(EditorialOfficeTheme.paper)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 34)
                        .background(spruce, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(!model.canEditOrganization)
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(spruce)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 34)
                    .background(Color.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 9))
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 5) {
                ForEach(LibrarySection.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        Label(item.rawValue, systemImage: item.icon)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(section == item ? EditorialOfficeTheme.paper : ink.opacity(0.68))
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(section == item ? spruce : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(paper)
    }

    private var employeeCatalogue: some View {
        HStack(spacing: 0) {
            catalogueList {
                ForEach(model.organization.employees) { employee in
                    Button {
                        selectedEmployeeID = employee.id
                    } label: {
                        HStack(spacing: 11) {
                            EmployeePortrait(employee: employee, size: CGSize(width: 38, height: 46))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(employee.name).font(.callout.weight(.bold))
                                Text(employee.role)
                                    .font(.caption2)
                                    .foregroundStyle(ink.opacity(0.56))
                                Text("\(model.organization.assignedSkills(employeeID: employee.id).count) skills")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(spruce.opacity(0.72))
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(
                            selectedEmployeeID == employee.id ? Color.white.opacity(0.68) : .clear,
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().opacity(0.4)

            if let employee = model.organization.employee(selectedEmployeeID) ?? model.organization.employees.first {
                employeeDetail(employee)
            }
        }
    }

    private func employeeDetail(_ employee: Employee) -> some View {
        let skills = model.organization.assignedSkills(employeeID: employee.id)
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 18) {
                    EmployeePortrait(employee: employee, size: CGSize(width: 72, height: 86))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(employee.name)
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text(employee.role).font(.headline).foregroundStyle(spruce.opacity(0.78))
                        Text(employee.responsibility)
                            .font(.callout)
                            .foregroundStyle(ink.opacity(0.7))
                        if let managerID = employee.managerID {
                            Label("Reports to \(model.employeeName(managerID))", systemImage: "arrow.turn.up.right")
                                .font(.caption)
                                .foregroundStyle(ink.opacity(0.52))
                        }
                    }
                }

                librarySection("Skill coverage", icon: "books.vertical.fill") {
                    if skills.isEmpty {
                        coverageGap("No skills are assigned. The role name is not being treated as proof of capability.")
                    } else {
                        flowTags(skills.map { "\($0.name) · v\($0.version)" })
                    }
                }

                librarySection("Keys currently granted", icon: "key.fill") {
                    if employee.capabilityGrants.isEmpty {
                        Text("No external capabilities granted.")
                            .font(.callout)
                            .foregroundStyle(ink.opacity(0.56))
                    } else {
                        flowTags(employee.capabilityGrants)
                    }
                }

                if employee.kind == .ai {
                    Button {
                        model.revealEmployeeHome(employee.id)
                    } label: {
                        Label("Open \(employee.name)'s local home", systemImage: "folder.fill")
                    }
                    .buttonStyle(.plain)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(spruce)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Color.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 9))
                }
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var skillCatalogue: some View {
        let skills = (model.organization.knowledge?.skillDefinitions ?? [])
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return HStack(spacing: 0) {
            catalogueList {
                ForEach(skills) { skill in
                    Button {
                        selectedSkillID = skill.id
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(skill.name).font(.callout.weight(.bold))
                                Spacer()
                                Text("v\(skill.version)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(ink.opacity(0.42))
                            }
                            Text(skill.category)
                                .font(.caption2)
                                .foregroundStyle(ink.opacity(0.52))
                            Text("\(model.organization.employeesWithSkill(skill.id).count) employees")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(spruce.opacity(0.72))
                        }
                        .padding(11)
                        .background(
                            selectedSkillID == skill.id ? Color.white.opacity(0.68) : .clear,
                            in: RoundedRectangle(cornerRadius: 11)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider().opacity(0.4)

            if let skill = model.organization.skill(selectedSkillID) ?? skills.first {
                skillDetail(skill)
            } else {
                ContentUnavailableView("No skills yet", systemImage: "books.vertical", description: Text("Teach the first organizational skill to begin the catalogue."))
            }
        }
    }

    private func skillDetail(_ skill: SkillDefinition) -> some View {
        let assignees = model.organization.employeesWithSkill(skill.id)
        let availableEmployees = model.organization.employees.filter { employee in
            !assignees.contains(where: { $0.id == employee.id })
        }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(skill.name)
                            .font(.system(.title, design: .rounded, weight: .bold))
                        Text("\(skill.category) · version \(skill.version)")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(spruce.opacity(0.75))
                    }
                    Spacer()
                    Text(skill.source == .builtIn ? "Built in" : "Owner-taught guidance")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(skill.source == .builtIn ? spruce : EditorialOfficeTheme.graphite)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.62), in: Capsule())
                }

                librarySection("Purpose", icon: "scope") {
                    Text(skill.purpose).font(.callout).foregroundStyle(ink.opacity(0.74))
                }
                librarySection("Operating guidance", icon: "text.book.closed.fill") {
                    Text(skill.instructions).font(.callout).foregroundStyle(ink.opacity(0.74))
                }
                librarySection("A good result", icon: "checkmark.seal.fill") {
                    Text(skill.successCriteria).font(.callout).foregroundStyle(ink.opacity(0.74))
                }
                librarySection("Required connections", icon: "point.3.connected.trianglepath.dotted") {
                    if skill.requiredConnectionIDs.isEmpty {
                        Text("None").font(.callout).foregroundStyle(ink.opacity(0.56))
                    } else {
                        flowTags(skill.requiredConnectionIDs.map(connectionName))
                    }
                }
                librarySection("Employees with this skill", icon: "person.2.fill") {
                    if assignees.isEmpty {
                        coverageGap("Nobody covers this skill yet.")
                    } else {
                        flowTags(assignees.map(\.name))
                    }
                }

                if !availableEmployees.isEmpty {
                    Menu {
                        ForEach(availableEmployees) { employee in
                            Button("Teach to \(employee.name)") {
                                _ = model.assignSkill(skill.id, to: employee.id)
                            }
                        }
                    } label: {
                        Label("Teach to another employee", systemImage: "person.badge.plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var connectionCatalogue: some View {
        let connections = model.organization.knowledge?.connectionDefinitions ?? []
        return ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                ForEach(connections) { connection in
                    let grants = permittedEmployees(for: connection)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            Image(systemName: connection.kind == .execution ? "cpu" : "globe")
                                .font(.title2)
                                .foregroundStyle(apricot)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(connection.name).font(.headline)
                                Text(connection.kind == .execution ? "Execution" : "Tool access")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(ink.opacity(0.46))
                            }
                            Spacer()
                            Text(connectionStatus(connection))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(connectionAvailable(connection) ? ink : EditorialOfficeTheme.graphite)
                        }
                        Text(connection.summary)
                            .font(.callout)
                            .foregroundStyle(ink.opacity(0.68))
                        Divider().opacity(0.35)
                        if connection.capabilityID != nil {
                            Text(grants.isEmpty ? "No employee currently has this key." : "Granted to \(grants.map(\.name).joined(separator: ", ")).")
                                .font(.caption)
                                .foregroundStyle(ink.opacity(0.58))
                        } else {
                            Text("Organization-wide execution option. No credential is stored here.")
                                .font(.caption)
                                .foregroundStyle(ink.opacity(0.58))
                        }
                    }
                    .padding(17)
                    .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
                    .background(paper, in: RoundedRectangle(cornerRadius: 15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15).stroke(DawnStageTheme.hairline)
                    }
                }
            }
            .padding(24)
        }
    }

    private func catalogueList<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 7, content: content)
                .padding(14)
        }
        .frame(width: 260)
        .background(EditorialOfficeTheme.softGrey.opacity(0.48))
    }

    private func librarySection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.callout.weight(.bold))
                .foregroundStyle(spruce)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func coverageGap(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(EditorialOfficeTheme.ink)
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EditorialOfficeTheme.softGrey, in: RoundedRectangle(cornerRadius: 10))
    }

    private func flowTags(_ values: [String]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(values, id: \.self) { value in
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(spruce)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.7), in: Capsule())
            }
        }
    }

    private func connectionName(_ id: String) -> String {
        model.organization.knowledge?.connectionDefinitions.first { $0.id == id }?.name ?? id
    }

    private func permittedEmployees(for connection: ConnectionDefinition) -> [Employee] {
        guard let capability = connection.capabilityID else { return [] }
        return model.organization.employees.filter { $0.capabilityGrants.contains(capability) }
    }

    private func connectionAvailable(_ connection: ConnectionDefinition) -> Bool {
        switch connection.id {
        case "demo-runner": true
        case "local-codex": model.codexAvailable
        case "web-research": model.codexAvailable && !permittedEmployees(for: connection).isEmpty
        default: false
        }
    }

    private func connectionStatus(_ connection: ConnectionDefinition) -> String {
        switch connection.id {
        case "demo-runner": "Available"
        case "local-codex": model.codexAvailable ? "Available" : "Unavailable"
        case "web-research":
            if !model.codexAvailable { "Runtime unavailable" }
            else if permittedEmployees(for: connection).isEmpty { "Permission required" }
            else { "Available" }
        default: "Not configured"
        }
    }
}

enum LibrarySection: String, CaseIterable, Identifiable {
    case employees = "Employees"
    case skills = "Skills"
    case connections = "Connections"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .employees: "person.3.fill"
        case .skills: "books.vertical.fill"
        case .connections: "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct TeachSkillView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Organization"
    @State private var purpose = ""
    @State private var instructions = ""
    @State private var successCriteria = ""
    @State private var employeeID = "maya"
    @State private var connectionID = "none"

    private let ink = DawnStageTheme.ivory
    private let spruce = DawnStageTheme.coral
    private let paper = DawnStageTheme.backstage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Teach an organizational skill")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("This stores operating guidance for future work. It does not fine-tune or certify the employee's model.")
                    .font(.callout)
                    .foregroundStyle(ink.opacity(0.64))
            }

            HStack(spacing: 14) {
                field("Skill name") { TextField("e.g. Interview synthesis", text: $name) }
                field("Category") { TextField("e.g. Research", text: $category) }
            }

            field("Purpose") {
                TextField("What should this skill help the employee accomplish?", text: $purpose, axis: .vertical)
                    .lineLimit(2...4)
            }
            field("Operating instructions") {
                TextField("Give concrete steps, constraints, and judgment rules.", text: $instructions, axis: .vertical)
                    .lineLimit(4...7)
            }
            field("A good result") {
                TextField("How will you recognize that the skill was used well?", text: $successCriteria, axis: .vertical)
                    .lineLimit(2...4)
            }

            HStack(spacing: 14) {
                field("Teach to") {
                    Picker("Teach to", selection: $employeeID) {
                        ForEach(model.organization.employees.filter { $0.kind == .ai }) { employee in
                            Text("\(employee.name) · \(employee.role)").tag(employee.id)
                        }
                    }
                    .labelsHidden()
                }
                field("Required connection") {
                    Picker("Required connection", selection: $connectionID) {
                        Text("None").tag("none")
                        ForEach(model.organization.knowledge?.connectionDefinitions ?? []) { connection in
                            Text(connection.name).tag(connection.id)
                        }
                    }
                    .labelsHidden()
                }
            }

            Divider().opacity(0.4)

            HStack {
                Text(formIsValid ? "The guidance will be available on the employee's next task." : "Complete every teaching field to continue.")
                    .font(.caption)
                    .foregroundStyle(formIsValid ? EditorialOfficeTheme.ink : EditorialOfficeTheme.graphite)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(spruce)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                    .keyboardShortcut(.cancelAction)
                Button("Teach skill") {
                    if model.teachSkill(
                        name: name,
                        category: category,
                        purpose: purpose,
                        instructions: instructions,
                        successCriteria: successCriteria,
                        requiredConnectionID: connectionID == "none" ? nil : connectionID,
                        employeeID: employeeID
                    ) {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(spruce)
                .disabled(!formIsValid)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(minWidth: 680, minHeight: 650)
        .background(paper)
        .foregroundStyle(ink)
        .tint(spruce)
        .environment(\.colorScheme, .dark)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(spruce.opacity(0.74))
            content()
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formIsValid: Bool {
        [name, purpose, instructions, successCriteria]
            .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && model.organization.employee(employeeID) != nil
    }
}
