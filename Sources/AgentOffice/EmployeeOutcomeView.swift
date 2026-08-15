import AgentOfficeCore
import SwiftUI

struct EmployeeOutcomeAssignmentSheet: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  let employee: Employee

  @State private var outcome = ""
  @State private var context = ""
  @State private var submissionError: String?
  @FocusState private var focusedField: Field?

  private var skills: [SkillDefinition] {
    model.organization.assignedSkills(employeeID: employee.id)
  }

  var body: some View {
    HStack(spacing: 0) {
      identityPanel
        .frame(width: 224)

      VStack(alignment: .leading, spacing: 22) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 5) {
            Text("Assign an outcome")
              .font(.system(size: 30, weight: .regular, design: .serif))
            Text("Give \(employee.name) the result. They decide the process.")
              .font(.callout)
              .foregroundStyle(EditorialOfficeTheme.graphite)
          }
          Spacer()
          Button("Cancel") { dismiss() }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }

        field(
          title: "Outcome",
          prompt: "What should be true when \(employee.name) is finished?",
          text: $outcome,
          lineLimit: 2...4,
          field: .outcome
        )

        field(
          title: "Context",
          optional: true,
          prompt: "Constraints, source material, audience, or the decision this should support",
          text: $context,
          lineLimit: 3...6,
          field: .context
        )

        VStack(alignment: .leading, spacing: 10) {
          Text("HOW THIS EMPLOYEE WILL WORK")
            .font(.caption2.weight(.medium))
            .tracking(1.2)
          workRule("Plan", "Choose assigned skills and create up to four tickets.")
          workRule("Execute", "Produce local artifacts through the current employee runner.")
          workRule("Communicate", "Report progress, delivery, or one precise request for help.")
        }
        .padding(.vertical, 2)

        if let submissionError {
          HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle")
            Text(submissionError)
              .font(.caption)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(11)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(EditorialOfficeTheme.softGrey.opacity(0.7))
          .overlay { Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1) }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Assignment needs attention. \(submissionError)")
        } else if skills.isEmpty {
          Text(
            "\(employee.name) needs at least one skill before assignment. Review their skills in Company."
          )
          .font(.caption)
          .foregroundStyle(EditorialOfficeTheme.graphite)
          .fixedSize(horizontal: false, vertical: true)
        }

        HStack(alignment: .center, spacing: 14) {
          Image(systemName: model.organization.executionMode == .demo ? "theatermasks" : "cpu")
            .font(.title3)
          VStack(alignment: .leading, spacing: 2) {
            Text(
              model.organization.executionMode == .demo
                ? "Practice with the Demo team" : "Work with Local Codex"
            )
            .font(.callout.weight(.medium))
            Text(
              "No self-granted permissions, publishing, spending, or writes outside this company folder."
            )
            .font(.caption)
            .foregroundStyle(EditorialOfficeTheme.graphite)
          }
          Spacer(minLength: 12)
          Button("Assign to \(employee.name)") { submit() }
            .buttonStyle(EditorialPrimaryButtonStyle())
            .disabled(trimmedOutcome.isEmpty || skills.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 2)
      }
      .padding(28)
    }
    .frame(minWidth: 640, idealWidth: 760, minHeight: 540, idealHeight: 580)
    .background(EditorialOfficeTheme.paper)
    .foregroundStyle(EditorialOfficeTheme.ink)
    .onAppear { focusedField = .outcome }
  }

  private var identityPanel: some View {
    VStack(alignment: .leading, spacing: 0) {
      EmployeePortrait(employee: employee, size: CGSize(width: 136, height: 136))
        .saturation(0)
        .contrast(1.16)
        .padding(.bottom, 20)

      Text(employee.name)
        .font(.system(size: 27, weight: .regular, design: .serif))
      Text(employee.role)
        .font(.callout)
        .foregroundStyle(Color.white.opacity(0.68))
        .padding(.top, 3)

      Rectangle()
        .fill(Color.white.opacity(0.22))
        .frame(height: 1)
        .padding(.vertical, 18)

      Text("AVAILABLE SKILLS")
        .font(.caption2.weight(.medium))
        .tracking(1.2)
        .foregroundStyle(Color.white.opacity(0.58))
        .padding(.bottom, 10)

      ForEach(skills.prefix(6)) { skill in
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Image(systemName: skill.id == "communication" ? "quote.bubble" : "checkmark")
            .font(.caption2)
            .frame(width: 12)
          Text(skill.name)
            .font(.caption)
            .lineLimit(1)
        }
        .padding(.vertical, 4)
      }

      Spacer()

      Text(
        "These are instructions, not permissions. \(employee.name) can ask for access but cannot grant it."
      )
      .font(.caption)
      .foregroundStyle(Color.white.opacity(0.6))
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(24)
    .foregroundStyle(EditorialOfficeTheme.onInk)
    .background(EditorialOfficeTheme.sidebarInk)
  }

  private func field(
    title: String,
    optional: Bool = false,
    prompt: String,
    text: Binding<String>,
    lineLimit: ClosedRange<Int>,
    field: Field
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 7) {
        Text(title).font(.headline)
        if optional {
          Text("OPTIONAL")
            .font(.caption2.weight(.medium))
            .foregroundStyle(EditorialOfficeTheme.graphite)
        }
      }
      TextField("", text: text, prompt: Text(prompt), axis: .vertical)
        .textFieldStyle(.plain)
        .font(.body)
        .lineLimit(lineLimit)
        .padding(14)
        .background(EditorialOfficeTheme.bone.opacity(0.72))
        .overlay { Rectangle().stroke(EditorialOfficeTheme.rule, lineWidth: 1) }
        .focused($focusedField, equals: field)
        .accessibilityLabel(title)
        .accessibilityHint(prompt)
    }
  }

  private func workRule(_ title: String, _ detail: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title)
        .font(.callout.weight(.medium))
        .frame(width: 92, alignment: .leading)
      Text(detail)
        .font(.callout)
        .foregroundStyle(EditorialOfficeTheme.graphite)
      Spacer(minLength: 0)
    }
    .padding(.vertical, 7)
    .overlay(alignment: .bottom) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.64)).frame(height: 1)
    }
  }

  private var trimmedOutcome: String {
    outcome.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func submit() {
    submissionError = nil
    Task {
      guard
        await model.submitEmployeeOutcome(
          employeeID: employee.id, outcome: outcome, context: context)
      else {
        submissionError = model.lastError ?? "This outcome could not be assigned."
        model.lastError = nil
        return
      }
      dismiss()
    }
  }

  private enum Field {
    case outcome
    case context
  }
}
