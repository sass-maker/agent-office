import AgentOfficeCore
import SwiftUI

struct CompanyLibraryView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var section: LibrarySection = .employees
  @State private var selectedEmployeeID = "maya"
  @State private var selectedPackageVersionedID: String?
  @State private var selectedSkillID = "outcome-ownership"
  @State private var showsTeachSkill = false
  @State private var editingContractEmployee: Employee?
  @State private var pendingRetirementEmployee: Employee?

  init(initialSection: LibrarySection = .employees) {
    _section = State(initialValue: initialSection)
  }

  private let ink = EditorialOfficeTheme.ink
  private let spruce = EditorialOfficeTheme.controlInk
  private let paper = EditorialOfficeTheme.paper
  private let plaster = EditorialOfficeTheme.bone
  private let apricot = EditorialOfficeTheme.graphite

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.width < 800

      VStack(spacing: 0) {
        header(compact: compact)
        Divider().opacity(0.45)
        Group {
          switch section {
          case .employees: employeeCatalogue(compact: compact)
          case .skills: skillCatalogue
          case .connections: connectionCatalogue
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .foregroundStyle(ink)
      .tint(spruce)
      .background(plaster)
    }
    .frame(minWidth: 600, idealWidth: 900, minHeight: 540, idealHeight: 700)
    .sheet(isPresented: $showsTeachSkill) {
      TeachSkillView()
        .environmentObject(model)
    }
    .sheet(item: $editingContractEmployee) { employee in
      if let contract = model.organization.workingContract(for: employee.id) {
        WorkingContractEditor(employee: employee, contract: contract)
          .environmentObject(model)
      }
    }
    .confirmationDialog(
      "Retire this employee?",
      isPresented: Binding(
        get: { pendingRetirementEmployee != nil },
        set: { if !$0 { pendingRetirementEmployee = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Retire employee", role: .destructive) {
        if let employee = pendingRetirementEmployee { model.retireEmployee(employee.id) }
        pendingRetirementEmployee = nil
      }
      Button("Keep employed", role: .cancel) { pendingRetirementEmployee = nil }
    } message: {
      Text(
        "Retirement removes the employee from active work but preserves their identity, contracts, outcomes, artifacts, and history."
      )
    }
  }

  private func header(compact: Bool) -> some View {
    VStack(spacing: 14) {
      if compact {
        HStack(alignment: .top, spacing: 12) {
          headerTitle
          Spacer(minLength: 8)
          VStack(alignment: .trailing, spacing: 8) {
            if section == .skills { teachButton }
            doneButton
          }
          .fixedSize()
        }
      } else {
        HStack(alignment: .top, spacing: 16) {
          headerTitle
          Spacer()
          if section == .skills { teachButton }
          doneButton
        }
      }

      HStack(spacing: 5) {
        ForEach(LibrarySection.allCases) { item in
          Button {
            section = item
          } label: {
            Group {
              if compact {
                Text(item.rawValue)
              } else {
                Label(item.rawValue, systemImage: item.icon)
              }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(section == item ? EditorialOfficeTheme.onInk : ink.opacity(0.68))
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(
              section == item ? EditorialOfficeTheme.sidebarInk : Color.clear,
              in: RoundedRectangle(cornerRadius: 8))
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(section == item ? .isSelected : [])
        }
      }
      .padding(4)
      .background(
        EditorialOfficeTheme.softGrey.opacity(0.28), in: RoundedRectangle(cornerRadius: 11))
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 20)
    .background(paper)
  }

  private var headerTitle: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("The company library")
        .font(.system(.title2, design: .rounded, weight: .bold))
      Text("Who is here, what the company knows, and which keys make the work possible.")
        .font(.callout)
        .foregroundStyle(ink.opacity(0.62))
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .layoutPriority(1)
  }

  private var teachButton: some View {
    Button {
      showsTeachSkill = true
    } label: {
      Label("Teach a skill", systemImage: "book.pages.fill")
        .font(.callout.weight(.bold))
        .foregroundStyle(EditorialOfficeTheme.onInk)
        .padding(.horizontal, 13)
        .frame(minHeight: 34)
        .background(EditorialOfficeTheme.sidebarInk, in: RoundedRectangle(cornerRadius: 9))
    }
    .buttonStyle(.plain)
    .disabled(!model.canEditOrganization)
  }

  private var doneButton: some View {
    Button("Done") { dismiss() }
      .buttonStyle(.plain)
      .font(.callout.weight(.semibold))
      .foregroundStyle(spruce)
      .padding(.horizontal, 10)
      .frame(minHeight: 34)
      .background(
        EditorialOfficeTheme.softGrey.opacity(0.44), in: RoundedRectangle(cornerRadius: 9)
      )
      .keyboardShortcut(.cancelAction)
  }

  @ViewBuilder
  private func employeeCatalogue(compact: Bool) -> some View {
    let layout = compact ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
    layout {
      catalogueList(width: compact ? nil : 280) {
        catalogueHeading("Employee packages")
        ForEach(model.organization.employeePackages) { package in
          Button {
            selectedPackageVersionedID = package.versionedID
          } label: {
            VStack(alignment: .leading, spacing: 3) {
              HStack {
                Text(package.name).font(.callout.weight(.bold))
                Spacer()
                Text(package.version).font(.caption2.monospacedDigit())
              }
              Text(package.role).font(.caption2).foregroundStyle(ink.opacity(0.56))
              Text(
                "\(package.skills.count) skills · \(package.requiredConnectionIDs.count) connections"
              )
              .font(.caption2.weight(.semibold)).foregroundStyle(spruce.opacity(0.72))
            }
            .padding(10)
            .background(
              selectedPackageVersionedID == package.versionedID ? paper.opacity(0.82) : .clear,
              in: RoundedRectangle(cornerRadius: 11))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(
            "Installed employee package \(package.name), \(package.role), version \(package.version)"
          )
          .accessibilityAddTraits(
            selectedPackageVersionedID == package.versionedID ? .isSelected : [])
        }

        catalogueHeading("Employed")
        employedEmployeesSection()

        if model.organization.employees.contains(where: { $0.effectiveEmploymentState == .retired })
        {
          catalogueHeading("History")
          retiredEmployeesSection()
        }

        Button(action: model.importEmployeePackage) {
          Label("Import package", systemImage: "square.and.arrow.down")
            .font(.callout.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(EditorialSecondaryButtonStyle())
        .padding(.top, 8)
      }
      .frame(height: compact ? 245 : nil)

      Divider().opacity(0.4)

      if let versionedID = selectedPackageVersionedID,
        let package = model.organization.employeePackages.first(where: {
          $0.versionedID == versionedID
        })
      {
        candidateDetail(package)
      } else if let employee = model.organization.employee(selectedEmployeeID)
        ?? model.organization.employees.first
      {
        employeeDetail(employee)
      }
    }
  }

  private func employedEmployeesSection() -> some View {
    ForEach(
      model.organization.employees.filter {
        $0.kind == .human || [.hired, .paused].contains($0.effectiveEmploymentState)
      }
    ) { employee in
      Button {
        selectedEmployeeID = employee.id
        selectedPackageVersionedID = nil
      } label: {
        HStack(spacing: 11) {
          EmployeePortrait(employee: employee, size: CGSize(width: 38, height: 46))
          VStack(alignment: .leading, spacing: 2) {
            Text(employee.name).font(.callout.weight(.bold))
            Text(employee.role)
              .font(.caption2)
              .foregroundStyle(ink.opacity(0.56))
            Text(
              employee.kind == .human
                ? "Organization member"
                : "\(employee.effectiveEmploymentState.rawValue.capitalized) · \(model.organization.assignedSkills(employeeID: employee.id).count) skills"
            )
            .font(.caption2.weight(.semibold))
            .foregroundStyle(spruce.opacity(0.72))
          }
          Spacer()
        }
        .padding(10)
        .background(
          selectedEmployeeID == employee.id ? paper.opacity(0.82) : .clear,
          in: RoundedRectangle(cornerRadius: 11)
        )
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(selectedEmployeeID == employee.id ? .isSelected : [])
    }
  }

  private func retiredEmployeesSection() -> some View {
    ForEach(model.organization.employees.filter { $0.effectiveEmploymentState == .retired }) {
      employee in
      Button {
        selectedEmployeeID = employee.id
        selectedPackageVersionedID = nil
      } label: {
        HStack {
          EmployeePortrait(employee: employee, size: CGSize(width: 34, height: 40))
            .saturation(0)
          VStack(alignment: .leading) {
            Text(employee.name).font(.callout.weight(.bold))
            Text("Retired · history preserved").font(.caption2).foregroundStyle(
              ink.opacity(0.56))
          }
          Spacer()
        }.padding(10)
      }.buttonStyle(.plain)
    }
  }

  private func catalogueHeading(_ title: String) -> some View {
    Text(title)
      .font(.caption.weight(.bold))
      .foregroundStyle(ink.opacity(0.5))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 4)
      .padding(.top, 8)
  }

  private func candidateDetail(_ package: EmployeePackage) -> some View {
    let isEmployed = model.organization.employees.contains {
      $0.packageID == package.id
        && $0.packageVersion == package.version
        && [.hired, .paused].contains($0.effectiveEmploymentState)
    }
    return ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text(package.name).font(.system(.title, design: .rounded, weight: .bold))
            Text(package.role).font(.headline).foregroundStyle(spruce.opacity(0.78))
            Text("Package \(package.version) · by \(package.creator)").font(.caption)
              .foregroundStyle(ink.opacity(0.56))
          }
          Spacer()
          Text("INSTALLED PACKAGE").font(.caption2.weight(.bold)).padding(.horizontal, 9).padding(
            .vertical, 5
          ).background(paper.opacity(0.78), in: Capsule())
        }
        Text(package.responsibility).font(.callout).foregroundStyle(ink.opacity(0.72))
        librarySection("What they bring", icon: "shippingbox.fill") {
          flowTags(package.skills.map { "\($0.name) · v\($0.version)" })
        }
        librarySection(
          "What the organization provides", icon: "point.3.connected.trianglepath.dotted"
        ) {
          Text(
            package.requiredConnectionIDs.isEmpty
              ? "No connection required." : package.requiredConnectionIDs.joined(separator: ", ")
          ).font(.callout)
        }
        librarySection("Execution and boundaries", icon: "cpu") {
          Text(
            "\(package.preferredProvider.rawValue) · local organization sandbox · publishing \(package.boundaries.mayPublish ? "allowed" : "unavailable") · up to \(package.boundaries.maximumRevisions) revisions"
          )
          .font(.callout).foregroundStyle(ink.opacity(0.72))
        }
        librarySection("How they work", icon: "dial.medium") {
          VStack(alignment: .leading, spacing: 8) {
            Text(
              package.requiredConnectionIDs.isEmpty
                ? "Normally: from local company context alone."
                : "Normally: with \(package.requiredConnectionIDs.joined(separator: ", ")), which hiring does not grant."
            )
            .font(.callout).foregroundStyle(ink.opacity(0.72))
            if let reduced = package.reducedModeDescription {
              Text("Reduced: \(reduced)").font(.callout).foregroundStyle(ink.opacity(0.72))
            }
          }
        }
        if let boundary = package.externalActionBoundary {
          librarySection("What stays with you", icon: "hand.raised.fill") {
            Text(boundary).font(.callout).foregroundStyle(ink.opacity(0.72))
          }
        }
        Button(isEmployed ? "Already employed" : "Hire \(package.name)") {
          if model.hireEmployee(packageID: package.id, version: package.version) {
            selectedEmployeeID = model.selectedEmployeeID ?? selectedEmployeeID
            selectedPackageVersionedID = nil
          }
        }
        .buttonStyle(EditorialPrimaryButtonStyle())
        .disabled(isEmployed)
        .accessibilityHint(
          "Creates a durable employee identity and working contract without granting connections")
      }
      .padding(26).frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private func employeeDetail(_ employee: Employee) -> some View {
    let skills = model.organization.assignedSkills(employeeID: employee.id)
    let requiredConnections = Array(Set(skills.flatMap(\.requiredConnectionIDs)))
      .sorted()
      .map(connectionName)
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
              Label(
                "Reports to \(model.employeeName(managerID))", systemImage: "arrow.turn.up.right"
              )
              .font(.caption)
              .foregroundStyle(ink.opacity(0.52))
            }
          }
        }

        librarySection("Skill coverage", icon: "books.vertical.fill") {
          if skills.isEmpty {
            coverageGap(
              "No skills are assigned. The role name is not being treated as proof of capability.")
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

        librarySection("Required connections", icon: "point.3.connected.trianglepath.dotted") {
          if requiredConnections.isEmpty {
            Text("No assigned skill requires a connection.")
              .font(.callout)
              .foregroundStyle(ink.opacity(0.56))
          } else {
            flowTags(requiredConnections)
          }
        }

        if let contract = model.organization.workingContract(for: employee.id) {
          contractActionsSection(for: employee, contract: contract)
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
          .background(paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 9))
        }
      }
      .padding(26)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  @ViewBuilder
  private func contractActionsSection(for employee: Employee, contract: WorkingContract)
    -> some View
  {
    librarySection(
      "Working contract · revision \(contract.revision)", icon: "doc.text.magnifyingglass"
    ) {
      VStack(alignment: .leading, spacing: 8) {
        contractLine("Employment", employee.effectiveEmploymentState.rawValue.capitalized)
        contractLine("Identity", "\(employee.name) · \(contract.role)")
        contractLine(
          "Skills", contract.assignedSkillIDs.map(skillName).joined(separator: ", "))
        contractLine(
          "Declared tools",
          contract.declaredConnectionIDs.isEmpty
            ? "None"
            : contract.declaredConnectionIDs.map(connectionName).joined(separator: ", "))
        contractLine(
          "Granted authority",
          contract.capabilityGrants.isEmpty
            ? "None" : contract.capabilityGrants.map(capabilityName).joined(separator: ", "))
        contractLine(
          "Execution",
          "\(executionProviderName(contract.executionProvider)) · \(contract.modelName ?? "provider default")"
        )
        contractLine("Environment", "Local organization sandbox · \(contract.workspacePath)")
        contractLine("Review", reviewPolicyName(contract.reviewPolicy))
        Button("Edit working contract") { editingContractEmployee = employee }
          .buttonStyle(EditorialSecondaryButtonStyle())
          .disabled(model.runningEmployeeIDs.contains(employee.id))
          .padding(.top, 6)
      }
    }
    if employee.effectiveEmploymentState == .hired {
      HStack {
        Button("Pause") { model.pauseEmployee(employee.id) }.buttonStyle(
          EditorialSecondaryButtonStyle())
        Button("Retire") { pendingRetirementEmployee = employee }.buttonStyle(
          EditorialSecondaryButtonStyle()
        ).disabled(model.runningEmployeeIDs.contains(employee.id))
      }
    } else if employee.effectiveEmploymentState == .paused {
      HStack {
        Button("Resume") { model.resumeEmployee(employee.id) }.buttonStyle(
          EditorialPrimaryButtonStyle())
        Button("Retire") { pendingRetirementEmployee = employee }.buttonStyle(
          EditorialSecondaryButtonStyle())
      }
    }
  }

  private func contractLine(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(label).font(.caption.weight(.semibold)).foregroundStyle(ink.opacity(0.55)).frame(
        width: 112, alignment: .leading)
      Text(value.isEmpty ? "None" : value).font(.callout).textSelection(.enabled)
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
              selectedSkillID == skill.id ? paper.opacity(0.82) : .clear,
              in: RoundedRectangle(cornerRadius: 11)
            )
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(selectedSkillID == skill.id ? .isSelected : [])
        }
      }

      Divider().opacity(0.4)

      if let skill = model.organization.skill(selectedSkillID) ?? skills.first {
        skillDetail(skill)
      } else {
        ContentUnavailableView(
          "No skills yet", systemImage: "books.vertical",
          description: Text("Teach the first organizational skill to begin the catalogue."))
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
            .background(paper.opacity(0.76), in: Capsule())
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
                .foregroundStyle(
                  connectionAvailable(connection) ? ink : EditorialOfficeTheme.graphite)
            }
            Text(connection.summary)
              .font(.callout)
              .foregroundStyle(ink.opacity(0.68))
            Divider().opacity(0.35)
            if connection.capabilityID != nil {
              Text(
                grants.isEmpty
                  ? "No employee currently has this key."
                  : "Granted to \(grants.map(\.name).joined(separator: ", "))."
              )
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
            RoundedRectangle(cornerRadius: 15).stroke(EditorialOfficeTheme.rule)
          }
        }
      }
      .padding(24)
    }
  }

  private func catalogueList<Content: View>(
    width: CGFloat? = 260, @ViewBuilder content: () -> Content
  ) -> some View {
    ScrollView {
      LazyVStack(spacing: 7, content: content)
        .padding(14)
    }
    .frame(width: width)
    .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    .background(EditorialOfficeTheme.softGrey.opacity(0.48))
  }

  private func librarySection<Content: View>(
    _ title: String, icon: String, @ViewBuilder content: () -> Content
  ) -> some View {
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
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading,
      spacing: 8
    ) {
      ForEach(values, id: \.self) { value in
        Text(value)
          .font(.caption.weight(.semibold))
          .foregroundStyle(spruce)
          .padding(.horizontal, 9)
          .padding(.vertical, 6)
          .background(paper.opacity(0.82), in: Capsule())
      }
    }
  }

  private func connectionName(_ id: String) -> String {
    model.organization.knowledge?.connectionDefinitions.first { $0.id == id }?.name ?? id
  }

  private func skillName(_ id: String) -> String {
    model.organization.skill(id)?.name ?? id
  }

  private func capabilityName(_ id: String) -> String {
    model.organization.knowledge?.connectionDefinitions.first { $0.capabilityID == id }?.name ?? id
  }

  private func executionProviderName(_ provider: EmployeeExecutionProvider) -> String {
    provider.displayName
  }

  private func reviewPolicyName(_ policy: PlanReviewPolicy) -> String {
    switch policy {
    case .always: "Review every plan"
    case .whenAuthorityChanges: "Review authority changes"
    case .automaticForLocalWork: "Approve bounded local plans"
    }
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
      if !model.codexAvailable {
        "Runtime unavailable"
      } else if permittedEmployees(for: connection).isEmpty {
        "Permission required"
      } else {
        "Available"
      }
    default: "Not configured"
    }
  }
}

private struct WorkingContractEditor: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  let employee: Employee
  let contract: WorkingContract
  @State private var role: String
  @State private var responsibility: String
  @State private var managerID: String
  @State private var selectedSkillIDs: Set<String>
  @State private var selectedConnectionIDs: Set<String>
  @State private var selectedGrantIDs: Set<String>
  @State private var provider: EmployeeExecutionProvider
  @State private var modelName: String
  @State private var reviewPolicy: PlanReviewPolicy
  @State private var mayDelegate: Bool
  @State private var mayUseExternalTools: Bool
  @State private var maximumRevisions: Int
  @State private var reason = ""

  init(employee: Employee, contract: WorkingContract) {
    self.employee = employee
    self.contract = contract
    _role = State(initialValue: contract.role)
    _responsibility = State(initialValue: contract.responsibility)
    _managerID = State(initialValue: contract.managerID ?? "")
    _selectedSkillIDs = State(initialValue: Set(contract.assignedSkillIDs))
    _selectedConnectionIDs = State(initialValue: Set(contract.declaredConnectionIDs))
    _selectedGrantIDs = State(initialValue: Set(contract.capabilityGrants))
    _provider = State(initialValue: contract.executionProvider)
    _modelName = State(initialValue: contract.modelName ?? "")
    _reviewPolicy = State(initialValue: contract.reviewPolicy)
    _mayDelegate = State(initialValue: contract.boundaries.mayDelegate)
    _mayUseExternalTools = State(initialValue: contract.boundaries.mayUseExternalTools)
    _maximumRevisions = State(initialValue: contract.boundaries.maximumRevisions)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Edit \(employee.name)'s working contract").font(.system(.title2, design: .serif))
        Spacer()
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
      }
      .padding(22).background(EditorialOfficeTheme.paper)
      Divider()
      Form {
        Section("Identity and responsibility") {
          TextField("Role", text: $role)
          TextField("Responsibility", text: $responsibility, axis: .vertical).lineLimit(2...4)
          Picker("Reports to", selection: $managerID) {
            Text("No manager").tag("")
            ForEach(
              model.organization.employees.filter {
                $0.id != employee.id && $0.effectiveEmploymentState != .retired
              }
            ) { manager in
              Text("\(manager.name) · \(manager.role)").tag(manager.id)
            }
          }
        }
        Section("Assigned skills") {
          ForEach(model.organization.knowledge?.skillDefinitions ?? []) { skill in
            Toggle(isOn: membershipBinding(skill.id, in: $selectedSkillIDs)) {
              VStack(alignment: .leading, spacing: 2) {
                Text(skill.name)
                Text(skill.purpose).font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
              }
            }
          }
        }
        Section("Declared tools") {
          ForEach(model.organization.knowledge?.connectionDefinitions ?? []) { connection in
            Toggle(isOn: connectionBinding(connection)) {
              VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                Text(connection.summary).font(.caption).foregroundStyle(
                  EditorialOfficeTheme.graphite)
              }
            }
          }
          Text(
            "Declaring a tool says the employee may be configured to use it. It grants no authority by itself."
          )
          .font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
        }
        Section("Granted authority") {
          ForEach(
            (model.organization.knowledge?.connectionDefinitions ?? []).filter {
              $0.capabilityID != nil
            }
          ) { connection in
            if let capabilityID = connection.capabilityID {
              Toggle(
                "Allow \(connection.name)",
                isOn: grantBinding(capabilityID, connectionID: connection.id))
            }
          }
          Text("Only explicit grants may be used. Credentials remain outside this contract.")
            .font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
        }
        Section("Execution") {
          // Agent and model are separate choices: which software does the work,
          // and which model that software runs. Leaving either on Auto is a
          // real answer, not an absent one.
          Picker("Agent", selection: $provider) {
            ForEach(EmployeeExecutionProvider.agentChoices, id: \.self) { choice in
              Text(agentOptionLabel(choice))
                .tag(choice)
                .disabled(!model.agentAvailable(choice))
            }
          }
          if let reason = model.agentUnavailableReason(provider) {
            VStack(alignment: .leading, spacing: 6) {
              Text(reason)
                .font(.caption.weight(.semibold))
                .foregroundStyle(EditorialOfficeTheme.attention)
              // Installing a CLI while the app is open should not require a
              // relaunch to be noticed.
              Button("Check again") { model.recheckAgentInstallations() }
                .font(.caption)
            }
          }
          Picker("Model", selection: $modelName) {
            Text("Auto — the runtime's own default").tag("")
            ForEach(offeredModelNames, id: \.self) { Text($0).tag($0) }
          }
          .disabled(offeredModelNames.isEmpty)
          if offeredModelNames.isEmpty {
            Text(modelPickerExplanation)
              .font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
          }
          Picker("Plan review", selection: $reviewPolicy) {
            ForEach(PlanReviewPolicy.allCases, id: \.self) { Text(reviewPolicyLabel($0)).tag($0) }
          }
        }
        .onChange(of: provider) { _, _ in
          // A model name only means something against a named runtime, so
          // changing the agent drops an override the new agent may not support.
          if offeredModelNames.isEmpty || !offeredModelNames.contains(modelName) {
            modelName = ""
          }
        }
        Section("Autonomy boundaries") {
          Toggle("May delegate covered tickets", isOn: $mayDelegate)
          Toggle("May use explicitly granted external tools", isOn: $mayUseExternalTools)
          Stepper("Maximum revisions: \(maximumRevisions)", value: $maximumRevisions, in: 0...4)
          Text("Publishing remains unavailable in this local POC.").font(.caption).foregroundStyle(
            EditorialOfficeTheme.graphite)
        }
        Section("Review and attribution") {
          Text(
            "Saving creates contract revision \(contract.revision + 1). Previous revisions and employee work remain attributable."
          )
          .font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
          if !removedProtectedSkillNames.isEmpty {
            Text(
              "Keep \(removedProtectedSkillNames.joined(separator: ", ")) until the employee's open commitments are accepted or stopped."
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(EditorialOfficeTheme.attention)
          }
          TextField("Reason for this contract change", text: $reason)
        }
      }
      .formStyle(.grouped)
      Divider()
      HStack {
        Spacer()
        Button("Save revision") { save() }.buttonStyle(EditorialPrimaryButtonStyle())
          .keyboardShortcut(.defaultAction).disabled(
            role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || responsibility.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              || !removedProtectedSkillNames.isEmpty)
      }
      .padding(18).background(EditorialOfficeTheme.paper)
    }
    .frame(minWidth: 540, idealWidth: 680, minHeight: 520, idealHeight: 650)
  }

  private func membershipBinding(_ id: String, in selection: Binding<Set<String>>) -> Binding<Bool>
  {
    Binding(
      get: { selection.wrappedValue.contains(id) },
      set: { isSelected in
        if isSelected {
          selection.wrappedValue.insert(id)
        } else {
          selection.wrappedValue.remove(id)
        }
      }
    )
  }

  private func connectionBinding(_ connection: ConnectionDefinition) -> Binding<Bool> {
    Binding(
      get: { selectedConnectionIDs.contains(connection.id) },
      set: { isSelected in
        if isSelected {
          selectedConnectionIDs.insert(connection.id)
        } else {
          selectedConnectionIDs.remove(connection.id)
          if let capabilityID = connection.capabilityID { selectedGrantIDs.remove(capabilityID) }
        }
      }
    )
  }

  private func grantBinding(_ capabilityID: String, connectionID: String) -> Binding<Bool> {
    Binding(
      get: { selectedGrantIDs.contains(capabilityID) },
      set: { isSelected in
        if isSelected {
          selectedConnectionIDs.insert(connectionID)
          selectedGrantIDs.insert(capabilityID)
        } else {
          selectedGrantIDs.remove(capabilityID)
        }
      }
    )
  }

  /// Names the agent and, when it cannot be used, says so in the option itself
  /// so an unavailable runtime stays visible rather than disappearing.
  private func agentOptionLabel(_ value: EmployeeExecutionProvider) -> String {
    model.agentAvailable(value) ? value.displayName : "\(value.displayName) — unavailable"
  }

  /// Models the selected agent actually supports.
  ///
  /// Empty for Auto and Practice mode: an explicit model cannot be promised
  /// before the runtime that would honour it is known.
  private var offeredModelNames: [String] {
    guard let kind = provider.explicitDriverKind else { return [] }
    return RuntimeModelCatalog.offeredModels(for: kind)
  }

  private var modelPickerExplanation: String {
    switch provider {
    case .auto:
      "Auto picks the runtime at run time, so the model is left to whichever runtime it chooses."
    case .demo:
      "Practice mode runs no model. Its output is a rehearsal, not real work."
    default:
      "This runtime does not offer a model choice."
    }
  }

  private func reviewPolicyLabel(_ value: PlanReviewPolicy) -> String {
    switch value {
    case .always: "Review every plan"
    case .whenAuthorityChanges: "Review authority changes"
    case .automaticForLocalWork: "Approve bounded local plans"
    }
  }

  private var removedProtectedSkillNames: [String] {
    let protectedSkillIDs = Set(
      model.organization.employeeOutcomes
        .filter { $0.assigneeID == employee.id && !$0.status.isTerminal }
        .flatMap(\.taskIDs)
        .compactMap { model.organization.task($0) }
        .flatMap { $0.requiredSkillIDs ?? [] })
    return
      protectedSkillIDs
      .subtracting(selectedSkillIDs)
      .map { model.organization.skill($0)?.name ?? $0 }
      .sorted()
  }

  private func save() {
    guard removedProtectedSkillNames.isEmpty else { return }
    var boundaries = contract.boundaries
    boundaries.mayDelegate = mayDelegate
    boundaries.mayUseExternalTools = mayUseExternalTools
    boundaries.mayPublish = false
    boundaries.maximumRevisions = maximumRevisions
    let connections = model.organization.knowledge?.connectionDefinitions ?? []
    let knownCapabilities = Set(connections.compactMap(\.capabilityID))
    let declaredCapabilities = Set(
      connections.filter { selectedConnectionIDs.contains($0.id) }.compactMap(\.capabilityID))
    let validGrants = selectedGrantIDs.filter {
      !knownCapabilities.contains($0) || declaredCapabilities.contains($0)
    }
    // The revision starts from the contract on screen and carries only the
    // fields this editor owns, so it travels the journalled boundary as one
    // owner intent rather than as a wide set of loose arguments.
    var revision = WorkingContractRevision(revising: contract, reason: reason)
    revision.role = role
    revision.responsibility = responsibility
    revision.managerID = managerID.isEmpty ? nil : managerID
    revision.assignedSkillIDs = selectedSkillIDs.sorted()
    revision.declaredConnectionIDs = selectedConnectionIDs.sorted()
    revision.capabilityGrants = validGrants.sorted()
    revision.executionProvider = provider
    revision.modelName = modelName
    revision.boundaries = boundaries
    revision.reviewPolicy = reviewPolicy
    model.reviseWorkingContract(revision)
    dismiss()
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

  private let ink = EditorialOfficeTheme.ink
  private let spruce = EditorialOfficeTheme.controlInk
  private let paper = EditorialOfficeTheme.paper

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Teach an organizational skill")
            .font(.system(.title2, design: .serif, weight: .semibold))
          Text(
            "This stores operating guidance for future work. It does not fine-tune or certify the employee's model."
          )
          .font(.callout)
          .foregroundStyle(ink.opacity(0.64))
        }

        HStack(spacing: 14) {
          field("Skill name") { TextField("e.g. Interview synthesis", text: $name) }
          field("Category") { TextField("e.g. Research", text: $category) }
        }

        field("Purpose") {
          TextField(
            "What should this skill help the employee accomplish?", text: $purpose, axis: .vertical
          )
          .lineLimit(2...4)
        }
        field("Operating instructions") {
          TextField(
            "Give concrete steps, constraints, and judgment rules.", text: $instructions,
            axis: .vertical
          )
          .lineLimit(4...7)
        }
        field("A good result") {
          TextField(
            "How will you recognize that the skill was used well?", text: $successCriteria,
            axis: .vertical
          )
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
          Text(
            formIsValid
              ? "The guidance will be available on the employee's next task."
              : "Complete every teaching field to continue."
          )
          .font(.caption)
          .foregroundStyle(formIsValid ? EditorialOfficeTheme.ink : EditorialOfficeTheme.graphite)
          Spacer()
          Button("Cancel") { dismiss() }
            .buttonStyle(.plain)
            .foregroundStyle(spruce)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(
              EditorialOfficeTheme.softGrey.opacity(0.44), in: RoundedRectangle(cornerRadius: 8)
            )
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
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(minWidth: 540, idealWidth: 680, minHeight: 500, idealHeight: 540)
    .background(paper)
    .foregroundStyle(ink)
    .tint(spruce)
  }

  private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.caption.weight(.bold)).foregroundStyle(spruce.opacity(0.74))
      content()
        .textFieldStyle(.roundedBorder)
        .foregroundStyle(ink)
        .accessibilityLabel(label)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var formIsValid: Bool {
    [name, purpose, instructions, successCriteria]
      .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      && model.organization.employee(employeeID) != nil
  }
}
