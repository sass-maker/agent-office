import AgentOfficeCore
import SwiftUI

struct OrganizationHomeView: View {
  var onOpenEmployeeProfile: (String) -> Void = { _ in }
  var onOpenMission: () -> Void = {}
  @EnvironmentObject private var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  @State private var outcomeDraft = ""
  @State private var productBriefDraft = ""
  @State private var showsProductBrief = false
  @State private var showsCompanyLibrary = false
  @State private var showsResearchAssignment = false
  @State private var outcomeEmployee: Employee?
  @State private var showsEmployeeDrawer = false
  @State private var hasExplicitlyOpenedEmployeeDrawer = false
  @State private var traySelection: OwnerTraySelection?
  @State private var pendingStopOutcomeID: String?
  @AccessibilityFocusState private var drawerAccessibilityFocus: DrawerAccessibilityFocus?

  private let ink = EditorialOfficeTheme.ink

  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < 1_180

      ZStack {
        OfficeSceneView(
          organization: model.organization,
          selectedEmployeeID: isEmployeeDrawerPresented(compact: compact)
            ? model.selectedEmployeeID : nil,
          onSelectEmployee: selectEmployee
        )
        .accessibilityRepresentation {
          VStack {
            Text("Living office. \(sceneAccessibilitySummary)")
            ForEach(aiEmployees) { employee in
              Button("Open \(employee.name), \(employee.role). \(employee.status.rawValue)") {
                selectEmployee(employee.id)
              }
            }
          }
        }

        Rectangle()
          .fill(Color.black.opacity(colorScheme == .dark ? 0.20 : 0))
          .blendMode(.multiply)
          .allowsHitTesting(false)
          .accessibilityHidden(true)

        missionNote(compact: compact)
          .padding(.top, compact ? 16 : 24)
          .padding(.leading, compact ? 14 : 22)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        officeDeskBar(compact: compact)
          .padding(.leading, compact ? 12 : 22)
          .padding(.bottom, compact ? 12 : 22)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

        contextualDrawer(compact: compact)
      }
      .background(EditorialOfficeTheme.bone)
      .clipped()
    }
    .background(EditorialOfficeTheme.bone)
    .foregroundStyle(ink)
    .onAppear {
      outcomeDraft = model.organization.outcome
      productBriefDraft = model.organization.productBrief
    }
    .onChange(of: model.organization.outcome) { _, value in
      if outcomeDraft != value { outcomeDraft = value }
    }
    .sheet(isPresented: $showsProductBrief) {
      ProductBriefSheet(
        brief: $productBriefDraft,
        onSave: {
          model.updateProductBrief(productBriefDraft)
          showsProductBrief = false
        },
        onReveal: model.revealOrganizationFolder
      )
    }
    .sheet(isPresented: $showsCompanyLibrary) {
      CompanyLibraryView()
        .environmentObject(model)
    }
    .sheet(isPresented: $showsResearchAssignment) {
      ResearchAssignmentSheet()
        .environmentObject(model)
    }
    .sheet(item: $outcomeEmployee) { employee in
      EmployeeOutcomeAssignmentSheet(employee: employee)
        .environmentObject(model)
    }
    .stopOutcomeConfirmation($pendingStopOutcomeID)
  }

  private func missionNote(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("CURRENT MISSION")
        .font(.system(size: 10, weight: .medium, design: .default))
        .tracking(1.4)
      Text(model.organization.outcome)
        .font(.system(compact ? .callout : .title3, design: .serif, weight: .regular))
        .lineLimit(compact ? 4 : 5)
        .fixedSize(horizontal: false, vertical: true)
      Rectangle()
        .fill(EditorialOfficeTheme.rule.opacity(0.7))
        .frame(height: 1)
      Text(outcomeOfficePrompt)
        .font(.caption.weight(.medium))
        .foregroundStyle(EditorialOfficeTheme.graphite)
        .lineLimit(2)
    }
    .foregroundStyle(EditorialOfficeTheme.ink)
    .padding(.horizontal, 15)
    .padding(.vertical, 13)
    .frame(width: compact ? 260 : 360, alignment: .leading)
    .background(EditorialOfficeTheme.paper.opacity(0.94))
    .overlay {
      Rectangle().stroke(EditorialOfficeTheme.ink.opacity(0.28), lineWidth: 1)
    }
    .shadow(color: EditorialOfficeTheme.sidebarInk.opacity(0.13), radius: 8, x: 3, y: 5)
    .allowsHitTesting(false)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Current mission. \(model.organization.outcome). \(outcomeOfficePrompt)")
  }

  private func officeDeskBar(compact: Bool) -> some View {
    HStack(spacing: compact ? 5 : 8) {
      ForEach(Array(aiEmployees.enumerated()), id: \.element.id) { index, employee in
        editorialEmployeeButton(employee, index: index, compact: compact)
      }

      Rectangle()
        .fill(EditorialOfficeTheme.rule.opacity(0.78))
        .frame(width: 1, height: 38)
        .padding(.horizontal, compact ? 1 : 4)

      ForEach(OwnerTraySelection.allCases) { selection in
        editorialTrayButton(selection, compact: compact)
      }
    }
    .padding(6)
    .background(EditorialOfficeTheme.paper.opacity(0.96))
    .overlay {
      Rectangle()
        .stroke(EditorialOfficeTheme.ink.opacity(0.28), lineWidth: 1)
    }
    .shadow(color: EditorialOfficeTheme.sidebarInk.opacity(0.18), radius: 12, x: 4, y: 7)
    .frame(maxWidth: compact ? .infinity : 840, alignment: .leading)
    .padding(.trailing, compact ? 12 : 0)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Team and work summary")
  }

  private func editorialEmployeeButton(_ employee: Employee, index: Int, compact: Bool) -> some View
  {
    let selected =
      model.selectedEmployeeID == employee.id && isEmployeeDrawerPresented(compact: compact)

    return Button {
      selectEmployee(employee.id)
    } label: {
      HStack(spacing: compact ? 4 : 7) {
        EmployeePortrait(
          employee: employee,
          size: CGSize(width: compact ? 24 : 28, height: compact ? 28 : 32)
        )

        VStack(alignment: .leading, spacing: 1) {
          Text(employee.name)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
          if !compact {
            Text(employeeStatusLabel(employee))
              .font(.caption2)
              .foregroundStyle(EditorialOfficeTheme.graphite)
              .lineLimit(1)
          }
        }
      }
      .deskBarButtonChrome(selected: selected, compact: compact, minWidth: compact ? 54 : 82)
    }
    .buttonStyle(.plain)
    .keyboardShortcut(
      KeyEquivalent(Character(String(index + 1))),
      modifiers: [.command, .option]
    )
    .help("Open \(employee.name)'s folio · Command-Option-\(index + 1)")
    .accessibilityLabel("\(employee.name), \(employee.role), \(employee.status.rawValue)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func editorialTrayButton(_ selection: OwnerTraySelection, compact: Bool) -> some View {
    let count = ownerTrayCount(selection)
    let selected = traySelection == selection

    return Button {
      let willOpen = !selected
      animateSelection {
        traySelection = willOpen ? selection : nil
        if willOpen { showsEmployeeDrawer = false }
      }
      drawerAccessibilityFocus = willOpen ? .ownerTray : nil
    } label: {
      HStack(spacing: 5) {
        Image(systemName: selection.icon)
          .font(.caption.weight(.semibold))
        Text(compact ? selection.compactTitle : ownerTrayTitle(selection))
          .font(.caption.weight(.semibold))
          .lineLimit(1)
        Text("\(count)")
          .font(.caption2.monospacedDigit().weight(.semibold))
          .foregroundStyle(EditorialOfficeTheme.graphite)
      }
      .deskBarButtonChrome(selected: selected, compact: compact)
    }
    .buttonStyle(.plain)
    .keyboardShortcut(selection.shortcut, modifiers: [.command, .shift])
    .help("Open \(ownerTrayTitle(selection)) · Command-Shift-\(selection.shortcutLabel)")
    .accessibilityLabel("\(ownerTrayTitle(selection)), \(count) items")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  private func ownerTrayCount(_ selection: OwnerTraySelection) -> Int {
    switch selection {
    case .attention: attentionCount
    case .motion: inMotionCount
    case .delivered: deliveredCount
    }
  }

  @ViewBuilder
  private func contextualDrawer(compact: Bool) -> some View {
    if let traySelection {
      drawerPlacement(compact: compact) {
        ownerDrawer(traySelection)
      }
      .transition(drawerTransition(compact: compact))
    } else if showsEmployeeDrawer,
      !compact || hasExplicitlyOpenedEmployeeDrawer,
      let employee = selectedEmployee
    {
      drawerPlacement(compact: compact) {
        employeeDrawer(employee, compact: compact)
      }
      .transition(drawerTransition(compact: compact))
    }
  }

  private func isEmployeeDrawerPresented(compact: Bool) -> Bool {
    showsEmployeeDrawer
      && traySelection == nil
      && (!compact || hasExplicitlyOpenedEmployeeDrawer)
      && selectedEmployee != nil
  }

  private func drawerPlacement<Content: View>(compact: Bool, @ViewBuilder content: () -> Content)
    -> some View
  {
    Group {
      if compact {
        content()
          .frame(maxWidth: 500, maxHeight: 420)
          .padding(.horizontal, 16)
          .padding(.bottom, 82)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
      } else {
        content()
          .frame(width: 356)
          .frame(maxHeight: 760)
          .padding(.trailing, 28)
          .padding(.vertical, 30)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      }
    }
  }

  private func employeeDrawer(_ employee: Employee, compact: Bool) -> some View {
    ScrollView {
      editorialEmployeeFolio(employee, compact: compact)
    }
    .scrollIndicators(.hidden)
    .background(EditorialOfficeTheme.paper)
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(EditorialOfficeTheme.ink.opacity(0.28), lineWidth: 1)
    }
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .shadow(color: EditorialOfficeTheme.sidebarInk.opacity(0.24), radius: 22, x: 7, y: 14)
    .accessibilityFocused($drawerAccessibilityFocus, equals: .employee)
    .accessibilityLabel("\(employee.name)'s profile folio")
  }

  private func editorialEmployeeFolio(_ employee: Employee, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ZStack(alignment: .topTrailing) {
        HStack(spacing: 16) {
          EmployeePortrait(
            employee: employee,
            size: CGSize(width: compact ? 86 : 104, height: compact ? 86 : 104)
          )
          .saturation(0)
          .contrast(1.14)

          VStack(alignment: .leading, spacing: 4) {
            Text(employee.name)
              .font(.system(size: compact ? 27 : 32, weight: .regular, design: .serif))
            Text(employee.role)
              .font(.body)
              .foregroundStyle(EditorialOfficeTheme.graphite)
            Label(employeeStatusLabel(employee), systemImage: "circle.fill")
              .font(.caption)
              .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.82))
              .padding(.top, 3)
          }

          Spacer(minLength: 28)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 18)

        Button {
          animateSelection { showsEmployeeDrawer = false }
          drawerAccessibilityFocus = nil
        } label: {
          Image(systemName: "xmark")
            .font(.system(size: 16, weight: .regular))
            .frame(width: 38, height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(EditorialOfficeTheme.ink)
        .help("Close employee folio")
        .accessibilityLabel("Close \(employee.name)'s profile")
        .padding(8)
      }

      VStack(alignment: .leading, spacing: 12) {
        folioRule
        if employee.kind == .ai {
          if employee.id == "nia" {
            niaResearchFolio(employee)
          } else if employee.id == "iris" {
            irisDutyFolio(employee, compact: compact)
          } else {
            employeeOutcomeFolio(employee)
          }
          folioRule
        }
        folioSection("Current duty", value: currentDuty(for: employee))
        folioRule
        folioSection("Responsible for", value: employee.responsibility)
        folioRule
        folioSection("Working with", value: collaborators(for: employee))
        folioRule
        folioSection("Skills", value: skills(for: employee))
        folioRule
        folioSection("Blocker", value: blocker(for: employee))

        Button {
          onOpenEmployeeProfile(employee.id)
        } label: {
          Label("Open full profile", systemImage: "arrow.up.forward.square")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(EditorialPrimaryButtonStyle())
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 22)
    }
    .foregroundStyle(EditorialOfficeTheme.ink)
  }

  @ViewBuilder
  private func niaResearchFolio(_ employee: Employee) -> some View {
    Text("RESEARCH DESK")
      .font(.caption2.weight(.semibold))
      .tracking(0.8)
      .foregroundStyle(EditorialOfficeTheme.graphite)

    if let assignment = model.latestResearchAssignment {
      ResearchDeskCard(
        assignment: assignment,
        onNewAssignment: { showsResearchAssignment = true }
      )
      .environmentObject(model)
    } else {
      ResearchDeskEmptyCard {
        showsResearchAssignment = true
      }
    }

    otherOutcomeSection(employee)
  }

  /// A specialist's general-outcome section, shown beneath whatever bespoke
  /// duty or assignment card that specialist has.
  @ViewBuilder
  private func otherOutcomeSection(_ employee: Employee) -> some View {
    if model.latestEmployeeOutcome(for: employee.id) != nil {
      Text("OTHER OUTCOME")
        .font(.caption2.weight(.semibold))
        .tracking(0.8)
        .foregroundStyle(EditorialOfficeTheme.graphite)
        .padding(.top, 2)
      employeeOutcomeFolio(employee)
    } else {
      Button {
        outcomeEmployee = employee
      } label: {
        Label("Give \(employee.name) a general outcome", systemImage: "arrow.up.right")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(EditorialSecondaryButtonStyle())
      .disabled(!model.canCreateEmployeeOutcome)
      .accessibilityLabel("Give \(employee.name) a general outcome")
    }
  }

  @ViewBuilder
  private func irisDutyFolio(_ employee: Employee, compact: Bool) -> some View {
    Text("CUSTOMER VOICE DUTY")
      .font(.caption2.weight(.semibold))
      .tracking(0.8)
      .foregroundStyle(EditorialOfficeTheme.graphite)

    if let duty = model.customerVoiceDuty {
      CustomerVoiceDutyCard(duty: duty, compact: compact)
        .environmentObject(model)
    }

    otherOutcomeSection(employee)
  }

  @ViewBuilder
  private func employeeOutcomeFolio(_ employee: Employee) -> some View {
    if employee.effectiveEmploymentState == .paused {
      VStack(alignment: .leading, spacing: 9) {
        Label("Employment paused", systemImage: "pause.circle").font(.callout.weight(.semibold))
        Text(
          "Queued commitments are preserved, but no new ticket will begin until you resume this employee."
        ).font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
        Button("Resume \(employee.name)") { model.resumeEmployee(employee.id) }.buttonStyle(
          EditorialPrimaryButtonStyle())
      }
    } else if let outcome = model.latestEmployeeOutcome(for: employee.id) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: employeeOutcomeIcon(outcome.status))
            .font(.caption)
          Text(employeeOutcomeLabel(outcome.status))
            .font(.caption.weight(.medium))
          Spacer()
          if !outcome.taskIDs.isEmpty {
            Text("\(completedTicketCount(outcome))/\(outcome.taskIDs.count) tickets")
              .font(.caption2)
              .foregroundStyle(EditorialOfficeTheme.graphite)
          }
        }

        if let help = outcome.helpRequest, !help.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text("NEEDS YOU")
              .font(.caption2.weight(.semibold))
              .tracking(0.8)
            Text(help)
              .font(.caption)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(EditorialOfficeTheme.softGrey.opacity(0.72))
          .overlay { Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1) }
        }

        Text(outcome.outcome)
          .font(.system(.title3, design: .serif, weight: .regular))
          .fixedSize(horizontal: false, vertical: true)

        if !outcome.taskIDs.isEmpty {
          outcomePlanStrip(outcome)
        }

        if !outcome.selectedSkillIDs.isEmpty {
          Text(
            outcome.selectedSkillIDs.compactMap { model.organization.skill($0)?.name }.joined(
              separator: " · ")
          )
          .font(.caption)
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .lineLimit(2)
        }

        if outcome.helpRequest == nil, let delivery = outcome.deliverySummary {
          Text(delivery)
            .font(.caption)
            .foregroundStyle(EditorialOfficeTheme.graphite)
            .fixedSize(horizontal: false, vertical: true)
        }

        employeeOutcomeActions(outcome, employee: employee)
      }
    } else {
      VStack(alignment: .leading, spacing: 9) {
        Text(
          "Give \(employee.name) a result to own. They will choose from their skills, create the tickets, work through them, and ask when they need you."
        )
        .font(.callout)
        .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.78))
        .fixedSize(horizontal: false, vertical: true)
        Button {
          outcomeEmployee = employee
        } label: {
          Label("Give an outcome", systemImage: "arrow.up.right")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(EditorialPrimaryButtonStyle())
        .disabled(!model.canCreateEmployeeOutcome)
        .accessibilityLabel("Give \(employee.name) an outcome")
      }
    }
  }

  private func outcomePlanStrip(_ outcome: EmployeeOutcome) -> some View {
    let tasks = outcome.taskIDs.compactMap(model.organization.task)
    let next = tasks.first { $0.status != .done }
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text("PLAN")
          .font(.caption2.weight(.semibold))
          .tracking(0.8)
        Spacer()
        Text("\(completedTicketCount(outcome)) of \(tasks.count)")
          .font(.caption2)
          .foregroundStyle(EditorialOfficeTheme.graphite)
      }
      if let next {
        Text(next.title)
          .font(.caption.weight(.medium))
          .lineLimit(2)
      } else {
        Text("All tickets delivered")
          .font(.caption.weight(.medium))
      }
      Button("View plan in Mission", action: onOpenMission)
        .buttonStyle(.plain)
        .font(.caption.weight(.medium))
        .underline()
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(EditorialOfficeTheme.bone.opacity(0.58))
    .overlay { Rectangle().stroke(EditorialOfficeTheme.rule.opacity(0.74), lineWidth: 1) }
  }

  @ViewBuilder
  private func employeeOutcomeActions(_ outcome: EmployeeOutcome, employee: Employee) -> some View {
    switch outcome.status {
    case .planning, .working, .revision:
      HStack(spacing: 8) {
        ProgressView().controlSize(.small)
        Text(outcome.status == .planning ? "Planning the work" : "Working through the plan")
          .font(.caption)
          .foregroundStyle(EditorialOfficeTheme.graphite)
        Spacer()
        Button("Stop") { pendingStopOutcomeID = outcome.id }
          .buttonStyle(.plain)
          .font(.caption.weight(.medium))
      }
    case .queued, .approved:
      HStack(spacing: 8) {
        Text(
          model.runningEmployeeIDs.count >= model.organization.effectiveConcurrencyLimit
            ? "Waiting for capacity" : "Queued for this employee"
        )
        .font(.caption).foregroundStyle(EditorialOfficeTheme.graphite)
        Spacer()
        Button("Stop") { pendingStopOutcomeID = outcome.id }.buttonStyle(.plain).font(
          .caption.weight(.medium))
      }
    case .proposed:
      Button("Review plan in Mission", action: onOpenMission).buttonStyle(
        EditorialPrimaryButtonStyle())
    case .waiting, .failed:
      HStack(spacing: 8) {
        Button("Respond in Mission", action: onOpenMission).buttonStyle(
          EditorialPrimaryButtonStyle())
        Button("Stop") { pendingStopOutcomeID = outcome.id }
          .buttonStyle(EditorialSecondaryButtonStyle())
      }
    case .delivered:
      HStack(spacing: 8) {
        if let artifactID = outcome.artifactIDs.last, let artifact = model.artifact(artifactID) {
          Button("Open delivery") { model.reveal(artifact) }.buttonStyle(
            EditorialSecondaryButtonStyle())
        }
        Button("Review delivery", action: onOpenMission).buttonStyle(EditorialPrimaryButtonStyle())
      }
    case .accepted, .closed, .cancelled:
      HStack(spacing: 8) {
        if let artifactID = outcome.artifactIDs.last,
          let artifact = model.artifact(artifactID)
        {
          Button("Open delivery") { model.reveal(artifact) }
            .buttonStyle(EditorialSecondaryButtonStyle())
        }
        Button("Give another outcome") { outcomeEmployee = employee }
          .buttonStyle(EditorialPrimaryButtonStyle())
          .disabled(!model.canCreateEmployeeOutcome)
          .accessibilityLabel("Give \(employee.name) another outcome")
      }
    }
  }

  private func completedTicketCount(_ outcome: EmployeeOutcome) -> Int {
    outcome.taskIDs.compactMap(model.organization.task).filter { $0.status == .done }.count
  }

  private var outcomeOfficePrompt: String {
    if let decision = model.organization.managementInbox.first,
      let employee = model.organization.employee(decision.employeeID)
    {
      return "\(employee.name) needs you: \(decision.title)."
    }
    if model.organization.activeAIEmployees.isEmpty {
      return "Hire an employee from the Company Library to open the office."
    }
    if let outcome = model.activeEmployeeOutcome,
      let employee = model.organization.employee(outcome.assigneeID)
    {
      return outcome.status == .waiting
        ? "\(employee.name) needs your help. Select them to respond."
        : "\(employee.name) owns the current outcome. Select them to inspect the plan."
    }
    if model.canCreateEmployeeOutcome {
      return "Choose a person to give the next outcome."
    }
    return "Select a person to inspect their work."
  }

  private func employeeOutcomeLabel(_ status: EmployeeOutcomeStatus) -> String {
    switch status {
    case .queued: "Queued outcome"
    case .planning: "Planning outcome"
    case .proposed: "Plan awaiting review"
    case .approved: "Plan approved"
    case .working: "Outcome in motion"
    case .waiting: "Waiting for help"
    case .delivered: "Outcome delivered"
    case .revision: "Revision in motion"
    case .accepted: "Outcome accepted"
    case .closed: "Outcome closed"
    case .failed: "Outcome needs a retry"
    case .cancelled: "Outcome stopped"
    }
  }

  private func employeeOutcomeIcon(_ status: EmployeeOutcomeStatus) -> String {
    switch status {
    case .queued: "clock"
    case .planning: "list.bullet.clipboard"
    case .proposed: "checklist"
    case .approved: "checkmark.seal"
    case .working: "arrow.forward"
    case .waiting: "questionmark.bubble"
    case .delivered: "checkmark"
    case .revision: "arrow.counterclockwise"
    case .accepted: "checkmark.seal.fill"
    case .closed: "archivebox"
    case .failed: "exclamationmark"
    case .cancelled: "stop"
    }
  }

  private var folioRule: some View {
    Rectangle()
      .fill(EditorialOfficeTheme.rule.opacity(0.8))
      .frame(height: 1)
  }

  private func folioSection(_ title: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption.weight(.medium))
      Text(value)
        .font(.callout)
        .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.78))
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private func currentDuty(for employee: Employee) -> String {
    if let taskID = employee.currentTaskID,
      let task = model.organization.task(taskID)
    {
      return task.title
    }
    if employee.id == "iris", let duty = model.customerVoiceDuty {
      return duty.title
    }
    return employee.status == .resting ? "Desk is clear" : employee.status.rawValue.capitalized
  }

  private func collaborators(for employee: Employee) -> String {
    var names: [String] = []
    if let managerID = employee.managerID {
      names.append(model.employeeName(managerID))
    }
    names.append(
      contentsOf: model.organization.employees
        .filter { $0.managerID == employee.id }
        .map(\.name))
    if let humanID = employee.assistantForHumanID {
      names.append(model.employeeName(humanID))
    }
    var seen = Set<String>()
    let unique = names.filter { seen.insert($0).inserted }
    return unique.isEmpty ? "The wider team" : unique.joined(separator: " · ")
  }

  private func skills(for employee: Employee) -> String {
    let assigned = model.organization.assignedSkills(employeeID: employee.id).map(\.name)
    return assigned.isEmpty ? "No assigned skills yet" : assigned.prefix(5).joined(separator: ", ")
  }

  private func blocker(for employee: Employee) -> String {
    model.organization.blockers.first(where: { !$0.resolved && $0.employeeID == employee.id })?
      .title ?? "None"
  }

  private func ownerDrawer(_ selection: OwnerTraySelection) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(ownerTrayTitle(selection), systemImage: selection.icon)
          .font(.system(.headline, design: .rounded, weight: .bold))
          .foregroundStyle(selection.tint)
        Spacer()
        Button {
          animateSelection { traySelection = nil }
          drawerAccessibilityFocus = nil
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink.opacity(0.5))
        .help("Close \(selection.title)")
        .accessibilityLabel("Close \(selection.title)")
      }

      ScrollView {
        switch selection {
        case .attention:
          attentionContent
        case .motion:
          motionContent
        case .delivered:
          deliveredContent
        }
      }
      .scrollIndicators(.hidden)
    }
    .padding(16)
    .padding(.leading, 18)
    .modifier(DeskFolioSurface(binding: selection.tint))
    .accessibilityFocused($drawerAccessibilityFocus, equals: .ownerTray)
    .accessibilityLabel(ownerTrayTitle(selection))
  }

  @ViewBuilder
  private var attentionContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(model.organization.managementInbox.prefix(8)) { item in
        AttentionRow(
          title: item.title,
          detail: item.consequence,
          buttonTitle: item.kind == .candidate ? "Review candidate" : "Manage in Mission"
        ) {
          if item.kind == .candidate { showsCompanyLibrary = true } else { onOpenMission() }
        }
      }
      if !model.organization.hasMeaningfulProductBrief {
        AttentionRow(
          title: "Maya needs the real product story",
          detail: "Add the audience, problem, and claims the team may safely make.",
          buttonTitle: "Write the brief"
        ) {
          productBriefDraft = model.organization.productBrief
          showsProductBrief = true
        }
      }

      if model.webResearchRequestPending
        || (model.organization.executionMode == .localCodex && !model.webResearchGranted)
      {
        AttentionRow(
          title: "Nia is asking for the library key",
          detail:
            "Grant read-only web research. Publishing and external writes remain unavailable.",
          buttonTitle: "Grant web research"
        ) {
          model.setWebResearchGranted(true)
        }
      }

      if customerVoiceNeedsAttention {
        AttentionRow(
          title: model.customerVoiceOccurrence?.status == .blocked
            ? "Iris needs help with the feedback inbox"
            : "Iris's weekly reading is ready",
          detail: model.customerVoiceOccurrence?.blockingReason
            ?? "Add this week's notes, then ask Iris for one cited owner decision.",
          buttonTitle: "Open feedback inbox"
        ) {
          model.revealFeedbackInbox()
        }
      }

      ForEach(additionalUnresolvedBlockers) { blocker in
        AttentionRow(
          title: blocker.title,
          detail: "\(blocker.detail) Asked by \(model.employeeName(blocker.employeeID)).",
          buttonTitle: nil,
          action: nil
        )
      }

      if attentionCount == 0 {
        EmptyDrawerState(
          icon: "checkmark.seal.fill",
          title: "Nothing is waiting on you",
          detail: "The team has what it needs right now."
        )
      }
    }
  }

  @ViewBuilder
  private var motionContent: some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(inMotionOutcomes) { outcome in
        if let employee = model.organization.employee(outcome.assigneeID) {
          StatusLine(
            icon: outcome.status == .planning ? "list.bullet.clipboard" : "arrow.forward",
            title: "\(employee.name) · \(outcome.status.rawValue.capitalized)",
            detail: outcome.outcome
          )
        }
      }
      if inMotionCount == 0 {
        EmptyDrawerState(
          icon: "cup.and.saucer.fill",
          title: "The office is resting",
          detail: "Give a hired employee an outcome to create the next commitment."
        )
      }
    }
  }

  @ViewBuilder
  private var deliveredContent: some View {
    VStack(alignment: .leading, spacing: 3) {
      if deliveredOutcomes.isEmpty {
        EmptyDrawerState(
          icon: "doc.text.fill",
          title: "Nothing delivered yet",
          detail: "Accepted employee outcomes will collect here."
        )
      } else {
        ForEach(deliveredOutcomes.suffix(8).reversed()) { outcome in
          StatusLine(
            icon: "checkmark.seal.fill",
            title:
              "\(model.employeeName(outcome.assigneeID)) · \(outcome.status.rawValue.capitalized)",
            detail: outcome.effectiveDeliveries.last?.summary ?? outcome.outcome
          )
        }
      }
    }
  }

  private var selectedEmployee: Employee? {
    model.organization.employee(model.selectedEmployeeID ?? "")
  }

  private var aiEmployees: [Employee] {
    model.organization.activeAIEmployees
  }

  private var customerVoiceNeedsAttention: Bool {
    model.customerVoiceOccurrence?.status == .blocked
      || model.customerVoiceOccurrence?.status == .queued
      || (model.customerVoiceOccurrence == nil
        && (model.customerVoiceDuty?.nextDueAt ?? .distantFuture) <= Date())
  }

  private var attentionCount: Int {
    var count = model.organization.managementInbox.count
    if !model.organization.hasMeaningfulProductBrief { count += 1 }
    if model.webResearchRequestPending
      || (model.organization.executionMode == .localCodex && !model.webResearchGranted)
    {
      count += 1
    }
    if customerVoiceNeedsAttention { count += 1 }
    count += additionalUnresolvedBlockers.count
    return count
  }

  private var additionalUnresolvedBlockers: [Blocker] {
    let inbox = model.organization.managementInbox
    let representedTaskIDs = Set(
      inbox.compactMap(\.taskID)
        + inbox.compactMap(\.outcomeID).flatMap { outcomeID in
          model.organization.employeeOutcome(outcomeID)?.taskIDs ?? []
        })
    return model.organization.blockers.filter {
      !$0.resolved && !representedTaskIDs.contains($0.taskID)
    }
  }

  private var inMotionCount: Int {
    inMotionOutcomes.count
  }

  private var deliveredCount: Int {
    deliveredOutcomes.count
  }

  private var inMotionOutcomes: [EmployeeOutcome] {
    model.organization.employeeOutcomes.filter {
      [.queued, .planning, .approved, .working, .revision].contains($0.status)
    }
  }

  private var deliveredOutcomes: [EmployeeOutcome] {
    model.organization.employeeOutcomes.filter {
      [.accepted, .closed].contains($0.status)
    }
  }

  private func ownerTrayTitle(_ selection: OwnerTraySelection) -> String {
    if selection == .attention, model.organization.workdayStatus == .complete {
      return "For tomorrow"
    }
    return selection.title
  }

  private var sceneAccessibilitySummary: String {
    model.organization.employees.map { employee in
      let task = model.taskTitle(employee.currentTaskID).map { " on \($0)" } ?? ""
      return "\(employee.name) is \(employee.status.rawValue)\(task)"
    }.joined(separator: ". ")
  }

  private func selectEmployee(_ employeeID: String) {
    animateSelection {
      model.selectedEmployeeID = employeeID
      traySelection = nil
      showsEmployeeDrawer = true
      hasExplicitlyOpenedEmployeeDrawer = true
    }
    drawerAccessibilityFocus = .employee
  }

  private func animateSelection(_ changes: () -> Void) {
    if reduceMotion {
      changes()
    } else {
      withAnimation(.snappy(duration: 0.24), changes)
    }
  }

  private func drawerTransition(compact: Bool) -> AnyTransition {
    reduceMotion
      ? .opacity
      : .move(edge: compact ? .bottom : .trailing).combined(with: .opacity)
  }

  private func employeeStatusLabel(_ employee: Employee) -> String {
    if employee.id == "iris", employee.status == .working { return "Reading customer notes" }
    if let task = model.taskTitle(employee.currentTaskID) { return task }
    return employee.status.rawValue.capitalized
  }
}

private enum DrawerAccessibilityFocus: Hashable {
  case employee
  case ownerTray
}

private enum OwnerTraySelection: String, CaseIterable, Identifiable {
  case attention
  case motion
  case delivered

  var id: String { rawValue }

  var title: String {
    switch self {
    case .attention: "Needs you"
    case .motion: "In motion"
    case .delivered: "Delivered"
    }
  }

  var compactTitle: String {
    switch self {
    case .attention: "Needs"
    case .motion: "Moving"
    case .delivered: "Done"
    }
  }

  var shortcutLabel: String {
    switch self {
    case .attention: "1"
    case .motion: "2"
    case .delivered: "3"
    }
  }

  var icon: String {
    switch self {
    case .attention: "hand.raised.fill"
    case .motion: "figure.walk.motion"
    case .delivered: "checkmark.seal.fill"
    }
  }

  var tint: Color {
    switch self {
    case .attention: DawnStageTheme.amber
    case .motion: DawnStageTheme.mint
    case .delivered: Color(hex: "6CB5F3")
    }
  }

  var shortcut: KeyEquivalent {
    switch self {
    case .attention: "n"
    case .motion: "m"
    case .delivered: "d"
    }
  }
}

private struct StatusLine: View {
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 9) {
      Image(systemName: icon)
        .foregroundStyle(DawnStageTheme.steel)
        .frame(width: 19)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.caption.weight(.semibold))
        Text(detail)
          .font(.caption2)
          .foregroundStyle(DawnStageTheme.steel)
          .lineLimit(2)
      }
      Spacer()
    }
    .padding(.vertical, 7)
  }
}

private struct AttentionRow: View {
  let title: String
  let detail: String
  let buttonTitle: String?
  let action: (() -> Void)?

  init(title: String, detail: String, buttonTitle: String?, action: (() -> Void)?) {
    self.title = title
    self.detail = detail
    self.buttonTitle = buttonTitle
    self.action = action
  }

  init(title: String, detail: String, buttonTitle: String, action: @escaping () -> Void) {
    self.init(
      title: title, detail: detail, buttonTitle: Optional(buttonTitle), action: Optional(action))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.callout.weight(.bold))
      Text(detail)
        .font(.caption)
        .foregroundStyle(DawnStageTheme.steel)
        .fixedSize(horizontal: false, vertical: true)
      if let buttonTitle, let action {
        Button(buttonTitle, action: action)
          .buttonStyle(.bordered)
          .tint(DawnStageTheme.coral)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(DawnStageTheme.hairline)
        .frame(height: 1)
    }
  }
}

private struct EmptyDrawerState: View {
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(DawnStageTheme.mint)
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.callout.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(DawnStageTheme.steel)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
  }
}

private struct DeskFolioSurface: ViewModifier {
  let binding: Color

  func body(content: Content) -> some View {
    content
      .background {
        RoundedRectangle(cornerRadius: 14)
          .fill(DawnStageTheme.backstage.opacity(0.97))
          .shadow(color: .black.opacity(0.42), radius: 20, x: 0, y: 12)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 14)
          .stroke(DawnStageTheme.hairline, lineWidth: 1)
          .allowsHitTesting(false)
      }
      .overlay(alignment: .top) {
        Rectangle()
          .fill(binding.opacity(0.9))
          .frame(height: 2)
          .padding(.horizontal, 16)
          .allowsHitTesting(false)
      }
  }
}

private struct ProductBriefSheet: View {
  @Binding var brief: String
  let onSave: () -> Void
  let onReveal: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 5) {
          Text("The product story")
            .font(.system(.title, design: .rounded, weight: .bold))
          Text(
            "Maya treats this as company truth. Give her the product, audience, problem, and only claims she can safely make."
          )
          .font(.callout)
          .foregroundStyle(DawnStageTheme.steel)
        }
        Spacer()
        Image(systemName: "book.closed.fill")
          .font(.title2)
          .foregroundStyle(DawnStageTheme.coral)
      }

      TextEditor(text: $brief)
        .font(.body.monospaced())
        .accessibilityLabel("Company product brief")
        .scrollContentBackground(.hidden)
        .padding(14)
        .foregroundStyle(DawnStageTheme.ivory)
        .background(DawnStageTheme.proscenium.opacity(0.62), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(DawnStageTheme.hairline, lineWidth: 1)
        }

      HStack {
        Button("Open company folder", action: onReveal)
          .buttonStyle(.plain)
          .foregroundStyle(DawnStageTheme.steel)
        Spacer()
        Text(briefStatus)
          .font(.caption)
          .foregroundStyle(briefIsMeaningful ? DawnStageTheme.mint : DawnStageTheme.amber)
        Button("Save brief", action: onSave)
          .buttonStyle(StagePrimaryButtonStyle(tint: DawnStageTheme.mint))
          .disabled(!briefIsMeaningful)
      }
    }
    .padding(26)
    .frame(minWidth: 520, idealWidth: 640, minHeight: 500, idealHeight: 560)
    .foregroundStyle(DawnStageTheme.ivory)
    .background(DawnStageTheme.pageField)
  }

  private var briefIsMeaningful: Bool {
    OrganizationState.isMeaningfulProductBrief(brief)
  }

  private var briefStatus: String {
    let count = brief.trimmingCharacters(in: .whitespacesAndNewlines).count
    return briefIsMeaningful
      ? "Ready for the team · \(count) characters"
      : "Replace the starter prompts · \(count)/120+ characters"
  }
}

extension Color {
  init(hex: String) {
    let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: clean).scanHexInt64(&value)
    let red = Double((value >> 16) & 0xFF) / 255
    let green = Double((value >> 8) & 0xFF) / 255
    let blue = Double(value & 0xFF) / 255
    self.init(red: red, green: green, blue: blue)
  }
}
