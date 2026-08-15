import AgentOfficeCore
import SwiftUI

/// A temporal view across scheduled work.
///
/// A projection, never an author: an empty week is shown as an empty week
/// rather than a grid of imagined slots. Office remains the organization home
/// and Mission remains commitment supervision.
struct WorkCalendarView: View {
  enum Span: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"

    var id: String { rawValue }
    var days: Int { self == .day ? 1 : 7 }
  }

  @EnvironmentObject private var model: AppModel
  @State private var span: Span = .week
  @State private var anchor = Date()

  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < 1_020
      VStack(alignment: .leading, spacing: 0) {
        header(compact: compact)
        if days.isEmpty {
          emptyState(compact: compact)
        } else {
          ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
              ForEach(days) { day in dayGroup(day, compact: compact) }
            }
          }
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .background(EditorialOfficeTheme.workingField.ignoresSafeArea())
    .foregroundStyle(EditorialOfficeTheme.ink)
    // Scheduled work starts while the app is open, never behind its back.
    .task { await model.dispatchDueScheduledWork() }
  }

  private var days: [CalendarDay] {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: anchor)
    let end =
      calendar.date(byAdding: .day, value: span.days, to: start) ?? start.addingTimeInterval(86_400)
    return model.organization.calendarDays(from: start, through: end)
  }

  private func header(compact: Bool) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 14) {
      Text("Calendar")
        .font(.system(compact ? .title2 : .largeTitle, design: .serif, weight: .regular))

      Picker("Span", selection: $span) {
        ForEach(Span.allCases) { option in Text(option.rawValue).tag(option) }
      }
      .pickerStyle(.segmented)
      .frame(width: 160)
      .accessibilityLabel("Calendar span")

      Spacer(minLength: 0)

      Button("Earlier") { shift(by: -span.days) }
        .keyboardShortcut(.leftArrow, modifiers: [.command])
      Button("Today") { anchor = Date() }
      Button("Later") { shift(by: span.days) }
        .keyboardShortcut(.rightArrow, modifiers: [.command])
    }
    .buttonStyle(.bordered)
    .controlSize(.small)
    .padding(.horizontal, compact ? 24 : 38)
    .padding(.top, 34)
    .padding(.bottom, 14)
  }

  private func emptyState(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Nothing is scheduled in this period.")
        .font(.callout.weight(.medium))
      Text(
        "The calendar shows work that a schedule created. It does not invent blocks, and it never runs anything on its own."
      )
      .font(.caption)
      .foregroundStyle(EditorialOfficeTheme.graphite)
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, compact ? 24 : 38)
    .padding(.vertical, 12)
  }

  private func dayGroup(_ day: CalendarDay, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(day.date.formatted(date: .complete, time: .omitted))
        .font(.caption.weight(.semibold))
        .foregroundStyle(EditorialOfficeTheme.graphite)
        .padding(.horizontal, compact ? 24 : 38)
        .padding(.vertical, 8)

      ForEach(day.blocks) { block in blockRow(block, compact: compact) }
    }
    .overlay(alignment: .bottom) {
      Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.5)).frame(height: 1)
    }
  }

  private func blockRow(_ block: CalendarBlock, compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(block.window.start.formatted(date: .omitted, time: .shortened))
          .font(.caption.monospacedDigit())
          .foregroundStyle(EditorialOfficeTheme.graphite)
        Text(block.employeeName).font(.callout.weight(.medium))
        // Status is text, never colour alone.
        Text(block.statusLabel)
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(EditorialOfficeTheme.softGrey.opacity(0.7))
        Spacer(minLength: 0)
        if !block.status.isTerminal {
          Button("Skip") {
            Task { await model.skipScheduledOccurrence(block.id) }
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
          .accessibilityLabel("Skip \(block.employeeName)'s scheduled work")
        }
      }

      Text(expectationLine(block))
        .font(.caption)
        .foregroundStyle(EditorialOfficeTheme.graphite)
        .fixedSize(horizontal: false, vertical: true)

      if let headline = block.receiptHeadline {
        Text(headline)
          .font(.caption)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, compact ? 24 : 38)
    .padding(.bottom, 10)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(
      "\(block.employeeName), \(block.statusLabel), \(expectationLine(block))")
  }

  /// Expected work and actual work, stated separately.
  private func expectationLine(_ block: CalendarBlock) -> String {
    let planned =
      "Planned \(Int(block.window.duration / 60)) min from "
      + block.window.start.formatted(date: .omitted, time: .shortened)
    guard let actual = block.actual else { return planned + " · has not run" }
    let ran = actual.startedAt.formatted(date: .omitted, time: .shortened)
    guard let duration = actual.duration else { return planned + " · started \(ran)" }
    return planned + " · ran \(ran) for \(Int(duration / 60)) min"
  }

  private func shift(by days: Int) {
    anchor =
      Calendar.current.date(byAdding: .day, value: days, to: anchor) ?? anchor
  }
}
