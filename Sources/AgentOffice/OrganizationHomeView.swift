import AgentOfficeCore
import SwiftUI

struct OrganizationHomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var outcomeDraft = ""

    private let spruce = Color(hex: "173B3A")
    private let ink = Color(hex: "263238")
    private let plaster = Color(hex: "F4E6C9")
    private let paper = Color(hex: "FFF8E8")
    private let apricot = Color(hex: "E78B5B")

    var body: some View {
        HStack(spacing: 0) {
            employeeSidebar
                .frame(width: 220)

            Divider().overlay(Color.black.opacity(0.12))

            VStack(spacing: 0) {
                dayHeader
                office
                activityShelf
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider().overlay(Color.black.opacity(0.12))

            workRail
                .frame(width: 340)
        }
        .background(plaster)
        .foregroundStyle(ink)
        .onAppear { outcomeDraft = model.organization.outcome }
        .onChange(of: model.organization.outcome) { _, value in
            if outcomeDraft != value { outcomeDraft = value }
        }
        .alert("The team needs attention", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("Okay", role: .cancel) { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }

    private var employeeSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 9) {
                    Image(systemName: "house.and.flag.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "F2C96D"))
                    Text(model.organization.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                Text(model.organization.workdayStatus == .active ? "The office is awake" : "A quiet little company")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.68))
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 22)

            Text("YOUR TEAM")
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(Color.white.opacity(0.52))
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 5) {
                ForEach(model.organization.employees) { employee in
                    EmployeeRow(
                        employee: employee,
                        taskTitle: model.taskTitle(employee.currentTaskID),
                        selected: model.selectedEmployeeID == employee.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { model.selectedEmployeeID = employee.id }
                    .accessibilityAddTraits(model.selectedEmployeeID == employee.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 9)

            if let selected = model.organization.employees.first(where: { $0.id == model.selectedEmployeeID }) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(selected.responsibility)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    if let managerID = selected.managerID {
                        Label("Reports to \(model.employeeName(managerID))", systemImage: "arrow.turn.up.right")
                            .font(.caption2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 13))
                .padding(12)
            }

            Spacer()

            VStack(spacing: 8) {
                Button(action: model.chooseOrganizationFolder) {
                    Label("Choose company folder", systemImage: "folder.badge.gearshape")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help("Choose where organization state and employee work are stored")

                Button(action: model.revealOrganizationFolder) {
                    Label("Open local files", systemImage: "arrow.up.forward.square")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .help(model.organizationURL.path)
            }
            .font(.caption)
            .foregroundStyle(Color.white.opacity(0.72))
            .padding(18)
        }
        .background(spruce)
        .foregroundStyle(.white)
    }

    private var dayHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(dayGreeting)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    TextField("What outcome should the team own?", text: $outcomeDraft, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .foregroundStyle(ink.opacity(0.78))
                        .lineLimit(2...3)
                        .onSubmit { model.updateOutcome(outcomeDraft) }
                        .onChange(of: outcomeDraft) { _, value in
                            if value != model.organization.outcome { model.updateOutcome(value) }
                        }
                        .accessibilityLabel("Organization outcome")
                }

                Spacer(minLength: 16)

                Menu {
                    Button {
                        model.setExecutionMode(.demo)
                    } label: {
                        Label("Demo", systemImage: model.organization.executionMode == .demo ? "checkmark" : "sparkles")
                    }
                    Button {
                        model.setExecutionMode(.localCodex)
                    } label: {
                        Label("Local Codex", systemImage: model.organization.executionMode == .localCodex ? "checkmark" : "cpu")
                    }
                    .disabled(!model.codexAvailable)
                } label: {
                    Label(
                        model.organization.executionMode == .demo ? "Demo team" : "Local Codex",
                        systemImage: model.organization.executionMode == .demo ? "sparkles" : "cpu"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 32)
                    .background(Color.white.opacity(0.58), in: RoundedRectangle(cornerRadius: 9))
                }
                .menuStyle(.borderlessButton)
                .tint(ink)
                .fixedSize()
                .disabled(model.organization.workdayStatus == .active)
                .accessibilityLabel("Employee runner")
                .help(model.codexAvailable
                    ? "Choose deterministic demo work or the locally authenticated Codex CLI"
                    : "Local Codex was not found; Demo mode is available")

                Button(action: model.toggleDay) {
                    Label(
                        dayButtonTitle,
                        systemImage: model.organization.workdayStatus == .active
                            ? "moon.stars.fill"
                            : (model.organization.workdayStatus == .complete ? "checkmark.circle.fill" : "sun.max.fill")
                    )
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 34)
                    .background(
                        model.organization.workdayStatus == .active
                            ? apricot
                            : (model.organization.workdayStatus == .complete ? Color(hex: "6E8B62") : spruce),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .shadow(color: .black.opacity(0.14), radius: 7, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(model.organization.workdayStatus == .complete)
                .keyboardShortcut(.return, modifiers: [.command])
                .accessibilityLabel(dayButtonTitle)
                .help(model.organization.workdayStatus == .active
                    ? "Stop before the next work step and save progress"
                    : "Wake the team and begin the next available work")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(paper)
    }

    private var office: some View {
        OfficeSceneView(organization: model.organization)
            .overlay(alignment: .topLeading) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(model.organization.workdayStatus == .active ? Color(hex: "6E8B62") : ink.opacity(0.35))
                        .frame(width: 8, height: 8)
                    Text(model.organization.workdayStatus == .active ? "Everyone is working" : "Office resting")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(paper.opacity(0.92), in: Capsule())
                .shadow(color: .black.opacity(0.16), radius: 8, y: 4)
                .padding(14)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Living office. \(sceneAccessibilitySummary)")
            .background(Color(hex: "33271F"))
    }

    private var activityShelf: some View {
        HStack(spacing: 12) {
            Image(systemName: "quote.bubble.fill")
                .foregroundStyle(apricot)
            if let latest = model.organization.activity.last {
                Text("\(model.employeeName(latest.actorID)): \(latest.message)")
                    .font(.callout)
                    .lineLimit(2)
            } else {
                Text("The office is ready.")
                    .font(.callout)
            }
            Spacer()
            Text("Day \(max(model.organization.dayNumber, 1))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink.opacity(0.55))
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 54)
        .background(paper)
    }

    private var workRail: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                RailSection(title: "Goal", systemImage: "flag.fill") {
                    ForEach(model.organization.goals) { goal in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(goal.title)
                                .font(.headline)
                            Text(goal.detail)
                                .font(.caption)
                                .foregroundStyle(ink.opacity(0.66))
                            ProgressView(value: goal.progress)
                                .tint(spruce)
                            Text("\(Int(goal.progress * 100))% of today's outcome")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(spruce)
                        }
                    }
                }

                RailSection(title: "Blockers", systemImage: "pin.fill") {
                    let openBlockers = model.organization.blockers.filter { !$0.resolved }
                    if openBlockers.isEmpty {
                        Label("Nothing needs you right now", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(Color(hex: "55764F"))
                    } else {
                        ForEach(openBlockers) { blocker in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(blocker.title).font(.callout.weight(.bold))
                                Text(blocker.detail).font(.caption)
                                Text("Asked by \(model.employeeName(blocker.employeeID))")
                                    .font(.caption2.weight(.semibold))
                            }
                            .padding(11)
                            .background(Color(hex: "F7D7B9"), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                RailSection(title: "Task board", systemImage: "list.bullet.rectangle.portrait.fill") {
                    taskGroup("Ready", statuses: [.ready, .waiting])
                    taskGroup("In motion", statuses: [.doing, .revision])
                    taskGroup("Review & done", statuses: [.review, .done, .blocked])
                }

                if !model.organization.artifacts.isEmpty {
                    RailSection(title: "Artifacts", systemImage: "doc.text.fill") {
                        ForEach(model.organization.artifacts.suffix(4).reversed()) { artifact in
                            Button {
                                model.reveal(artifact)
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: "doc.richtext")
                                        .foregroundStyle(apricot)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(artifact.title)
                                            .font(.caption.weight(.semibold))
                                            .lineLimit(1)
                                        Text("\(model.employeeName(artifact.authorID)) · \(artifact.kind.rawValue.capitalized)")
                                            .font(.caption2)
                                            .foregroundStyle(ink.opacity(0.55))
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.square")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Reveal \(artifact.relativePath) in Finder")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(hex: "F0DFC0"))
    }

    @ViewBuilder
    private func taskGroup(_ title: String, statuses: Set<TaskStatus>) -> some View {
        let tasks = model.organization.tasks.filter { statuses.contains($0.status) }
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ink.opacity(0.5))
                ForEach(tasks) { task in
                    TaskCard(task: task, employeeName: model.employeeName(task.assigneeID))
                }
            }
        }
    }

    private var dayGreeting: String {
        switch model.organization.workdayStatus {
        case .active: "Day \(model.organization.dayNumber) is underway"
        case .complete: "The team wrapped up"
        case .ending: "The office is winding down"
        case .resting: "Good morning, founder"
        }
    }

    private var dayButtonTitle: String {
        switch model.organization.workdayStatus {
        case .active, .ending: "End Day"
        case .complete: "Day Complete"
        case .resting: "Start Day"
        }
    }

    private var sceneAccessibilitySummary: String {
        model.organization.employees.map { employee in
            let task = model.taskTitle(employee.currentTaskID).map { " on \($0)" } ?? ""
            return "\(employee.name) is \(employee.status.rawValue)\(task)"
        }.joined(separator: ". ")
    }
}

private struct EmployeeRow: View {
    let employee: Employee
    let taskTitle: String?
    let selected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color(hex: employee.avatarColor))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Text(String(employee.name.prefix(1)))
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(Color(hex: "263238"))
                    }
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(Color(hex: "173B3A"), lineWidth: 2))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(employee.name)
                    .font(.system(.callout, design: .rounded, weight: .bold))
                Text(taskTitle ?? employee.role)
                    .font(.caption2)
                    .foregroundStyle(Color.white.opacity(0.58))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(selected ? Color.white.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(employee.name), \(employee.role), \(employee.status.rawValue)")
    }

    private var statusColor: Color {
        switch employee.status {
        case .blocked: Color(hex: "C95F4B")
        case .resting: Color.white.opacity(0.4)
        case .waiting: Color(hex: "F2C96D")
        default: Color(hex: "82A879")
        }
    }
}

private struct RailSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label(title, systemImage: systemImage)
                .font(.system(.headline, design: .rounded, weight: .bold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TaskCard: View {
    let task: WorkTask
    let employeeName: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Text(employeeName)
                    Text("·")
                    Text(statusLabel)
                }
                .font(.caption2)
                .foregroundStyle(Color(hex: "263238").opacity(0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(task.title), \(statusLabel), assigned to \(employeeName)")
    }

    private var icon: String {
        switch task.status {
        case .done: "checkmark.circle.fill"
        case .review: "eye.circle.fill"
        case .revision: "arrow.triangle.2.circlepath.circle.fill"
        case .blocked: "exclamationmark.circle.fill"
        case .doing: "pencil.circle.fill"
        case .ready: "play.circle.fill"
        case .waiting: "clock.fill"
        }
    }

    private var tint: Color {
        switch task.status {
        case .done: Color(hex: "6E8B62")
        case .blocked: Color(hex: "C95F4B")
        case .review, .revision: Color(hex: "E78B5B")
        default: Color(hex: "7395A8")
        }
    }

    private var statusLabel: String {
        switch task.status {
        case .doing: "Working"
        case .review: "With manager"
        case .revision: "Revising"
        case .done: "Done"
        case .blocked: "Blocked"
        case .ready: "Ready"
        case .waiting: "Waiting"
        }
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
