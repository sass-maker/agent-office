import AgentOfficeCore
import SwiftUI

struct ResearchAssignmentSheet: View {
  /// Every research assignment is created for Nia, so the sheet describes her
  /// resolved runtime.
  static let assigneeID = "nia"

  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var outcome = ""
  @State private var context = ""
  @FocusState private var focusedField: Field?

  private let ink = EditorialOfficeTheme.ink
  private let spruce = EditorialOfficeTheme.controlInk
  private let paper = EditorialOfficeTheme.paper
  private let plaster = EditorialOfficeTheme.bone
  private let apricot = EditorialOfficeTheme.graphite

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      HStack(alignment: .top, spacing: 18) {
        if let mira = model.organization.employee("mira"),
          let nia = model.organization.employee("nia")
        {
          HStack(spacing: -7) {
            EmployeePortrait(employee: mira, size: CGSize(width: 38, height: 46))
              .zIndex(1)
            EmployeePortrait(employee: nia, size: CGSize(width: 38, height: 46))
          }
          .padding(6)
          .background(EditorialOfficeTheme.softGrey, in: RoundedRectangle(cornerRadius: 14))
        }

        VStack(alignment: .leading, spacing: 5) {
          Text("Give Nia a research assignment")
            .font(.system(.title2, design: .rounded, weight: .bold))
          Text(
            "Mira will frame the request, Nia will research it, and the result stays in this company folder."
          )
          .font(.callout)
          .foregroundStyle(ink.opacity(0.65))
          .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 12)

        Button("Cancel") { dismiss() }
          .buttonStyle(.plain)
          .font(.callout.weight(.semibold))
          .foregroundStyle(spruce)
          .keyboardShortcut(.cancelAction)
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("What should Nia find out?")
          .font(.headline)
        TextField(
          "",
          text: $outcome,
          prompt: Text("For example: Compare how three products onboard a new team")
            .foregroundStyle(ink.opacity(0.52)),
          axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.body)
        .lineLimit(2...4)
        .padding(14)
        .background(
          EditorialOfficeTheme.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 11)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 11)
            .stroke(spruce.opacity(0.18), lineWidth: 1)
        }
        .accessibilityLabel("Research outcome")
        .focused($focusedField, equals: .outcome)
      }

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Useful context")
            .font(.headline)
          Text("Optional")
            .font(.caption.weight(.semibold))
            .foregroundStyle(ink.opacity(0.45))
        }
        TextField(
          "",
          text: $context,
          prompt: Text(
            "Audience, constraints, products to include, or the decision this should support"
          )
          .foregroundStyle(ink.opacity(0.52)),
          axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.body)
        .lineLimit(3...5)
        .padding(14)
        .background(
          EditorialOfficeTheme.paper.opacity(0.68), in: RoundedRectangle(cornerRadius: 11)
        )
        .overlay {
          RoundedRectangle(cornerRadius: 11)
            .stroke(ink.opacity(0.12), lineWidth: 1)
        }
        .accessibilityLabel("Research context")
        .focused($focusedField, equals: .context)
      }

      HStack(alignment: .top, spacing: 12) {
        Image(systemName: modeIcon)
          .font(.title3)
          .foregroundStyle(apricot)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 3) {
          Text(notice.title)
            .font(.callout.weight(.bold))
          Text(notice.detail)
            .font(.caption)
            .foregroundStyle(ink.opacity(0.62))
        }
      }
      .padding(13)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(plaster.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))

      HStack {
        Label("You → Mira → Nia", systemImage: "person.2.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(spruce.opacity(0.68))
        Spacer()
        Button("Send to Mira") { submit() }
          .buttonStyle(.plain)
          .font(.body.weight(.bold))
          .foregroundStyle(EditorialOfficeTheme.onInk)
          .padding(.horizontal, 17)
          .frame(minHeight: 38)
          .background(EditorialOfficeTheme.sidebarInk, in: RoundedRectangle(cornerRadius: 10))
          .disabled(trimmedOutcome.isEmpty)
          .opacity(trimmedOutcome.isEmpty ? 0.45 : 1)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(26)
    .frame(minWidth: 520, idealWidth: 620, minHeight: 480, idealHeight: 520)
    .foregroundStyle(ink)
    .tint(spruce)
    .background(paper)
    .onAppear { focusedField = .outcome }
  }

  private var trimmedOutcome: String {
    outcome.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// What this assignment will actually run on, resolved for the assignee every
  /// research assignment is created with.
  ///
  /// Read from the runtime policy rather than the organization-wide execution
  /// mode, which called a contract-driven real run a rehearsal and could never
  /// name Claude Code.
  private var notice: RuntimeNotice {
    model.runtimeDisposition(for: Self.assigneeID)
      .researchNotice(
        employeeName: model.employeeName(Self.assigneeID),
        webResearchGranted: model.webResearchGranted
      )
  }

  private var modeIcon: String {
    switch notice.standing {
    case .blocked: "exclamationmark.triangle.fill"
    case .rehearsal: "theatermasks.fill"
    case .real: "globe.americas.fill"
    }
  }

  private func submit() {
    guard model.submitResearchAssignment(outcome: outcome, context: context) else { return }
    dismiss()
  }

  private enum Field {
    case outcome
    case context
  }
}

struct ResearchDeskCard: View {
  @EnvironmentObject private var model: AppModel
  @AccessibilityFocusState private var statusFocused: Bool
  let assignment: ResearchAssignment
  let onNewAssignment: () -> Void

  private let ink = EditorialOfficeTheme.ink
  private let spruce = EditorialOfficeTheme.controlInk
  private let paper = EditorialOfficeTheme.paper

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 9) {
        Image(systemName: statusIcon)
          .foregroundStyle(statusColor)
        Text(statusTitle)
          .font(.caption.weight(.bold))
          .foregroundStyle(statusColor)
        Spacer()
        Text("You → Mira → Nia")
          .font(.caption2.weight(.bold))
          .foregroundStyle(spruce.opacity(0.46))
      }

      Text(assignment.outcome)
        .font(.system(.headline, design: .rounded, weight: .bold))
        .fixedSize(horizontal: false, vertical: true)

      if !assignment.context.isEmpty {
        Text(assignment.context)
          .font(.caption)
          .foregroundStyle(ink.opacity(0.62))
          .lineLimit(3)
      }

      if let reason = assignment.blockingReason, !reason.isEmpty {
        Label(reason, systemImage: "exclamationmark.bubble.fill")
          .font(.caption)
          .foregroundStyle(EditorialOfficeTheme.ink)
          .fixedSize(horizontal: false, vertical: true)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(EditorialOfficeTheme.softGrey, in: RoundedRectangle(cornerRadius: 9))
      }

      if let evidenceLabel {
        Label(evidenceLabel, systemImage: evidenceIcon)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(ink.opacity(0.55))
      }

      Divider().opacity(0.45)
      actions
    }
    .padding(15)
    .background(paper, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(statusColor.opacity(0.2), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.12), radius: 9, y: 5)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Research assignment. \(statusTitle). \(assignment.outcome)")
    .accessibilityFocused($statusFocused)
    .onChange(of: assignment.status) { _, status in
      if status == .waiting || status.isTerminal { statusFocused = true }
    }
  }

  @ViewBuilder
  private var actions: some View {
    switch assignment.status {
    case .researching:
      HStack(spacing: 9) {
        ProgressView().controlSize(.small)
        Text("Nia is working. This will be saved locally.")
          .font(.caption)
          .foregroundStyle(ink.opacity(0.58))
        Spacer()
        Button("Stop") { model.cancelResearchAssignment(assignment.id) }
          .buttonStyle(.plain)
          .font(.caption.weight(.bold))
          .foregroundStyle(EditorialOfficeTheme.ink)
      }
    case .queued:
      if model.organization.workdayStatus == .active {
        HStack(spacing: 9) {
          ProgressView().controlSize(.small)
          Text("Nia is getting started.")
            .font(.caption)
            .foregroundStyle(ink.opacity(0.58))
        }
      } else {
        actionButton(
          assignment.blockingReason == nil ? "Begin research" : "Resume research",
          icon: assignment.blockingReason == nil ? "play.fill" : "arrow.clockwise"
        ) {
          model.retryResearchAssignment(assignment.id)
        }
      }
    case .waiting:
      HStack(spacing: 8) {
        remedyButtons
        Spacer()
        Button("Stop assignment") { model.cancelResearchAssignment(assignment.id) }
          .buttonStyle(.plain)
          .font(.caption.weight(.semibold))
          .foregroundStyle(EditorialOfficeTheme.ink)
      }
    case .failed:
      HStack(spacing: 8) {
        actionButton("Try again", icon: "arrow.clockwise") {
          model.retryResearchAssignment(assignment.id)
        }
        Spacer()
        Button("New assignment", action: onNewAssignment)
          .buttonStyle(.plain)
          .font(.caption.weight(.semibold))
          .foregroundStyle(spruce)
      }
    case .delivered:
      HStack(spacing: 8) {
        if let brief = model.artifact(assignment.briefArtifactID) {
          actionButton("Nia's brief", icon: "doc.text.fill") { model.reveal(brief) }
        }
        if let delivery = model.artifact(assignment.deliveryArtifactID) {
          actionButton("Mira's note", icon: "checkmark.seal.fill") { model.reveal(delivery) }
        }
        Spacer(minLength: 2)
        Button("New assignment", action: onNewAssignment)
          .buttonStyle(.plain)
          .font(.caption.weight(.bold))
          .foregroundStyle(spruce)
      }
    case .cancelled:
      HStack {
        Text("Stopped without delivering work.")
          .font(.caption)
          .foregroundStyle(ink.opacity(0.58))
        Spacer()
        Button("New assignment", action: onNewAssignment)
          .buttonStyle(.plain)
          .font(.caption.weight(.bold))
          .foregroundStyle(spruce)
      }
    }
  }

  /// The controls a waiting assignment offers its owner, best remedy first.
  ///
  /// Each one is an action that can actually change the resolver's answer for
  /// this assignee. The card used to offer "Use a practice run" whenever the
  /// organization-wide mode said Codex and Codex was missing — an
  /// organization-wide question standing in for a refusal about one employee, so
  /// the escape hatch appeared for assignments that were not blocked and stayed
  /// hidden for the ones that were.
  @ViewBuilder
  private var remedyButtons: some View {
    let remedies = model.runtimeDisposition(
      for: assignment.assigneeID, commitmentID: assignment.canonicalOutcomeID
    ).waitingRemedies(webResearchGranted: model.webResearchGranted)
    ForEach(Array(remedies.enumerated()), id: \.offset) { _, remedy in
      remedyButton(remedy)
    }
  }

  @ViewBuilder
  private func remedyButton(_ remedy: RuntimeRemedy) -> some View {
    switch remedy {
    case .grantWebResearch:
      actionButton("Grant web research", icon: "key.fill") {
        model.setWebResearchGranted(true)
      }
    case .recheckRuntimeInstallations(let reason):
      actionButton("Check again", icon: "arrow.triangle.2.circlepath") {
        model.recheckAgentInstallations()
      }
      .help(reason)
    case .rehearseWholeOrganization:
      actionButton("Move everyone to a practice run", icon: "theatermasks.fill") {
        model.setExecutionMode(.demo)
      }
      .help(
        "Rewrites every hired employee's contract to Practice mode. To change one employee, edit their contract in Company."
      )
    case .retry:
      actionButton("Try again", icon: "arrow.clockwise") {
        model.retryResearchAssignment(assignment.id)
      }
    }
  }

  private func actionButton(_ title: String, icon: String, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      Label(title, systemImage: icon)
        .font(.caption.weight(.bold))
        .foregroundStyle(spruce)
        .padding(.horizontal, 10)
        .frame(minHeight: 34)
        .background(EditorialOfficeTheme.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private var statusTitle: String {
    switch assignment.status {
    case .queued: model.organization.workdayStatus == .active ? "Getting started" : "Ready to begin"
    case .waiting: "Waiting for you"
    case .researching: "Researching"
    case .delivered: "Delivered"
    case .failed: "Needs another attempt"
    case .cancelled: "Stopped"
    }
  }

  private var statusIcon: String {
    switch assignment.status {
    case .queued: "tray.full.fill"
    case .waiting: "hand.raised.fill"
    case .researching: "magnifyingglass"
    case .delivered: "checkmark.seal.fill"
    case .failed: "exclamationmark.triangle.fill"
    case .cancelled: "stop.circle.fill"
    }
  }

  private var statusColor: Color {
    switch assignment.status {
    case .queued, .researching: spruce
    case .waiting, .failed: EditorialOfficeTheme.ink
    case .delivered: EditorialOfficeTheme.graphite
    case .cancelled: ink.opacity(0.55)
    }
  }

  private var evidenceLabel: String? {
    switch assignment.evidenceBasis {
    case "synthetic-demo": "Practice run — no web sources"
    case "permitted-web-research": "Cited web research"
    default: nil
    }
  }

  private var evidenceIcon: String {
    assignment.evidenceBasis == "permitted-web-research" ? "link" : "theatermasks.fill"
  }
}

struct ResearchDeskEmptyCard: View {
  let action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "magnifyingglass.circle.fill")
          .font(.title2)
          .foregroundStyle(EditorialOfficeTheme.graphite)
        VStack(alignment: .leading, spacing: 2) {
          Text("Nia's desk is clear")
            .font(.system(.headline, design: .rounded, weight: .bold))
          Text("Give her one question worth answering.")
            .font(.caption)
            .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.62))
        }
      }
      Button(action: action) {
        Label("Ask Nia to research", systemImage: "arrow.right")
          .font(.caption.weight(.bold))
          .foregroundStyle(EditorialOfficeTheme.onInk)
          .padding(.horizontal, 11)
          .frame(minHeight: 31)
          .background(EditorialOfficeTheme.sidebarInk, in: RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    }
    .padding(15)
    .frame(maxWidth: .infinity, alignment: .leading)
    .foregroundStyle(EditorialOfficeTheme.ink)
    .background(EditorialOfficeTheme.paper, in: RoundedRectangle(cornerRadius: 14))
    .overlay {
      RoundedRectangle(cornerRadius: 14)
        .stroke(EditorialOfficeTheme.rule.opacity(0.7), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.12), radius: 9, y: 5)
  }
}
