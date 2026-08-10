import AgentOfficeCore
import SwiftUI

struct CustomerVoiceDutyCard: View {
    @EnvironmentObject private var model: AppModel

    let duty: EmployeeDuty
    var compact = false
    var onClose: (() -> Void)?

    private let ink = EditorialOfficeTheme.ink
    private let spruce = EditorialOfficeTheme.sidebarInk
    private let moss = EditorialOfficeTheme.graphite
    private let apricot = EditorialOfficeTheme.graphite
    private let paper = EditorialOfficeTheme.paper

    private var occurrence: DutyOccurrence? {
        model.customerVoiceOccurrence
    }

    private var analyst: Employee? {
        model.organization.employee(duty.assigneeID)
    }

    private var reviewer: Employee? {
        model.organization.employee(duty.reviewerID)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                header(at: context.date)

                if !compact {
                    Text(duty.responsibility)
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)

                    Divider().overlay(spruce.opacity(0.12))
                }

                scheduleAndCoverage(at: context.date)

                if let reason = occurrence?.blockingReason {
                    Label(reason, systemImage: "pin.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ink.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(EditorialOfficeTheme.softGrey, in: RoundedRectangle(cornerRadius: 9))
                        .accessibilityLabel("Customer Voice blocker. \(reason)")
                }

                Label(
                    "Reads only .txt, .md, and .csv files you place in this company's feedback inbox. Nothing is sent or changed.",
                    systemImage: "lock.doc.fill"
                )
                .font(.caption2)
                .foregroundStyle(spruce.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

                actions
            }
        }
        .padding(compact ? 12 : 15)
        .background(paper, in: RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(spruce.opacity(0.48), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.24), radius: 9, y: 5)
        .accessibilityElement(children: .contain)
    }

    private func header(at date: Date) -> some View {
        HStack(alignment: .top, spacing: 11) {
            if let analyst {
                EmployeePortrait(employee: analyst, size: CGSize(width: 44, height: 53))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(duty.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("You → \(reviewer?.name ?? duty.reviewerID) → \(analyst?.name ?? duty.assigneeID)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(spruce.opacity(0.76))
            }

            Spacer(minLength: 8)

            Text(statusTitle(at: date))
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor(at: date))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(statusColor(at: date).opacity(0.13), in: Capsule())
                .accessibilityLabel("Duty status: \(statusTitle(at: date))")

            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ink.opacity(0.52))
                .help("Close Iris's desk")
                .accessibilityLabel("Close Iris's desk")
            }
        }
    }

    private func scheduleAndCoverage(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(moss)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly responsibility")
                        .font(.caption.weight(.semibold))
                    Text(nextDueText(at: date))
                        .font(.caption2)
                        .foregroundStyle(ink.opacity(0.72))
                }
            }
            .accessibilityElement(children: .combine)

            if let occurrence, !occurrence.includedInputs.isEmpty || !occurrence.excludedInputs.isEmpty {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "tray.full.fill")
                        .foregroundStyle(apricot)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Latest inbox snapshot")
                            .font(.caption.weight(.semibold))
                        Text("\(occurrence.includedInputs.count) included · \(occurrence.excludedInputs.count) left out")
                            .font(.caption2)
                            .foregroundStyle(ink.opacity(0.72))
                        if !occurrence.includedInputs.isEmpty {
                            Text(occurrence.includedInputs.map(\.fileName).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(ink.opacity(0.78))
                                .lineLimit(2)
                        }
                        if !occurrence.excludedInputs.isEmpty {
                            DisclosureGroup("Show what was left out") {
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(occurrence.excludedInputs) { exclusion in
                                        Text("\(exclusion.fileName) — \(exclusion.reason)")
                                            .font(.caption2)
                                            .foregroundStyle(ink.opacity(0.76))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(spruce)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { actionButtons }
            VStack(alignment: .leading, spacing: 8) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: model.revealFeedbackInbox) {
            Label("Add feedback", systemImage: "folder.badge.plus")
                .frame(minHeight: 34)
        }
        .buttonStyle(.bordered)
        .tint(spruce)
        .help("Reveal the company's bounded local feedback inbox")

        if model.isCustomerVoiceRunning {
            Button(action: model.stopCustomerVoiceDuty) {
                Label("Stop", systemImage: "pause.fill")
                    .frame(minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(apricot)
            .keyboardShortcut(.escape, modifiers: [])
        } else {
            Button(action: model.runCustomerVoiceDuty) {
                Label(runButtonTitle, systemImage: "play.fill")
                    .frame(minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(spruce)
            .disabled(!model.canRunCustomerVoiceDuty)
            .help(model.canRunCustomerVoiceDuty
                ? "Run this occurrence while the app is open"
                : "Finish the current employee work first")
        }

        if let brief = model.artifact(occurrence?.briefArtifactID) {
            Button {
                model.reveal(brief)
            } label: {
                Label("Open latest brief", systemImage: "doc.text.magnifyingglass")
                    .frame(minHeight: 34)
            }
            .buttonStyle(.bordered)
            .help("Reveal Iris's latest brief")
        }
    }

    private func statusTitle(at date: Date) -> String {
        guard let occurrence else {
            return duty.nextDueAt <= date ? "Due now" : "Upcoming"
        }
        return switch occurrence.status {
        case .running: "Iris is reading"
        case .blocked: "Needs attention"
        case .queued: "Ready to resume"
        case .delivered: duty.nextDueAt <= date ? "Due again" : "Delivered"
        case .cancelled: "Stopped"
        }
    }

    private func statusColor(at date: Date) -> Color {
        switch occurrence?.status {
        case .running: moss
        case .blocked: apricot
        case .queued: EditorialOfficeTheme.graphite
        case .delivered: moss
        case .cancelled: ink.opacity(0.76)
        case nil: duty.nextDueAt <= date ? apricot : spruce
        }
    }

    private var runButtonTitle: String {
        switch occurrence?.status {
        case .blocked, .queued: "Retry"
        default: "Run now"
        }
    }

    private func nextDueText(at date: Date) -> String {
        if duty.nextDueAt <= date {
            return "Due now · runs only when you ask"
        }
        return "Next due \(duty.nextDueAt.formatted(date: .abbreviated, time: .omitted))"
    }
}
