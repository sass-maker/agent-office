import AgentOfficeCore
import SwiftUI

struct CompanyView: View {
  @EnvironmentObject private var model: AppModel
  let onDirtyChange: (Bool) -> Void
  var initialEmployeeID: String? = nil

  @State private var section: CompanySection = .members
  @State private var selectedEmployeeID: String?
  @State private var showsEmployeeDetails = false
  @State private var employeeTab: EmployeeDetailTab = .overview
  @State private var nameDraft = ""
  @State private var ownerDraft = ""
  @State private var outcomeDraft = ""
  @State private var profileDraft = OrganizationProfile.empty
  @State private var savedSnapshot = CompanyDraftSnapshot.empty
  @State private var isSaving = false
  @State private var showsLibrary = false

  var body: some View {
    GeometryReader { proxy in
      if showsEmployeeDetails, let employee = selectedEmployee {
        employeeDetails(employee, compact: proxy.size.width < 1_060)
      } else {
        companyBook(compact: proxy.size.width < 1_040)
      }
    }
    .background(EditorialOfficeTheme.workingField.ignoresSafeArea())
    .foregroundStyle(EditorialOfficeTheme.ink)
    .onAppear {
      loadDrafts()
      if let initialEmployeeID,
        model.organization.employee(initialEmployeeID) != nil
      {
        selectedEmployeeID = initialEmployeeID
        showsEmployeeDetails = true
      } else {
        selectedEmployeeID =
          model.organization.employee("maya")?.id
          ?? model.organization.employees.first?.id
      }
    }
    .onChange(of: currentSnapshot) { _, _ in
      onDirtyChange(profileIsDirty)
    }
    .sheet(isPresented: $showsLibrary) {
      CompanyLibraryView(initialSection: section.librarySection)
        .environmentObject(model)
    }
  }

  private func companyBook(compact: Bool) -> some View {
    VStack(spacing: 0) {
      companyHeader(compact: compact)

      Group {
        switch section {
        case .overview: companyOverview(compact: compact)
        case .members: membersDirectory(compact: compact)
        case .skills: cataloguePage(.skills)
        case .connections: cataloguePage(.connections)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func companyHeader(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 8) {
        Text("Company")
          .font(.system(.title3, design: .serif))
        Text(companyPurpose)
          .font(.system(size: compact ? 31 : 41, weight: .regular, design: .serif))
          .tracking(-0.75)
          .lineLimit(compact ? 3 : 2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, compact ? 28 : 46)
      .padding(.top, compact ? 28 : 38)
      .padding(.bottom, 26)

      HStack(spacing: 0) {
        ForEach(CompanySection.allCases) { item in
          Button {
            section = item
          } label: {
            Text(item.rawValue)
              .font(.system(.title3, design: .serif, weight: section == item ? .medium : .regular))
              .padding(.horizontal, compact ? 18 : 28)
              .frame(height: 45)
              .background(
                section == item ? EditorialOfficeTheme.softGrey.opacity(0.72) : Color.clear
              )
              .overlay(alignment: .bottom) {
                Rectangle()
                  .fill(
                    section == item
                      ? EditorialOfficeTheme.ink : EditorialOfficeTheme.rule.opacity(0.72)
                  )
                  .frame(height: section == item ? 2 : 1)
              }
          }
          .buttonStyle(.plain)
          .disabled(profileIsDirty && section == .overview && item != .overview)
          .help(
            profileIsDirty && section == .overview && item != .overview
              ? "Save Company Overview changes before opening \(item.rawValue)."
              : "Open \(item.rawValue)"
          )
          .accessibilityAddTraits(section == item ? .isSelected : [])
        }
        Spacer()
      }
      .padding(.horizontal, compact ? 28 : 46)
    }
    .background(EditorialOfficeTheme.bone.opacity(0.6))
    .overlay(alignment: .bottom) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.78)).frame(height: 1)
    }
  }

  @ViewBuilder
  private func membersDirectory(compact: Bool) -> some View {
    if compact {
      compactMembersDirectory
    } else {
      HStack(spacing: 0) {
        ScrollView(.vertical) {
          VStack(alignment: .leading, spacing: 18) {
            Text("Organization Members")
              .font(.system(.title2, design: .serif))

            relationshipWall(compact: false)
              .frame(minWidth: 780)

            Text(
              "Humans and AI employees belong to one organization. Their kind changes their capabilities and permissions, not whether they are members."
            )
            .font(.caption)
            .foregroundStyle(EditorialOfficeTheme.graphite)
            .frame(maxWidth: 720, alignment: .leading)
            .padding(.top, 4)
          }
          .padding(.horizontal, 42)
          .padding(.vertical, 28)
        }
        .scrollIndicators(.hidden)

        Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(width: 1)
        memberSummary
          .frame(width: 290)
      }
    }
  }

  private var compactMembersDirectory: some View {
    let members = model.organization.employees.filter {
      $0.id == "owner" || $0.kind == .human
        || [.hired, .paused].contains($0.effectiveEmploymentState)
    }

    return ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Organization Members")
            .font(.system(.title2, design: .serif))
          Text(
            "People first. Reporting context and employment state stay visible without a sideways canvas."
          )
          .font(.callout)
          .foregroundStyle(EditorialOfficeTheme.graphite)
        }
        .padding(.bottom, 6)

        ForEach(members) { employee in
          compactMemberRow(employee)
        }

        Text(
          "Humans and AI employees belong to one organization. Their kind changes their capabilities and permissions, not whether they are members."
        )
        .font(.caption)
        .foregroundStyle(EditorialOfficeTheme.graphite)
        .padding(.top, 8)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 26)
    }
    .scrollIndicators(.hidden)
  }

  private func compactMemberRow(_ employee: Employee) -> some View {
    let assignedSkills = model.organization.assignedSkills(employeeID: employee.id)

    return Button {
      selectedEmployeeID = employee.id
      showsEmployeeDetails = true
    } label: {
      HStack(spacing: 16) {
        EmployeePortrait(employee: employee, size: CGSize(width: 62, height: 70))
          .saturation(0)
          .contrast(1.12)

        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 7) {
            Text(employee.name)
              .font(.system(.title3, design: .serif, weight: .medium))
            Text(employee.kind == .human ? "OWNER" : statusText(employee).uppercased())
              .font(.caption2.weight(.semibold))
              .foregroundStyle(EditorialOfficeTheme.graphite)
          }

          Text(employee.kind == .human ? "Organization owner" : employee.role)
            .font(.callout)

          Text(
            employee.kind == .human
              ? "Leads the organization"
              : "Reports to \(managerName(for: employee)) · \(assignedSkills.count) skill\(assignedSkills.count == 1 ? "" : "s")"
          )
          .font(.caption)
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .lineLimit(2)
        }

        Spacer(minLength: 12)

        Image(systemName: "chevron.right")
          .font(.callout.weight(.semibold))
          .foregroundStyle(EditorialOfficeTheme.graphite)
      }
      .foregroundStyle(EditorialOfficeTheme.ink)
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, minHeight: 94, alignment: .leading)
      .background(EditorialOfficeTheme.paper)
      .overlay {
        Rectangle()
          .stroke(EditorialOfficeTheme.rule, lineWidth: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "Open \(employee.name), \(employee.kind == .human ? "organization owner" : employee.role)")
  }

  private func relationshipWall(compact: Bool) -> some View {
    let owner = model.organization.employee("owner")
    let employees = model.organization.employees.filter {
      $0.id != "owner"
        && ($0.kind == .human || [.hired, .paused].contains($0.effectiveEmploymentState))
    }

    return VStack(spacing: 0) {
      if let owner {
        memberFolio(owner, width: 220, isRoot: true, opensDetailsOnSelection: compact)

        Rectangle()
          .fill(EditorialOfficeTheme.ink.opacity(0.72))
          .frame(width: 1, height: 28)
      }

      ZStack(alignment: .top) {
        Rectangle()
          .fill(EditorialOfficeTheme.ink.opacity(0.72))
          .frame(height: 1)
          .padding(.horizontal, 78)

        HStack(alignment: .top, spacing: compact ? 14 : 18) {
          ForEach(employees) { employee in
            VStack(spacing: 0) {
              Rectangle()
                .fill(EditorialOfficeTheme.ink.opacity(0.72))
                .frame(width: 1, height: 30)
              memberFolio(employee, width: compact ? 146 : 158)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
  }

  private func memberFolio(
    _ employee: Employee,
    width: CGFloat,
    isRoot: Bool = false,
    opensDetailsOnSelection: Bool = false
  ) -> some View {
    let selected = selectedEmployeeID == employee.id
    let assignedSkills = model.organization.assignedSkills(employeeID: employee.id)
    return Button {
      selectedEmployeeID = employee.id
      if width < 150 || opensDetailsOnSelection { showsEmployeeDetails = true }
    } label: {
      VStack(spacing: 9) {
        HStack(spacing: 6) {
          Circle()
            .fill(employee.kind == .human ? EditorialOfficeTheme.ink : EditorialOfficeTheme.success)
            .frame(width: 6, height: 6)
          Text(employee.kind == .human ? "Founder" : statusText(employee))
            .font(.caption2.weight(.medium))
            .foregroundStyle(EditorialOfficeTheme.graphite)
          Spacer()
          Image(systemName: "arrow.up.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(EditorialOfficeTheme.graphite)
        }
        .padding(.top, 10)

        EmployeePortrait(
          employee: employee,
          size: CGSize(width: isRoot ? 106 : 84, height: isRoot ? 106 : 84)
        )
        .saturation(0)
        .contrast(1.12)

        Text(employee.name)
          .font(.system(isRoot ? .title3 : .callout, design: .serif, weight: .regular))
          .multilineTextAlignment(.center)
          .lineLimit(1)

        Text(employee.kind == .human ? "Owner" : employee.role)
          .font(.caption)
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .frame(minHeight: 28, alignment: .top)

        Rectangle()
          .fill(EditorialOfficeTheme.rule.opacity(0.72))
          .frame(height: 1)

        HStack(spacing: 5) {
          ForEach(assignedSkills.prefix(1)) { skill in
            Text(skill.name)
              .font(.caption2)
              .lineLimit(1)
              .padding(.horizontal, 4)
              .padding(.vertical, 2)
              .overlay {
                Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1)
              }
          }

          if assignedSkills.count > 1 {
            Text("+\(assignedSkills.count - 1)")
              .font(.caption2.weight(.medium))
              .padding(.horizontal, 4)
              .padding(.vertical, 2)
              .overlay {
                Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1)
              }
          }
        }
        .frame(maxWidth: width - 24)
        .frame(minHeight: 18)
      }
      .foregroundStyle(EditorialOfficeTheme.ink)
      .padding(.horizontal, 12)
      .padding(.bottom, 12)
      .frame(width: width)
      .frame(minHeight: isRoot ? 244 : 242)
      .background(EditorialOfficeTheme.paper)
      .overlay {
        Rectangle()
          .stroke(
            selected ? EditorialOfficeTheme.ink : EditorialOfficeTheme.rule,
            lineWidth: selected ? 1.5 : 1)
      }
      .shadow(
        color: EditorialOfficeTheme.sidebarInk.opacity(selected ? 0.2 : 0.12), radius: 8, x: 3, y: 6
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Open \(employee.name), \(employee.role)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private var memberSummary: some View {
    ScrollView {
      if let employee = selectedEmployee {
        VStack(alignment: .leading, spacing: 16) {
          memberFolio(employee, width: 220)
            .frame(maxWidth: .infinity)

          summarySection("Responsibilities", value: employee.responsibility)
          summarySection("Manager", value: managerName(for: employee))
          summarySection(
            "Reports", value: reports(for: employee).map(\.name).joined(separator: "\n"))
          summarySection(
            "Collaborates with",
            value: collaborators(for: employee).map(\.name).joined(separator: "\n"))
          summarySection("Skills", value: skills(for: employee).map(\.name).joined(separator: ", "))

          Button("Open full profile") {
            showsEmployeeDetails = true
          }
          .buttonStyle(EditorialPrimaryButtonStyle())
          .frame(maxWidth: .infinity)

          if employee.kind == .ai {
            Button("Teach a skill") {
              section = .skills
              showsLibrary = true
            }
            .buttonStyle(EditorialSecondaryButtonStyle())
            .frame(maxWidth: .infinity)
          }
        }
        .padding(26)
      } else {
        Text("Select a member")
          .font(.system(.title2, design: .serif))
          .padding(26)
      }
    }
    .scrollIndicators(.hidden)
    .background(EditorialOfficeTheme.paper.opacity(0.72))
  }

  private func summarySection(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(height: 1)
      Text(title)
        .font(.callout.weight(.semibold))
        .padding(.top, 9)
      Text(value.isEmpty ? "None" : value)
        .font(.caption)
        .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.76))
        .lineSpacing(3)
    }
  }

  private func companyOverview(compact: Bool) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Organization data")
              .font(.system(.title2, design: .serif))
            Text("The shared company context every employee receives.")
              .font(.callout)
              .foregroundStyle(EditorialOfficeTheme.graphite)
          }
          Spacer()
          Button(isSaving ? "Saving…" : "Save changes", action: saveProfile)
            .buttonStyle(EditorialPrimaryButtonStyle())
            .disabled(!profileIsValid || !profileIsDirty || isSaving)
        }

        if compact {
          VStack(spacing: 24) {
            identityFields
            productFields
          }
        } else {
          HStack(alignment: .top, spacing: 42) {
            identityFields
            Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.7)).frame(width: 1)
            productFields
          }
        }

        VStack(alignment: .leading, spacing: 22) {
          companyTextArea(
            "Operating principles", prompt: "How should people make decisions and work together?",
            text: $profileDraft.operatingPrinciples)
          companyTextArea(
            "Constraints and safe claims", prompt: "What must the team never assume or do?",
            text: $profileDraft.constraints)
        }
      }
      .padding(compact ? 28 : 44)
    }
    .scrollIndicators(.hidden)
  }

  private var identityFields: some View {
    VStack(alignment: .leading, spacing: 22) {
      Text("Identity")
        .font(.system(.title3, design: .serif, weight: .medium))
      companyField("Company name", prompt: "Clarity Initiative", text: $nameDraft)
      companyField("Owner", prompt: "What should the team call you?", text: $ownerDraft)
      companyTextArea(
        "Purpose", prompt: "Why does this organization exist?", text: $profileDraft.purpose)
      companyTextArea(
        "Current mission", prompt: "What must the organization make true now?", text: $outcomeDraft)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private var productFields: some View {
    VStack(alignment: .leading, spacing: 22) {
      Text("Product context")
        .font(.system(.title3, design: .serif, weight: .medium))
      companyTextArea(
        "Product", prompt: "What are you building or offering?", text: $profileDraft.product)
      companyTextArea("Audience", prompt: "Who is it for?", text: $profileDraft.audience)
      companyField(
        "Current stage", prompt: "Proof of concept, early product, growing…",
        text: $profileDraft.stage)
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
  }

  private func employeeDetails(_ employee: Employee, compact: Bool) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Button {
          showsEmployeeDetails = false
          employeeTab = .overview
        } label: {
          Label("Members", systemImage: "chevron.left")
        }
        .buttonStyle(.plain)

        Text("/")
          .foregroundStyle(EditorialOfficeTheme.graphite)
        Text(employee.name)
          .font(.callout.weight(.medium))
        Spacer()
      }
      .padding(.horizontal, 28)
      .frame(height: 48)
      .background(EditorialOfficeTheme.paper.opacity(0.52))
      .overlay(alignment: .bottom) {
        Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(height: 1)
      }

      if compact {
        ScrollView {
          VStack(spacing: 0) {
            employeeIdentity(employee)
            employeeMain(employee)
            employeeLedger(employee)
          }
        }
        .scrollIndicators(.hidden)
      } else {
        HStack(spacing: 0) {
          employeeIdentity(employee)
            .frame(width: 330)
          Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(width: 1)
          employeeMain(employee)
            .frame(maxWidth: .infinity)
          Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(width: 1)
          employeeLedger(employee)
            .frame(width: 320)
        }
      }
    }
  }

  private func employeeIdentity(_ employee: Employee) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      EmployeePortrait(employee: employee, size: CGSize(width: 260, height: 300))
        .saturation(0)
        .contrast(1.14)
        .frame(maxWidth: .infinity)
        .background(EditorialOfficeTheme.paper.opacity(0.6))
        .overlay {
          Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1)
        }

      Text(employee.name)
        .font(.system(size: 38, weight: .regular, design: .serif))
        .padding(.top, 22)
      Text(employee.role)
        .font(.title3)
        .foregroundStyle(EditorialOfficeTheme.graphite)
        .padding(.top, 2)
      Label(statusText(employee), systemImage: "circle.fill")
        .font(.callout)
        .padding(.top, 14)

      Rectangle().fill(EditorialOfficeTheme.rule).frame(height: 1).padding(.vertical, 22)

      identityFact(
        "Member kind", value: employee.kind == .human ? "Human" : "AI employee", icon: "person")
      identityFact(
        "Reports to", value: managerName(for: employee), icon: "person.line.dotted.person")
      identityFact(
        "Direct reports", value: reports(for: employee).map(\.name).joined(separator: ", "),
        icon: "person.2")

      Spacer(minLength: 22)

      if employee.kind == .ai {
        Button {
          model.revealEmployeeHome(employee.id)
        } label: {
          Label("Open employee home", systemImage: "folder")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(EditorialPrimaryButtonStyle())

        Button {
          section = .skills
          showsLibrary = true
        } label: {
          Label("Teach a skill", systemImage: "graduationcap")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(EditorialSecondaryButtonStyle())
        .padding(.top, 10)

        if employee.effectiveEmploymentState == .hired {
          Button("Pause employment") { model.pauseEmployee(employee.id) }
            .buttonStyle(EditorialSecondaryButtonStyle()).padding(.top, 10)
        } else if employee.effectiveEmploymentState == .paused {
          Button("Resume employment") { model.resumeEmployee(employee.id) }
            .buttonStyle(EditorialPrimaryButtonStyle()).padding(.top, 10)
        }
      }
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(EditorialOfficeTheme.bone.opacity(0.48))
  }

  private func employeeMain(_ employee: Employee) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 0) {
          ForEach(EmployeeDetailTab.allCases) { tab in
            Button {
              employeeTab = tab
            } label: {
              Text(tab.rawValue)
                .font(
                  .system(.title3, design: .serif, weight: employeeTab == tab ? .medium : .regular)
                )
                .frame(width: 116, height: 43)
                .background(employeeTab == tab ? EditorialOfficeTheme.paper : Color.clear)
                .overlay { Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1) }
            }
            .buttonStyle(.plain)
          }
          Spacer()
        }

        switch employeeTab {
        case .overview:
          employeeOverview(employee)
        case .work:
          employeeWork(employee)
        case .skills:
          employeeSkillDetail(employee)
        }
      }
      .padding(.horizontal, 32)
      .padding(.bottom, 34)
    }
    .scrollIndicators(.hidden)
    .background(EditorialOfficeTheme.paper.opacity(0.34))
  }

  private func employeeOverview(_ employee: Employee) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(employee.responsibility)
        .font(.system(size: 31, weight: .regular, design: .serif))
        .tracking(-0.45)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 30)

      detailRule
      Text("Current commitment").font(.system(.title3, design: .serif, weight: .medium)).padding(
        .top, 22)
      if let outcome = model.organization.activeEmployeeOutcome(for: employee.id)
        ?? model.organization.latestEmployeeOutcome(for: employee.id)
      {
        Text(outcome.outcome).font(.title3.weight(.medium)).padding(.top, 10)
        Label(
          "\(outcome.status.rawValue.capitalized) · \(outcome.effectivePriority.rawValue) priority",
          systemImage: outcome.status == .delivered ? "checkmark.circle.fill" : "scope"
        )
        .font(.callout).padding(.top, 12)
        if !outcome.effectiveAcceptanceCriteria.isEmpty {
          Text("Acceptance: \(outcome.effectiveAcceptanceCriteria.joined(separator: " · "))").font(
            .caption
          ).foregroundStyle(EditorialOfficeTheme.graphite).padding(.top, 8)
        }
      } else {
        Text("No outcome is currently assigned.").font(.callout).foregroundStyle(
          EditorialOfficeTheme.graphite
        ).padding(.top, 10)
      }

      detailRule.padding(.vertical, 22)
      Text("Active work").font(.system(.title3, design: .serif, weight: .medium))
      VStack(spacing: 0) {
        ForEach(activeTasks(for: employee)) { task in
          employeeTaskRow(task)
        }
        if activeTasks(for: employee).isEmpty {
          Text(
            "No active work. The employee will pick up from the task board when the next day begins."
          )
          .font(.callout)
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .padding(.vertical, 18)
        }
      }
      .padding(.top, 12)

      detailRule.padding(.vertical, 22)
      HStack(alignment: .top, spacing: 28) {
        VStack(alignment: .leading, spacing: 12) {
          Text("Responsibilities").font(.system(.title3, design: .serif, weight: .medium))
          Text("• \(employee.responsibility)")
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(width: 1, height: 140)

        VStack(alignment: .leading, spacing: 12) {
          Text("Working relationships").font(.system(.title3, design: .serif, weight: .medium))
          relationshipRow("Manager", value: managerName(for: employee))
          relationshipRow(
            "Direct reports", value: reports(for: employee).map(\.name).joined(separator: ", "))
          relationshipRow(
            "Collaborators", value: collaborators(for: employee).map(\.name).joined(separator: ", ")
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      latestRunSection(for: employee)

      if let contract = model.organization.workingContract(for: employee.id) {
        contractSection(for: employee, contract: contract)
      }
    }
  }

  /// The last run this employee actually had, and whose move it is now.
  ///
  /// Absence is stated rather than left blank: an employee that has never run
  /// says so, so a quiet folio cannot read as a successful one.
  @ViewBuilder
  private func latestRunSection(for employee: Employee) -> some View {
    detailRule.padding(.vertical, 22)
    Text("Latest run").font(.system(.title3, design: .serif, weight: .medium))
    if let receipt = model.organization.latestRunReceipt(forEmployee: employee.id) {
      VStack(alignment: .leading, spacing: 8) {
        // Status is text first. Colour is never the only carrier.
        Text(receipt.headline).font(.callout.weight(.medium))
        Text(receipt.result.summary)
          .font(.callout)
          .fixedSize(horizontal: false, vertical: true)
        contractFact("Next action", receipt.nextAction.statement)
        contractFact("Evidence", receipt.result.evidenceStatement)
        contractFact("Ran on", receipt.work.runtimeKind ?? "not recorded")
        contractFact("Model", receipt.work.modelName ?? "the runtime's own default")
        contractFact("Usage", usageText(receipt.result.usage))
        contractFact(
          "Planned",
          "\(receipt.scheduledWindow.start.formatted(date: .abbreviated, time: .shortened)) · "
            + "\(Int(receipt.scheduledWindow.duration / 60)) min")
        contractFact("Actual", actualText(receipt))
      }
      .padding(.top, 12)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(
        "Latest run for \(employee.name): \(receipt.headline) \(receipt.nextAction.statement)")
    } else {
      Text(
        "This employee has not run yet. Nothing is being claimed about work it has not done."
      )
      .font(.callout)
      .foregroundStyle(EditorialOfficeTheme.graphite)
      .padding(.top, 10)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  /// Three-valued on purpose: a runtime that reported nothing is unknown, never
  /// zero.
  private func usageText(_ usage: RunUsage) -> String {
    switch usage {
    case .observed(let description): description
    case .unknown: "The runtime reported nothing"
    case .notApplicable: "Not applicable"
    }
  }

  private func actualText(_ receipt: RunReceipt) -> String {
    guard let actual = receipt.actual else { return "Never started" }
    let started = actual.startedAt.formatted(date: .abbreviated, time: .shortened)
    guard let duration = actual.duration else { return "Started \(started), still open" }
    return "Started \(started) · ran \(Int(duration / 60)) min"
  }

  @ViewBuilder
  private func contractSection(for employee: Employee, contract: WorkingContract) -> some View {
    detailRule.padding(.vertical, 22)
    Text("Working contract · revision \(contract.revision)").font(
      .system(.title3, design: .serif, weight: .medium))
    VStack(alignment: .leading, spacing: 12) {
      contractFact("Identity and role", "\(employee.name) · \(contract.role)")
      contractFact("Responsibilities", contract.responsibility)
      contractFact(
        "Relationships", "Manager: \(contract.managerID.map(model.employeeName) ?? "None")")
      contractFact(
        "Assigned skills",
        contract.assignedSkillIDs.map(contractSkillName).joined(separator: ", "))
      contractFact(
        "Declared tools",
        contract.declaredConnectionIDs.isEmpty
          ? "None"
          : contract.declaredConnectionIDs.map(contractConnectionName).joined(separator: ", "))
      contractFact(
        "Granted authority",
        contract.capabilityGrants.isEmpty
          ? "None"
          : contract.capabilityGrants.map(contractCapabilityName).joined(separator: ", "))
      contractFact(
        "Execution",
        "\(contract.executionProvider.displayName) · \(contract.modelName ?? "provider default")"
      )
      contractFact("Environment", "Local organization sandbox · \(contract.workspacePath)")
      contractFact(
        "Autonomy",
        "\(contractReviewName(contract.reviewPolicy)) · delegate: \(contract.boundaries.mayDelegate ? "yes" : "no") · publish: \(contract.boundaries.mayPublish ? "yes" : "no")"
      )
    }
    .padding(.top, 14)
  }

  private func contractFact(_ title: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 16) {
      Text(title).font(.caption.weight(.semibold)).foregroundStyle(EditorialOfficeTheme.graphite)
        .frame(width: 128, alignment: .leading)
      Text(value.isEmpty ? "None" : value).font(.callout).textSelection(.enabled).frame(
        maxWidth: .infinity, alignment: .leading)
    }
  }

  private func contractSkillName(_ id: String) -> String {
    model.organization.skill(id)?.name ?? id
  }

  private func contractConnectionName(_ id: String) -> String {
    model.organization.knowledge?.connectionDefinitions.first { $0.id == id }?.name ?? id
  }

  private func contractCapabilityName(_ id: String) -> String {
    model.organization.knowledge?.connectionDefinitions.first { $0.capabilityID == id }?.name ?? id
  }

  private func contractReviewName(_ policy: PlanReviewPolicy) -> String {
    switch policy {
    case .always: "Review every plan"
    case .whenAuthorityChanges: "Review authority changes"
    case .automaticForLocalWork: "Approve bounded local plans"
    }
  }

  private func employeeWork(_ employee: Employee) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Work owned by \(employee.name)")
        .font(.system(size: 31, weight: .regular, design: .serif))
        .padding(.vertical, 30)
      detailRule
      ForEach(tasks(for: employee)) { task in
        employeeTaskRow(task)
      }
      if tasks(for: employee).isEmpty {
        Text("No work has been assigned yet.")
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .padding(.vertical, 24)
      }
    }
  }

  private func employeeSkillDetail(_ employee: Employee) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Skills practiced by \(employee.name)")
        .font(.system(size: 31, weight: .regular, design: .serif))
        .padding(.vertical, 30)
      detailRule
      ForEach(skills(for: employee)) { skill in
        VStack(alignment: .leading, spacing: 6) {
          HStack {
            Text(skill.name).font(.headline)
            Spacer()
            Text("v\(skill.version)").font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
          }
          Text(skill.purpose).font(.callout).foregroundStyle(EditorialOfficeTheme.ink.opacity(0.76))
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
          Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.6)).frame(height: 1)
        }
      }
      if skills(for: employee).isEmpty {
        Text("No skills assigned yet.")
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .padding(.vertical, 24)
      }
    }
  }

  private func employeeLedger(_ employee: Employee) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        ledgerSection("Skills") {
          ForEach(skills(for: employee)) { skill in
            HStack {
              Text(skill.name)
              Spacer()
              Text(skill.source == .builtIn ? "Practiced" : "Taught")
                .foregroundStyle(EditorialOfficeTheme.graphite)
            }
            .font(.callout)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
              Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.55)).frame(height: 1)
            }
          }
        }

        ledgerSection("Recent artifacts") {
          ForEach(artifacts(for: employee).suffix(4).reversed()) { artifact in
            Button {
              model.reveal(artifact)
            } label: {
              HStack {
                Image(systemName: "doc.text")
                Text(artifact.relativePath).lineLimit(1)
                Spacer()
                Text(artifact.createdAt, format: .dateTime.month(.abbreviated).day())
                  .foregroundStyle(EditorialOfficeTheme.graphite)
              }
              .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 5)
          }
          if artifacts(for: employee).isEmpty {
            Text("None yet").font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
          }
        }

        ledgerSection("Recent activity") {
          ForEach(activity(for: employee).suffix(5).reversed()) { item in
            HStack(alignment: .top, spacing: 9) {
              Circle().fill(EditorialOfficeTheme.ink).frame(width: 6, height: 6).padding(.top, 5)
              VStack(alignment: .leading, spacing: 3) {
                Text(item.message).font(.caption)
                Text(item.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                  .font(.caption2)
                  .foregroundStyle(EditorialOfficeTheme.graphite)
              }
            }
          }
        }

        ledgerSection("Blockers") {
          let items = blockers(for: employee)
          Text(items.isEmpty ? "None" : items.map(\.title).joined(separator: "\n"))
            .font(.callout)
            .foregroundStyle(
              items.isEmpty ? EditorialOfficeTheme.ink : EditorialOfficeTheme.attention)
        }
      }
      .padding(24)
    }
    .scrollIndicators(.hidden)
    .background(EditorialOfficeTheme.paper.opacity(0.64))
  }

  private func cataloguePage(_ page: CompanySection) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 5) {
            Text(page == .skills ? "Skill catalogue" : "Connections catalogue")
              .font(.system(.title2, design: .serif))
            Text(
              page == .skills
                ? "What the company knows, who can use it, and where coverage is missing."
                : "Recognized tools and execution routes. Credentials never live in this catalogue."
            )
            .font(.callout)
            .foregroundStyle(EditorialOfficeTheme.graphite)
          }
          Spacer()
          Button(page == .skills ? "Teach or assign" : "Inspect grants") {
            showsLibrary = true
          }
          .buttonStyle(EditorialPrimaryButtonStyle())
        }

        if page == .skills {
          ForEach(model.organization.knowledge?.skillDefinitions ?? []) { skill in
            catalogueRow(
              title: skill.name,
              subtitle: "\(skill.category) · v\(skill.version)",
              detail: skill.purpose,
              trailing: model.organization.employeesWithSkill(skill.id).map(\.name).joined(
                separator: ", ")
            )
          }
        } else {
          ForEach(model.organization.knowledge?.connectionDefinitions ?? []) { connection in
            let granted =
              connection.capabilityID.map { capability in
                model.organization.employees.filter { $0.capabilityGrants.contains(capability) }
                  .map(\.name)
              } ?? []
            catalogueRow(
              title: connection.name,
              subtitle: connection.kind.rawValue.capitalized,
              detail: connection.summary,
              trailing: granted.isEmpty ? "No grants" : granted.joined(separator: ", ")
            )
          }
        }
      }
      .padding(40)
    }
    .scrollIndicators(.hidden)
  }

  private func catalogueRow(title: String, subtitle: String, detail: String, trailing: String)
    -> some View
  {
    HStack(alignment: .top, spacing: 20) {
      VStack(alignment: .leading, spacing: 5) {
        Text(title).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
      }
      .frame(width: 180, alignment: .leading)
      Text(detail).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
      Text(trailing.isEmpty ? "Coverage gap" : trailing)
        .font(.caption.weight(.medium))
        .foregroundStyle(
          trailing.isEmpty ? EditorialOfficeTheme.attention : EditorialOfficeTheme.ink
        )
        .frame(width: 170, alignment: .leading)
    }
    .padding(.vertical, 17)
    .overlay(alignment: .bottom) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(height: 1)
    }
  }

  private func companyField(_ label: String, prompt: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label).font(.system(.title3, design: .serif, weight: .medium))
      TextField(prompt, text: text)
        .textFieldStyle(.plain)
        .padding(.vertical, 8)
        .accessibilityLabel(label)
      Rectangle().fill(EditorialOfficeTheme.rule).frame(height: 1)
    }
  }

  private func companyTextArea(_ label: String, prompt: String, text: Binding<String>) -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      Text(label).font(.system(.title3, design: .serif, weight: .medium))
      TextField(prompt, text: text, axis: .vertical)
        .textFieldStyle(.plain)
        .lineLimit(2...5)
        .padding(.vertical, 8)
        .accessibilityLabel(label)
      Rectangle().fill(EditorialOfficeTheme.rule).frame(height: 1)
    }
  }

  private func identityFact(_ title: String, value: String, icon: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon).frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.callout.weight(.semibold))
        Text(value.isEmpty ? "None" : value).font(.callout).foregroundStyle(
          EditorialOfficeTheme.graphite)
      }
    }
    .padding(.bottom, 15)
  }

  @ViewBuilder
  private func employeeTaskRow(_ task: WorkTask) -> some View {
    if let artifact = artifact(for: task) {
      Button {
        model.reveal(artifact)
      } label: {
        employeeTaskRowContent(task, showsArtifact: true)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open artifact for \(task.title)")
    } else {
      employeeTaskRowContent(task, showsArtifact: false)
    }
  }

  private func employeeTaskRowContent(_ task: WorkTask, showsArtifact: Bool) -> some View {
    HStack(spacing: 14) {
      Image(systemName: task.status == .done ? "checkmark" : "arrow.up")
        .foregroundStyle(
          task.status == .done ? EditorialOfficeTheme.success : EditorialOfficeTheme.attention
        )
        .frame(width: 18)
      Text(task.title).font(.callout).frame(maxWidth: .infinity, alignment: .leading)
      Text(task.status.rawValue.capitalized).font(.caption).frame(width: 82, alignment: .leading)
      Text(task.updatedAt, format: .dateTime.month(.abbreviated).day()).font(.caption).frame(
        width: 54)
      if showsArtifact {
        Image(systemName: "doc.text").frame(width: 18)
      }
    }
    .padding(.vertical, 12)
    .overlay(alignment: .bottom) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.55)).frame(height: 1)
    }
  }

  private func relationshipRow(_ title: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Text(title).font(.caption.weight(.semibold)).frame(width: 88, alignment: .leading)
      Text(value.isEmpty ? "None" : value).font(.caption).foregroundStyle(
        EditorialOfficeTheme.ink.opacity(0.76))
    }
  }

  private func ledgerSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 9) {
      Text(title).font(.headline)
      content()
    }
    .padding(.bottom, 18)
    .overlay(alignment: .bottom) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.7)).frame(height: 1)
    }
  }

  private var detailRule: some View {
    Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(height: 1)
  }

  private var selectedEmployee: Employee? {
    selectedEmployeeID.flatMap { model.organization.employee($0) }
  }

  private var companyPurpose: String {
    let value = profileDraft.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty
      ? "A company where people and AI employees make useful work together." : value
  }

  private func statusText(_ employee: Employee) -> String {
    if employee.kind == .ai, employee.effectiveEmploymentState == .paused { return "Paused" }
    if employee.kind == .ai, employee.effectiveEmploymentState == .retired { return "Retired" }
    return switch employee.status {
    case .working, .planning: "In progress"
    case .reviewing: "Reviewing"
    case .blocked: "Blocked"
    case .celebrating: "Delivered"
    case .resting, .waiting: "Available"
    }
  }

  private func managerName(for employee: Employee) -> String {
    employee.managerID.map(model.employeeName) ?? "None"
  }

  private func reports(for employee: Employee) -> [Employee] {
    model.organization.employees.filter { $0.managerID == employee.id }
  }

  private func collaborators(for employee: Employee) -> [Employee] {
    let taskIDs = Set(tasks(for: employee).map(\.id))
    let collaboratorIDs = Set(
      model.organization.tasks.filter {
        !$0.dependencyIDs.filter(taskIDs.contains).isEmpty || taskIDs.contains($0.id)
      }.flatMap { [$0.assigneeID, $0.reviewerID].compactMap { $0 } })
    return model.organization.employees.filter {
      collaboratorIDs.contains($0.id) && $0.id != employee.id
    }
  }

  private func tasks(for employee: Employee) -> [WorkTask] {
    model.organization.tasks.filter { $0.assigneeID == employee.id || $0.reviewerID == employee.id }
  }

  private func activeTasks(for employee: Employee) -> [WorkTask] {
    tasks(for: employee).filter { $0.status != .done }
  }

  private func skills(for employee: Employee) -> [SkillDefinition] {
    model.organization.assignedSkills(employeeID: employee.id)
  }

  private func artifacts(for employee: Employee) -> [Artifact] {
    model.organization.artifacts.filter { $0.authorID == employee.id }
  }

  private func artifact(for task: WorkTask) -> Artifact? {
    if let artifactID = task.artifactIDs.last,
      let artifact = model.organization.artifacts.first(where: { $0.id == artifactID })
    {
      return artifact
    }
    return model.organization.artifacts.last(where: { $0.taskID == task.id })
  }

  private func activity(for employee: Employee) -> [Activity] {
    model.organization.activity.filter { $0.actorID == employee.id }
  }

  private func blockers(for employee: Employee) -> [Blocker] {
    model.organization.blockers.filter { !$0.resolved && $0.employeeID == employee.id }
  }

  private var profileIsValid: Bool {
    [nameDraft, ownerDraft, outcomeDraft, profileDraft.product, profileDraft.audience]
      .allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
  }

  private var currentSnapshot: CompanyDraftSnapshot {
    CompanyDraftSnapshot(
      name: nameDraft, owner: ownerDraft, outcome: outcomeDraft, profile: profileDraft)
  }

  private var profileIsDirty: Bool { currentSnapshot != savedSnapshot }

  private func loadDrafts() {
    nameDraft = model.organization.name
    ownerDraft = model.organization.employee("owner")?.name ?? ""
    outcomeDraft = model.organization.outcome
    profileDraft = model.organization.knowledge?.profile ?? .empty
    profileDraft.product = conciseProduct(from: profileDraft.product)
    savedSnapshot = currentSnapshot
    onDirtyChange(false)
  }

  private func conciseProduct(from value: String) -> String {
    guard value.contains("## Product") else { return value }
    let lines = value.components(separatedBy: .newlines)
    guard
      let heading = lines.firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "## Product"
      })
    else { return value }
    let description = lines.dropFirst(heading + 1)
      .prefix { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("## ") }
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return description.isEmpty ? value : description
  }

  private func saveProfile() {
    let snapshot = currentSnapshot
    isSaving = true
    Task {
      let saved = await model.updateCompanyProfile(
        name: nameDraft,
        ownerName: ownerDraft,
        outcome: outcomeDraft,
        profile: profileDraft
      )
      isSaving = false
      if saved {
        savedSnapshot = snapshot
        onDirtyChange(false)
      }
    }
  }
}

private struct CompanyDraftSnapshot: Equatable {
  let name: String
  let owner: String
  let outcome: String
  let profile: OrganizationProfile

  static let empty = CompanyDraftSnapshot(name: "", owner: "", outcome: "", profile: .empty)
}

private enum CompanySection: String, CaseIterable, Identifiable {
  case overview = "Overview"
  case members = "Members"
  case skills = "Skills"
  case connections = "Connections"

  var id: String { rawValue }

  var librarySection: LibrarySection {
    switch self {
    case .overview, .members: .employees
    case .skills: .skills
    case .connections: .connections
    }
  }
}

private enum EmployeeDetailTab: String, CaseIterable, Identifiable {
  case overview = "Overview"
  case work = "Work"
  case skills = "Skills"

  var id: String { rawValue }
}
