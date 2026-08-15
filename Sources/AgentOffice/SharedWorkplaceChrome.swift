import AgentOfficeCore
import SwiftUI

/// The confirmation shown before stopping an employee's outcome.
///
/// Office and Mission both offer this, and the copy is a promise about what
/// survives — so it lives in one place rather than being restated per surface.
private struct StopOutcomeConfirmation: ViewModifier {
  @EnvironmentObject private var model: AppModel
  @Binding var pendingOutcomeID: String?

  func body(content: Content) -> some View {
    content.confirmationDialog(
      "Stop this employee outcome?",
      isPresented: Binding(
        get: { pendingOutcomeID != nil },
        set: { if !$0 { pendingOutcomeID = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("Stop outcome", role: .destructive) {
        if let outcomeID = pendingOutcomeID { model.stopEmployeeOutcome(outcomeID) }
        pendingOutcomeID = nil
      }
      Button("Keep working", role: .cancel) { pendingOutcomeID = nil }
    } message: {
      Text(
        "The employee's plan, completed tickets, deliveries, and activity will remain in the organization history."
      )
    }
  }
}

/// The shared look of a desk-bar control: quiet until selected, then filled with
/// a rule beneath it.
private struct DeskBarButtonChrome: ViewModifier {
  var selected: Bool
  var compact: Bool
  var minWidth: CGFloat?

  func body(content: Content) -> some View {
    content
      .foregroundStyle(EditorialOfficeTheme.ink)
      .padding(.horizontal, compact ? 5 : 8)
      .frame(minWidth: minWidth, minHeight: 44, alignment: minWidth == nil ? .center : .leading)
      .background(selected ? EditorialOfficeTheme.softGrey.opacity(0.76) : Color.clear)
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(selected ? EditorialOfficeTheme.ink : Color.clear)
          .frame(height: 2)
      }
      .contentShape(Rectangle())
  }
}

extension View {
  func stopOutcomeConfirmation(_ pendingOutcomeID: Binding<String?>) -> some View {
    modifier(StopOutcomeConfirmation(pendingOutcomeID: pendingOutcomeID))
  }

  func deskBarButtonChrome(selected: Bool, compact: Bool, minWidth: CGFloat? = nil) -> some View {
    modifier(DeskBarButtonChrome(selected: selected, compact: compact, minWidth: minWidth))
  }
}
