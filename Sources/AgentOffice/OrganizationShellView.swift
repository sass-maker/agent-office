import AgentOfficeCore
import SwiftUI

enum OrganizationDestination: String, CaseIterable, Identifiable {
  case office = "Office"
  case mission = "Mission"
  case company = "Company"

  var id: String { rawValue }

  var icon: String {
    switch self {
    case .office: "building.2"
    case .mission: "scope"
    case .company: "person.2"
    }
  }

  var shortcut: KeyEquivalent {
    switch self {
    case .office: "1"
    case .mission: "2"
    case .company: "3"
    }
  }

  var shortcutLabel: String {
    switch self {
    case .office: "1"
    case .mission: "2"
    case .company: "3"
    }
  }
}

struct OrganizationShellView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var destination: OrganizationDestination = .office
  @State private var hasUnsavedChanges = false
  @State private var requestedEmployeeID: String?

  var body: some View {
    GeometryReader { proxy in
      let compactSidebar = proxy.size.width < 820

      HStack(spacing: 0) {
        editorialSidebar(compact: compactSidebar)
          .frame(width: compactSidebar ? 118 : 148)

        Group {
          switch destination {
          case .office:
            OrganizationHomeView(
              showsCommandShelf: false,
              onOpenEmployeeProfile: openEmployeeProfile,
              onOpenMission: { open(.mission) }
            )
          case .mission:
            MissionView(
              onOpenOffice: { open(.office) },
              onOpenEmployeeProfile: openEmployeeProfile,
              onDirtyChange: { hasUnsavedChanges = $0 }
            )
          case .company:
            CompanyView(
              onOpenOffice: { open(.office) },
              onDirtyChange: { hasUnsavedChanges = $0 },
              initialEmployeeID: requestedEmployeeID
            )
          }
        }
        .id("\(destination.rawValue)-\(requestedEmployeeID ?? "root")")
        .transition(reduceMotion ? .identity : .opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(destination.rawValue) destination")
      }
    }
    .background(EditorialOfficeTheme.bone)
    .alert(
      "The team needs attention",
      isPresented: Binding(
        get: { model.lastError != nil },
        set: { if !$0 { model.lastError = nil } }
      )
    ) {
      if destination != .office {
        Button("See the office") {
          model.lastError = nil
          open(.office)
        }
      }
      Button("Okay", role: .cancel) { model.lastError = nil }
    } message: {
      Text(model.lastError ?? "")
    }
  }

  private func editorialSidebar(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 6) {
        Text(model.organization.name)
          .font(.system(compact ? .title3 : .title2, design: .serif, weight: .regular))
          .foregroundStyle(EditorialOfficeTheme.onInk)
          .lineLimit(compact ? 2 : 3)
          .minimumScaleFactor(0.82)

        if !compact {
          Text(companyStatus)
            .font(.caption2)
            .foregroundStyle(EditorialOfficeTheme.sidebarMuted.opacity(0.78))
            .lineLimit(2)
        }
      }
      .padding(.top, 66)
      .padding(.horizontal, compact ? 16 : 22)
      .padding(.bottom, compact ? 32 : 42)

      VStack(spacing: 2) {
        ForEach(OrganizationDestination.allCases) { item in
          destinationButton(item, compact: compact)
        }
      }

      Spacer(minLength: 24)

      Rectangle()
        .fill(EditorialOfficeTheme.graphite.opacity(0.55))
        .frame(height: 1)
        .padding(.horizontal, compact ? 14 : 20)
        .padding(.bottom, 18)

      workControl(compact: compact)

      Menu {
        Button(
          "Open company folder", systemImage: "arrow.up.forward.square",
          action: model.revealOrganizationFolder)
        Button(
          "Move company home", systemImage: "folder.badge.gearshape",
          action: model.chooseOrganizationFolder
        )
        .disabled(
          model.organization.workdayStatus == .active || model.isEmployeeRunActive
            || hasUnsavedChanges)
        Divider()
        Button(
          "Welcome and setup", systemImage: "door.left.hand.open", action: model.revisitOnboarding
        )
        .disabled(
          model.organization.workdayStatus == .active || model.isEmployeeRunActive
            || hasUnsavedChanges)
      } label: {
        Group {
          if compact {
            VStack(spacing: 4) {
              Image(systemName: "ellipsis")
              Text("Settings")
                .font(.caption2)
            }
          } else {
            HStack(spacing: 8) {
              Image(systemName: "ellipsis")
              Text("Company settings")
            }
          }
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(EditorialOfficeTheme.onInk.opacity(0.82))
        .frame(maxWidth: .infinity, minHeight: 36, alignment: compact ? .center : .leading)
        .padding(.horizontal, compact ? 10 : 21)
        .background(EditorialOfficeTheme.onInk.opacity(0.04))
        .contentShape(Rectangle())
      }
      .menuIndicator(.hidden)
      .buttonStyle(.plain)
      .tint(EditorialOfficeTheme.onInk)
      .fixedSize(horizontal: false, vertical: true)
      .help("Company settings")
      .accessibilityLabel("Company settings")
      .padding(.bottom, 16)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(EditorialOfficeTheme.sidebarInk)
  }

  private func destinationButton(_ item: OrganizationDestination, compact: Bool) -> some View {
    let selected = destination == item
    return Button {
      requestedEmployeeID = nil
      open(item)
    } label: {
      Group {
        if compact {
          VStack(spacing: 6) {
            Image(systemName: item.icon)
              .font(.system(size: 17, weight: .regular))
              .frame(height: 20)
            Text(item.rawValue)
              .font(.caption.weight(selected ? .semibold : .regular))
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity)
        } else {
          HStack(spacing: 12) {
            Image(systemName: item.icon)
              .font(.system(size: 17, weight: .regular))
              .frame(width: 24)
            Text(item.rawValue)
              .font(.system(.body, design: .default, weight: selected ? .medium : .regular))
              .lineLimit(1)
              .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
          }
        }
      }
      .foregroundStyle(selected ? EditorialOfficeTheme.onInk : EditorialOfficeTheme.sidebarMuted)
      .padding(.horizontal, compact ? 10 : 21)
      .frame(maxWidth: .infinity, minHeight: 66, alignment: compact ? .center : .leading)
      .background(selected ? Color.white.opacity(0.055) : Color.clear)
      .overlay(alignment: .leading) {
        Rectangle()
          .fill(selected ? EditorialOfficeTheme.onInk : Color.clear)
          .frame(width: 3)
      }
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(selected ? EditorialOfficeTheme.onInk.opacity(0.74) : Color.clear)
          .frame(height: 2)
          .padding(.horizontal, compact ? 31 : 60)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(hasUnsavedChanges && item != destination)
    .keyboardShortcut(item.shortcut, modifiers: [.command])
    .help(
      hasUnsavedChanges && item != destination
        ? "Save the current edits before leaving \(destination.rawValue)."
        : "Open \(item.rawValue) · Command-\(item.shortcutLabel)"
    )
    .accessibilityLabel(item.rawValue)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }

  @ViewBuilder
  private func workControl(compact: Bool) -> some View {
    if model.organization.workdayStatus == .complete {
      VStack(alignment: compact ? .center : .leading, spacing: 5) {
        Image(
          systemName: model.canCreateEmployeeOutcome
            ? "person.crop.circle.badge.plus" : "checkmark.circle"
        )
        .font(.title3)
        Text(model.canCreateEmployeeOutcome ? "Office ready" : "Work complete")
          .font(compact ? .caption2 : .callout)
          .multilineTextAlignment(compact ? .center : .leading)
      }
      .foregroundStyle(EditorialOfficeTheme.sidebarMuted)
      .frame(maxWidth: .infinity, minHeight: 58, alignment: compact ? .center : .leading)
      .padding(.horizontal, compact ? 8 : 21)
      .help(
        model.canCreateEmployeeOutcome
          ? "The first mission is complete. Choose an employee in the Office for the next outcome."
          : "The bounded workflow is complete. Review Mission or delivered work.")
    } else {
      Button(action: model.toggleDay) {
        VStack(alignment: compact ? .center : .leading, spacing: 6) {
          Image(
            systemName: model.organization.workdayStatus == .active
              ? "calendar.badge.clock" : "calendar"
          )
          .font(.title3)
          Text(model.organization.workdayStatus == .active ? "End Day" : "Start Day")
            .font(compact ? .caption2 : .callout)
        }
        .foregroundStyle(EditorialOfficeTheme.onInk)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: compact ? .center : .leading)
        .padding(.horizontal, compact ? 8 : 21)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(
        hasUnsavedChanges
          || (model.isEmployeeRunActive && model.organization.workdayStatus != .active)
      )
      .help(
        hasUnsavedChanges
          ? "Save the current edits before starting work."
          : (model.organization.workdayStatus == .active ? "End Day" : "Start Day")
      )
      .accessibilityLabel(model.organization.workdayStatus == .active ? "End Day" : "Start Day")
      .accessibilityHint(
        hasUnsavedChanges
          ? "Save the current edits before changing the workday."
          : "Updates the shared workday state."
      )
      .keyboardShortcut(.return, modifiers: [.command])
    }
  }

  private func openEmployeeProfile(_ employeeID: String) {
    requestedEmployeeID = employeeID
    open(.company)
  }

  private func open(_ item: OrganizationDestination) {
    guard !hasUnsavedChanges || item == destination else { return }
    if reduceMotion {
      destination = item
    } else {
      withAnimation(.easeOut(duration: 0.16)) { destination = item }
    }
  }

  private var companyStatus: String {
    if model.isCustomerVoiceRunning { return "Iris is reading customer notes" }
    if model.latestResearchAssignment?.status == .researching { return "Nia is researching" }
    return switch model.organization.workdayStatus {
    case .active, .ending: "The team is working"
    case .complete:
      model.canCreateEmployeeOutcome
        ? "Ready for the next outcome" : "The first mission is complete"
    case .resting: "The office is resting"
    }
  }
}
