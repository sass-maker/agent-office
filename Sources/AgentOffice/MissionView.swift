import AgentOfficeCore
import SwiftUI

struct MissionView: View {
    @EnvironmentObject private var model: AppModel
    @ScaledMetric(relativeTo: .largeTitle) private var missionTitleSize: CGFloat = 32
    @ScaledMetric(relativeTo: .title) private var inspectorTitleSize: CGFloat = 29
    let onOpenOffice: () -> Void
    let onOpenEmployeeProfile: (String) -> Void
    let onDirtyChange: (Bool) -> Void

    @State private var missionDraft = ""
    @State private var selectedTaskID: String?
    @State private var filter: MissionFilter = .all
    @State private var grouping: MissionGrouping = .status
    @State private var searchText = ""
    @State private var collapsedGroupIDs: Set<String> = []
    @State private var isSavingMission = false
    @State private var showsCompactInspector = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 1_020

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    missionHeader(compact: compact)
                    missionControls(compact: compact)
                    taskList(compact: compact)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !compact {
                    Rectangle()
                        .fill(EditorialOfficeTheme.rule.opacity(0.75))
                        .frame(width: 1)

                    if let task = selectedTask {
                        taskInspector(task)
                            .frame(width: min(370, proxy.size.width * 0.29))
                    } else {
                        emptyInspector
                            .frame(width: min(370, proxy.size.width * 0.29))
                    }
                }
            }
        }
        .background(EditorialOfficeTheme.workingField.ignoresSafeArea())
        .foregroundStyle(EditorialOfficeTheme.ink)
        .onAppear {
            missionDraft = model.organization.outcome
            selectedTaskID = preferredTask?.id
        }
        .onChange(of: model.organization.outcome) { _, value in
            if missionDraft != value { missionDraft = value }
        }
        .onChange(of: missionDraft) { _, value in
            onDirtyChange(value.trimmingCharacters(in: .whitespacesAndNewlines) != model.organization.outcome)
        }
        .onChange(of: searchText) { _, _ in
            if !filteredTasks.contains(where: { $0.id == selectedTaskID }) {
                selectedTaskID = filteredTasks.first?.id
            }
        }
        .sheet(isPresented: $showsCompactInspector) {
            if let task = selectedTask {
                VStack(spacing: 0) {
                    HStack {
                        Text("Task details")
                            .font(.headline)
                        Spacer()

                        if let taskIndex = selectedTaskIndex {
                            Text("\(taskIndex + 1) of \(filteredTasks.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(EditorialOfficeTheme.graphite)

                            Button {
                                selectAdjacentTask(offset: -1)
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(taskIndex == 0)
                            .help("Previous task")
                            .accessibilityLabel("Previous task")

                            Button {
                                selectAdjacentTask(offset: 1)
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(taskIndex == filteredTasks.count - 1)
                            .help("Next task")
                            .accessibilityLabel("Next task")
                        }

                        Button("Done") { showsCompactInspector = false }
                            .keyboardShortcut(.cancelAction)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 48)
                    .background(EditorialOfficeTheme.paper)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(EditorialOfficeTheme.rule).frame(height: 1)
                    }

                    taskInspector(task)
                }
                .frame(minWidth: 360, idealWidth: 500, minHeight: 520, idealHeight: 620)
            }
        }
    }

    private func missionHeader(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    Text("Grand Mission")
                        .font(.system(.title3, design: .serif))

                    Text("\(deliveredTaskCount) of \(model.organization.tasks.count) delivered")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(EditorialOfficeTheme.graphite)
                }

                TextField("What should the organization make true?", text: $missionDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: compact ? missionTitleSize * 0.84 : missionTitleSize, weight: .regular, design: .serif))
                    .tracking(-0.5)
                    .lineLimit(compact ? 3...3 : 2...2)
                    .disabled(!model.canEditOrganization)
                    .onSubmit(saveMission)
                    .accessibilityLabel("Current organization mission")

                HStack(spacing: 7) {
                    Label(
                        model.organization.workdayStatus == .complete ? "Mission delivered" : "\(openTaskCount) open",
                        systemImage: model.organization.workdayStatus == .complete ? "checkmark.circle.fill" : "circle.dotted"
                    )
                    Text("\(missionOwnerName) owns the outcome")
                    if missionIsDirty {
                        Text("·")
                        Button(isSavingMission ? "Saving…" : "Save mission", action: saveMission)
                            .buttonStyle(.plain)
                            .underline()
                            .disabled(isSavingMission || missionDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .font(.callout)
                .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.74))
            }

            Spacer(minLength: 12)

            if !compact {
                VStack(alignment: .trailing, spacing: 8) {
                    Text(attentionTaskCount == 0 ? "Nothing needs you" : "\(attentionTaskCount) need attention")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(attentionTaskCount == 0 ? EditorialOfficeTheme.graphite : EditorialOfficeTheme.attention)

                    Button("Open office", action: onOpenOffice)
                        .buttonStyle(EditorialSecondaryButtonStyle())
                        .frame(minWidth: 128)
                }
            }
        }
        .padding(.horizontal, compact ? 24 : 38)
        .padding(.top, compact ? 22 : 26)
        .padding(.bottom, compact ? 18 : 20)
        .background(EditorialOfficeTheme.bone.opacity(0.6))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.75)).frame(height: 1)
        }
    }

    private func missionControls(compact: Bool) -> some View {
        HStack(spacing: compact ? 14 : 24) {
            ForEach(MissionFilter.allCases) { item in
                Button {
                    filter = item
                    selectedTaskID = filteredTasks.first?.id
                } label: {
                    HStack(spacing: 5) {
                        Text(item.rawValue)
                        Text("\(taskCount(for: item))")
                            .foregroundStyle(EditorialOfficeTheme.graphite)
                    }
                        .font(.callout.weight(filter == item ? .semibold : .regular))
                        .padding(.vertical, 15)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(filter == item ? EditorialOfficeTheme.ink : Color.clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == item ? .isSelected : [])
            }

            Spacer()

            Menu {
                ForEach(MissionGrouping.allCases) { item in
                    Button {
                        grouping = item
                    } label: {
                        if item == grouping {
                            Label(item.rawValue, systemImage: "checkmark")
                        } else {
                            Text(item.rawValue)
                        }
                    }
                }
            } label: {
                if compact {
                    Label(grouping.rawValue, systemImage: "rectangle.3.group")
                        .font(.caption.weight(.medium))
                        .accessibilityLabel("Group tasks by \(grouping.rawValue)")
                } else {
                    Text("Group: \(grouping.rawValue)")
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(EditorialOfficeTheme.graphite)
                TextField("Search tasks", text: $searchText)
                    .textFieldStyle(.plain)
                    .frame(width: compact ? 112 : 166)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(EditorialOfficeTheme.graphite)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                    .accessibilityLabel("Clear task search")
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(EditorialOfficeTheme.paper.opacity(0.72))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(EditorialOfficeTheme.rule, lineWidth: 1)
            }
        }
        .padding(.horizontal, compact ? 24 : 38)
        .background(EditorialOfficeTheme.paper.opacity(0.38))
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.7)).frame(height: 1)
        }
    }

    private func taskList(compact: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if filteredTasks.isEmpty {
                    emptyTaskList
                } else if grouping == .status {
                    ForEach(MissionGroup.allCases) { group in
                        let tasks = tasks(in: group)
                        if !tasks.isEmpty || group == .delivered {
                            taskGroup(group, tasks: tasks, compact: compact)
                        }
                    }
                } else {
                    ForEach(model.organization.employees) { employee in
                        let tasks = filteredTasks
                            .filter { $0.assigneeID == employee.id }
                            .sorted { $0.updatedAt > $1.updatedAt }
                        if !tasks.isEmpty {
                            employeeTaskGroup(employee, tasks: tasks, compact: compact)
                        }
                    }
                }
            }
            .padding(.horizontal, compact ? 20 : 24)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.hidden)
        .background(EditorialOfficeTheme.bone.opacity(0.22))
    }

    private var emptyTaskList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(EditorialOfficeTheme.graphite)
            Text("No tasks match")
                .font(.system(.title2, design: .serif))
            Text("Clear the search or return to all tasks.")
                .font(.callout)
                .foregroundStyle(EditorialOfficeTheme.graphite)
            Button("Show all tasks") {
                filter = .all
                searchText = ""
                selectedTaskID = preferredTask?.id
            }
            .buttonStyle(EditorialSecondaryButtonStyle())
            .padding(.top, 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 34)
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func employeeTaskGroup(_ employee: Employee, tasks: [WorkTask], compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                EmployeePortrait(employee: employee, size: CGSize(width: 25, height: 29))
                    .saturation(0)
                Text(employee.name)
                    .font(.system(.headline, design: .default, weight: .semibold))
                Text("· \(tasks.count)")
                    .font(.headline)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)

            ForEach(tasks) { task in
                taskRow(task, compact: compact)
            }
        }
        .padding(.bottom, 10)
    }

    private func taskGroup(_ group: MissionGroup, tasks: [WorkTask], compact: Bool) -> some View {
        let isCollapsed = collapsedGroupIDs.contains(group.id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isCollapsed {
                    collapsedGroupIDs.remove(group.id)
                } else {
                    collapsedGroupIDs.insert(group.id)
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                    Text(group.rawValue)
                        .font(.system(.headline, design: .default, weight: .semibold))
                    Text("· \(tasks.count)")
                        .font(.headline)
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .accessibilityLabel("\(group.rawValue), \(tasks.count) tasks")
            .accessibilityHint(isCollapsed ? "Expand group" : "Collapse group")

            if !isCollapsed {
                ForEach(tasks) { task in
                    taskRow(task, compact: compact)
                }
            }
        }
        .padding(.bottom, 10)
    }

    private func taskRow(_ task: WorkTask, compact: Bool) -> some View {
        let selected = selectedTaskID == task.id
        let employee = model.organization.employee(task.assigneeID)
        return Button {
            selectedTaskID = task.id
            if compact { showsCompactInspector = true }
        } label: {
            HStack(spacing: compact ? 10 : 16) {
                Image(systemName: priorityIcon(for: task))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(priorityColor(for: task))
                    .frame(width: 18)

                Text(taskKey(task))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.76))
                    .frame(width: compact ? 56 : 72, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.callout.weight(selected ? .semibold : .medium))
                    .lineLimit(1)
                Text(task.detail)
                    .font(.caption)
                    .foregroundStyle(EditorialOfficeTheme.graphite)
                    .lineLimit(compact ? 2 : 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let employee {
                    EmployeePortrait(employee: employee, size: CGSize(width: 32, height: 32))
                        .saturation(0)
                    if compact {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(employee.name)
                                .font(.caption.weight(.medium))
                            Text("\(statusLabel(task.status)) · \(dueContext(task))")
                                .font(.caption2)
                                .foregroundStyle(EditorialOfficeTheme.graphite)
                        }
                        .frame(width: 92, alignment: .leading)
                    } else {
                        Text(employee.name)
                            .font(.caption.weight(.medium))
                            .frame(width: 78, alignment: .leading)
                    }
                }

                if !compact {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(priorityColor(for: task))
                            .frame(width: 6, height: 6)
                        Text(statusLabel(task.status))
                    }
                    .font(.caption.weight(.medium))
                    .frame(width: 92, alignment: .leading)

                    Text(dueContext(task))
                        .font(.caption)
                        .frame(width: 64, alignment: .leading)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(EditorialOfficeTheme.graphite)
                    .frame(width: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 7 : 2)
            .frame(minHeight: compact ? 66 : 56)
            .background(selected ? EditorialOfficeTheme.paper : Color.clear)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(selected ? EditorialOfficeTheme.ink : Color.clear)
                    .frame(width: 2)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.58)).frame(height: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(task.title). \(task.detail). \(statusLabel(task.status)), assigned to \(model.employeeName(task.assigneeID))")
    }

    private func taskInspector(_ task: WorkTask) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Text(taskKey(task))
                            .font(.callout.monospacedDigit())
                        Circle()
                            .fill(priorityColor(for: task))
                            .frame(width: 6, height: 6)
                        Text(statusLabel(task.status))
                            .font(.caption.weight(.semibold))
                    }
                    Spacer()
                    Menu {
                        if let artifact = artifact(for: task) {
                            Button("Reveal artifact", systemImage: "arrow.up.forward.square") {
                                model.reveal(artifact)
                            }
                        }
                        Button("See employee", systemImage: "person") {
                            onOpenEmployeeProfile(task.assigneeID)
                        }
                            .disabled(missionIsDirty || isSavingMission)
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 34, height: 30)
                    }
                    .accessibilityLabel("Task actions")
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                .padding(.bottom, 16)

                Text(task.title)
                    .font(.system(size: inspectorTitleSize, weight: .regular, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)

                Text(task.detail)
                    .font(.callout)
                    .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.78))
                    .lineSpacing(3)
                    .padding(.top, 10)

                if let employee = model.organization.employee(task.assigneeID) {
                    HStack(spacing: 11) {
                        EmployeePortrait(employee: employee, size: CGSize(width: 46, height: 46))
                            .saturation(0)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(employee.name)
                                .font(.callout.weight(.semibold))
                            Text(employee.role)
                                .font(.caption)
                                .foregroundStyle(EditorialOfficeTheme.graphite)
                        }

                        Spacer()

                        Button("View profile") {
                            onOpenEmployeeProfile(task.assigneeID)
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .underline()
                        .disabled(missionIsDirty || isSavingMission)
                    }
                    .padding(.top, 18)
                }

                if let artifact = artifact(for: task) {
                    Button {
                        model.reveal(artifact)
                    } label: {
                        Label("Open current artifact", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(EditorialPrimaryButtonStyle())
                    .padding(.top, 18)
                }

                inspectorRule
                    .padding(.vertical, 18)

                if let reviewerID = task.reviewerID {
                    inspectorPerson("Reviewer", employeeID: reviewerID)
                    inspectorRule
                }

                inspectorRow("Current artifact") {
                    if let artifact = artifact(for: task) {
                        Button {
                            model.reveal(artifact)
                        } label: {
                            Label(artifact.relativePath, systemImage: "doc.text")
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("None yet")
                            .foregroundStyle(EditorialOfficeTheme.graphite)
                    }
                }

                inspectorRule
                inspectorRow("Blocker") {
                    if let blocker = blocker(for: task) {
                        Label(blocker.title, systemImage: "exclamationmark.circle")
                            .foregroundStyle(EditorialOfficeTheme.attention)
                    } else {
                        Label("None", systemImage: "nosign")
                    }
                }

                inspectorRule
                    .padding(.top, 4)

                Text("Activity")
                    .font(.headline)
                    .padding(.vertical, 18)

                VStack(alignment: .leading, spacing: 18) {
                    if activity(for: task).isEmpty {
                        Text("No activity has been recorded for this task yet.")
                            .font(.caption)
                            .foregroundStyle(EditorialOfficeTheme.graphite)
                    } else {
                        ForEach(activity(for: task)) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(EditorialOfficeTheme.ink)
                                    .frame(width: 7, height: 7)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(model.employeeName(item.actorID))
                                            .font(.callout.weight(.medium))
                                        Spacer()
                                        Text(item.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.caption2)
                                            .foregroundStyle(EditorialOfficeTheme.graphite)
                                    }
                                    Text(item.message)
                                        .font(.caption)
                                        .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.76))
                                }
                            }
                        }
                    }
                }
            }
            .padding(26)
        }
        .scrollIndicators(.hidden)
        .background(EditorialOfficeTheme.paper.opacity(0.72))
    }

    private var emptyInspector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select a task")
                .font(.system(.title2, design: .serif))
            Text("Its owner, evidence, blockers, and activity will appear here.")
                .font(.callout)
                .foregroundStyle(EditorialOfficeTheme.graphite)
            Spacer()
        }
        .padding(26)
        .background(EditorialOfficeTheme.paper.opacity(0.72))
    }

    private func inspectorRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(width: 104, alignment: .leading)
            content()
                .font(.callout)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }

    private func inspectorPerson(_ title: String, employeeID: String) -> some View {
        inspectorRow(title) {
            if let employee = model.organization.employee(employeeID) {
                HStack(spacing: 9) {
                    EmployeePortrait(employee: employee, size: CGSize(width: 38, height: 44))
                        .saturation(0)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(employee.name)
                        Text(employee.role)
                            .font(.caption)
                            .foregroundStyle(EditorialOfficeTheme.graphite)
                    }
                }
            }
        }
    }

    private var inspectorRule: some View {
        Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.72)).frame(height: 1)
    }

    private var filteredTasks: [WorkTask] {
        model.organization.tasks.filter { task in
            let filterMatch = taskMatches(task, filter: filter)
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatch = query.isEmpty
                || task.title.localizedCaseInsensitiveContains(query)
                || task.detail.localizedCaseInsensitiveContains(query)
                || model.employeeName(task.assigneeID).localizedCaseInsensitiveContains(query)
            return filterMatch && searchMatch
        }
    }

    private func taskMatches(_ task: WorkTask, filter: MissionFilter) -> Bool {
        switch filter {
        case .all: true
        case .open: task.status != .done
        case .blocked: task.status == .blocked || blocker(for: task) != nil
        }
    }

    private func taskCount(for filter: MissionFilter) -> Int {
        model.organization.tasks.filter { taskMatches($0, filter: filter) }.count
    }

    private var deliveredTaskCount: Int {
        model.organization.tasks.filter { $0.status == .done }.count
    }

    private var openTaskCount: Int {
        model.organization.tasks.count - deliveredTaskCount
    }

    private var attentionTaskCount: Int {
        model.organization.tasks.filter {
            $0.status == .blocked || blocker(for: $0) != nil
        }.count
    }

    private func tasks(in group: MissionGroup) -> [WorkTask] {
        filteredTasks.filter { group.statuses.contains($0.status) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var selectedTask: WorkTask? {
        selectedTaskID.flatMap { id in filteredTasks.first(where: { $0.id == id }) }
    }

    private var selectedTaskIndex: Int? {
        guard let selectedTaskID else { return nil }
        return filteredTasks.firstIndex(where: { $0.id == selectedTaskID })
    }

    private func selectAdjacentTask(offset: Int) {
        guard let selectedTaskIndex else { return }
        let nextIndex = selectedTaskIndex + offset
        guard filteredTasks.indices.contains(nextIndex) else { return }
        selectedTaskID = filteredTasks[nextIndex].id
    }

    private var preferredTask: WorkTask? {
        model.organization.tasks.first(where: { [.doing, .revision, .review].contains($0.status) })
            ?? model.organization.tasks.first
    }

    private var missionOwnerName: String {
        let ownerID = model.organization.goals.first?.ownerID ?? "maya"
        return model.employeeName(ownerID)
    }

    private var missionIsDirty: Bool {
        missionDraft.trimmingCharacters(in: .whitespacesAndNewlines) != model.organization.outcome
    }

    private func saveMission() {
        let trimmed = missionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSavingMission = true
        Task {
            let saved = await model.updateOutcome(trimmed)
            isSavingMission = false
            if saved { onDirtyChange(false) }
        }
    }

    private func taskKey(_ task: WorkTask) -> String {
        let prefix = String(model.organization.name.filter(\.isLetter).prefix(3)).uppercased()
        let index = (model.organization.tasks.firstIndex(where: { $0.id == task.id }) ?? 0) + 1
        return "\(prefix.isEmpty ? "ORG" : prefix)-\(String(format: "%02d", index))"
    }

    private func statusLabel(_ status: TaskStatus) -> String {
        switch status {
        case .doing, .revision: "In progress"
        case .review: "Review"
        case .waiting, .ready: "Next"
        case .blocked: "Blocked"
        case .done: "Delivered"
        }
    }

    private func dueContext(_ task: WorkTask) -> String {
        if Calendar.current.isDateInToday(task.updatedAt) { return "Today" }
        return task.updatedAt.formatted(.dateTime.month(.abbreviated).day())
    }

    private func priorityIcon(for task: WorkTask) -> String {
        switch task.status {
        case .doing, .review, .revision: "arrow.up"
        case .blocked: "exclamationmark"
        case .done: "checkmark"
        case .waiting, .ready: "circle.fill"
        }
    }

    private func priorityColor(for task: WorkTask) -> Color {
        switch task.status {
        case .blocked: EditorialOfficeTheme.attention
        case .done: EditorialOfficeTheme.success
        case .waiting, .ready: EditorialOfficeTheme.graphite
        default: EditorialOfficeTheme.attention
        }
    }

    private func artifact(for task: WorkTask) -> Artifact? {
        if let id = task.artifactIDs.last,
           let artifact = model.organization.artifacts.first(where: { $0.id == id }) {
            return artifact
        }
        return model.organization.artifacts.last(where: { $0.taskID == task.id })
    }

    private func blocker(for task: WorkTask) -> Blocker? {
        model.organization.blockers.first(where: { !$0.resolved && $0.taskID == task.id })
    }

    private func activity(for task: WorkTask) -> [Activity] {
        let relevant = model.organization.activity.filter {
            $0.actorID == task.assigneeID
                || $0.actorID == task.reviewerID
                || $0.message.localizedCaseInsensitiveContains(task.title)
        }
        return Array(relevant.suffix(4))
    }
}

private enum MissionFilter: String, CaseIterable, Identifiable {
    case all = "All tasks"
    case open = "Open"
    case blocked = "Blocked"

    var id: String { rawValue }
}

private enum MissionGrouping: String, CaseIterable, Identifiable {
    case status = "Status"
    case assignee = "Assignee"

    var id: String { rawValue }
}

private enum MissionGroup: String, CaseIterable, Identifiable {
    case inProgress = "In progress"
    case review = "Review"
    case next = "Next"
    case delivered = "Delivered"

    var id: String { rawValue }

    var statuses: Set<TaskStatus> {
        switch self {
        case .inProgress: [.doing, .revision]
        case .review: [.review]
        case .next: [.waiting, .ready, .blocked]
        case .delivered: [.done]
        }
    }
}
