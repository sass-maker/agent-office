import AgentOfficeCore
import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var organizationName = ""
    @State private var ownerName = ""
    @State private var outcome = ""
    @State private var purpose = ""
    @State private var product = ""
    @State private var audience = ""
    @State private var stage = ""
    @State private var operatingPrinciples = ""
    @State private var constraints = ""
    @State private var startImmediately = true
    @State private var useLocalCodex = false
    @State private var allowWebResearch = false
    @State private var isCompleting = false
    @State private var selectedStarterPackageIDs = Set(["starter.mira", "starter.maya", "starter.nia", "starter.theo", "starter.iris"])
    @State private var expandedStarterPackageID: String?

    private let steps = ["Welcome", "Company", "Product", "Mission", "Team"]

    var body: some View {
        GeometryReader { proxy in
            let showsPreview = proxy.size.width >= 1_020

            HStack(spacing: 0) {
                onboardingForm(compact: !showsPreview)
                    .frame(width: showsPreview ? max(610, proxy.size.width * 0.53) : proxy.size.width)

                if showsPreview {
                    officePreview
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(reduceMotion ? .identity : .opacity)
                }
            }
        }
        .background(EditorialOfficeTheme.bone)
        .foregroundStyle(EditorialOfficeTheme.ink)
        .onAppear(perform: loadDrafts)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: step)
        .alert("The office could not open", isPresented: Binding(
            get: { model.lastError != nil },
            set: { if !$0 { model.lastError = nil } }
        )) {
            Button("Okay", role: .cancel) { model.lastError = nil }
        } message: {
            Text(model.lastError ?? "")
        }
    }

    private func onboardingForm(compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 18 : 34) {
            setupRail(compact: compact)
                .frame(width: compact ? 92 : 144)

            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 34) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(stepTitle)
                                .font(.system(size: compact ? 40 : 48, weight: .regular, design: .serif))
                                .tracking(-1.15)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(stepSubtitle)
                                .font(.system(.title3, design: .serif))
                                .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        stepContent
                    }
                    .frame(maxWidth: 520, alignment: .topLeading)
                    .padding(.top, 92)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)

                onboardingActions
                    .frame(maxWidth: 520)
                    .padding(.bottom, 18)

                Label("Your organization stays on this Mac.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(EditorialOfficeTheme.graphite)
                    .padding(.bottom, 32)
            }
            .padding(.trailing, compact ? 24 : 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(EditorialOfficeTheme.bone)
    }

    private func setupRail(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                Button {
                    step = index
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle()
                                    .fill(index == step ? EditorialOfficeTheme.sidebarInk : EditorialOfficeTheme.bone)
                                    .overlay {
                                        Circle().stroke(EditorialOfficeTheme.ink.opacity(0.8), lineWidth: 1)
                                    }
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(index == step ? EditorialOfficeTheme.onInk : EditorialOfficeTheme.ink)
                            }
                            .frame(width: 28, height: 28)

                            if index < steps.count - 1 {
                                Rectangle()
                                    .fill(EditorialOfficeTheme.ink.opacity(0.6))
                                    .frame(width: 1, height: compact ? 58 : 82)
                            }
                        }

                        if !compact {
                            Text(title)
                                .font(.system(.callout, design: .default, weight: index == step ? .medium : .regular))
                                .foregroundStyle(index <= step ? EditorialOfficeTheme.ink : EditorialOfficeTheme.graphite)
                                .padding(.top, 5)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(index > step)
                .help(index <= step ? "Return to \(title)" : "Complete the earlier steps first")
                .accessibilityLabel("Step \(index + 1), \(title)")
                .accessibilityAddTraits(index == step ? .isSelected : [])
            }
        }
        .padding(.top, 164)
        .padding(.leading, compact ? 22 : 34)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Setup step \(step + 1) of \(steps.count): \(steps[step])")
    }

    private var officePreview: some View {
        GeometryReader { proxy in
            ZStack {
                if let previewImage = Self.officePreviewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .saturation(0)
                        .contrast(1.04)
                        .clipped()
                } else {
                    EditorialOfficeTheme.softGrey
                }

                LinearGradient(
                    colors: [Color.clear, EditorialOfficeTheme.sidebarInk.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let assistant = model.organization.employee("mira") ?? model.organization.employees.first(where: { $0.kind == .ai }) {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            Spacer()
                            VStack(spacing: 0) {
                                EmployeePortrait(employee: assistant, size: CGSize(width: 200, height: 250))
                                    .saturation(0)
                                    .contrast(1.12)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(assistant.name)
                                        .font(.system(.title3, design: .serif, weight: .regular))
                                    Text(step == 4 ? "Ready to welcome the team" : "Your executive assistant")
                                        .font(.caption)
                                        .foregroundStyle(EditorialOfficeTheme.graphite)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(width: 210, alignment: .leading)
                                .background(EditorialOfficeTheme.paper.opacity(0.96))
                                .overlay(alignment: .top) {
                                    Rectangle().fill(EditorialOfficeTheme.ink.opacity(0.22)).frame(height: 1)
                                }
                            }
                            .editorialPaper(cornerRadius: 5)
                            .padding(.trailing, 44)
                            .padding(.bottom, 38)
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(EditorialOfficeTheme.ink.opacity(0.38))
                    .frame(width: 1)
            }
        }
        .accessibilityHidden(true)
    }

    private static let officePreviewImage: NSImage? = {
        guard let url = Bundle.module.url(forResource: "editorial-office-background", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: welcome
        case 1: organizationSetup
        case 2: productSetup
        case 3: firstMission
        default: readyToOpen
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Set one outcome. Your employees will decide what comes next, work through it together, and bring you in where judgment is needed.")
                .font(.system(.title2, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.88))

            VStack(alignment: .leading, spacing: 18) {
                promise("Named employees", detail: "Each person has a role, responsibilities, skills, memory, and a place in the company.")
                promise("A living workplace", detail: "Their real tasks, handoffs, blockers, and artifacts are visible throughout the day.")
                promise("Local by default", detail: "Your organization and its work stay in a folder you control on this Mac.")
            }
        }
    }

    private var organizationSetup: some View {
        VStack(alignment: .leading, spacing: 28) {
            editorialLineField("Company name", prompt: "Clarity Initiative", text: $organizationName)
            editorialLineField("Your name", prompt: "What should your assistant call you?", text: $ownerName)
            editorialTextField(
                "Why this company exists",
                prompt: "The purpose that should guide every employee",
                text: $purpose,
                lineLimit: 2...4
            )
        }
    }

    private var productSetup: some View {
        VStack(alignment: .leading, spacing: 32) {
            editorialTextField(
                "What are you building?",
                prompt: "Describe the product or service in plain language",
                text: $product,
                lineLimit: 2...4
            )
            editorialTextField(
                "Who is it for?",
                prompt: "The people your team should understand and serve",
                text: $audience,
                lineLimit: 2...4
            )
            editorialLineField("Current stage", prompt: "Proof of concept, early product, growing…", text: $stage)
        }
    }

    private var firstMission: some View {
        VStack(alignment: .leading, spacing: 30) {
            editorialTextField(
                "What should the team make true?",
                prompt: "A concrete outcome they can own together",
                text: $outcome,
                lineLimit: 2...4
            )
            editorialTextField(
                "How should your team work?",
                prompt: "Decision principles, quality bar, and when to involve you",
                text: $operatingPrinciples,
                lineLimit: 2...4
            )
            editorialTextField(
                "What must they never assume?",
                prompt: "Constraints, unsupported claims, and actions that require you",
                text: $constraints,
                lineLimit: 2...4
            )
        }
    }

    private var readyToOpen: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Review the people you want to hire. Each candidate arrives with declared skills and boundaries; connections are never granted by hiring.")
                    .font(.system(.title3, design: .serif))
                    .lineSpacing(4)
                Text("Open Contract to inspect execution, review, connections, package source, and reduced-mode behavior.")
                    .font(.caption)
                    .foregroundStyle(EditorialOfficeTheme.graphite)
            }

            VStack(spacing: 0) {
                ForEach(model.organization.employeePackages.filter(\.builtIn)) { package in
                    candidateFolio(package)
                }
            }

            editorialToggle(
                title: "Prepare their first outcomes when the doors open",
                detail: "Hired employees receive independent, resumable commitments within local capacity.",
                isOn: $startImmediately
            )

            if model.codexAvailable {
                editorialToggle(
                    title: "Let employees use my local Codex",
                    detail: "Uses your existing authentication. No API key is stored in this app.",
                    isOn: $useLocalCodex
                )
            } else if useLocalCodex {
                editorialToggle(
                    title: "Local Codex is selected",
                    detail: "It is temporarily unavailable. This choice will be preserved and employees will wait for it to return.",
                    isOn: $useLocalCodex
                )
                .disabled(true)
            }

            if useLocalCodex {
                editorialToggle(
                    title: "Give Nia read-only web research",
                    detail: "Publishing and every external write remain unavailable.",
                    isOn: $allowWebResearch
                )
            }

            Text("\(selectedStarterPackageIDs.count) candidates selected for hire")
                .font(.caption.weight(.semibold))
                .foregroundStyle(EditorialOfficeTheme.graphite)
                .padding(.top, 4)

            if selectedStarterPackageIDs.isEmpty {
                Label("Select at least one employee to open the office.", systemImage: "exclamationmark.circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(EditorialOfficeTheme.attention)
            }
        }
    }

    private func candidateFolio(_ package: EmployeePackage) -> some View {
        let selected = selectedStarterPackageIDs.contains(package.id)
        let expanded = expandedStarterPackageID == package.id
        let essentialSkills = package.skills.prefix(3).map(\.name).joined(separator: ", ")

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("Hire \(package.name)", isOn: Binding(
                    get: { selectedStarterPackageIDs.contains(package.id) },
                    set: { isSelected in
                        if isSelected { selectedStarterPackageIDs.insert(package.id) }
                        else { selectedStarterPackageIDs.remove(package.id) }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .accessibilityHint("Hiring creates an employee and local working contract, but grants no external authority")

                if let employee = model.organization.employees.first(where: { $0.packageID == package.id }) {
                    EmployeePortrait(employee: employee, size: CGSize(width: 42, height: 50))
                        .saturation(0)
                } else {
                    Image(systemName: "person.crop.rectangle")
                        .font(.title2)
                        .frame(width: 42, height: 50)
                        .foregroundStyle(EditorialOfficeTheme.graphite)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("\(package.name) · \(package.role)")
                        .font(.callout.weight(.semibold))
                    Text(package.responsibility)
                        .font(.caption)
                        .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.76))
                        .lineLimit(2)
                    Text(essentialSkills.isEmpty ? "No included skills" : essentialSkills)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(EditorialOfficeTheme.graphite)
                        .lineLimit(1)
                    Label("Local sandbox · reviewed plans · no publishing", systemImage: "lock")
                        .font(.caption2)
                        .foregroundStyle(EditorialOfficeTheme.graphite)
                        .lineLimit(1)
                        .help("They work only in the selected company folder. You review plans before execution, and hiring grants no publishing authority.")
                }

                Spacer(minLength: 8)

                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                        expandedStarterPackageID = expanded ? nil : package.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        Text(expanded ? "Hide" : "Contract")
                            .font(.caption2.weight(.medium))
                    }
                    .frame(minWidth: 50, minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(expanded ? "Hide contract details" : "Review contract details")
                .accessibilityLabel(expanded ? "Hide \(package.name) contract details" : "Show \(package.name) contract details")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            }
            .padding(.vertical, 13)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Rectangle()
                        .fill(EditorialOfficeTheme.rule.opacity(0.7))
                        .frame(height: 1)

                    candidateContractFact("Included skills", package.skills.map(\.name).joined(separator: ", "))
                    candidateContractFact("Connections", candidateConnectionNames(package))
                    candidateContractFact("Execution", package.preferredProvider == .localCodex ? "Local sandbox · Local Codex preferred" : "Local sandbox · practice mode ready")
                    candidateContractFact("Review", "Plans are reviewed before execution; authority changes always return to you.")
                    candidateContractFact("Package", "Version \(package.version) by \(package.creator)")
                    candidateContractFact("Reduced mode", package.reducedModeDescription ?? "No reduced mode is declared.")

                    Label("Hiring grants no connection, publishing right, spending authority, or access outside this company folder.", systemImage: "hand.raised")
                        .font(.caption)
                        .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 34)
                .padding(.bottom, 15)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 8)
        .background(selected ? EditorialOfficeTheme.softGrey.opacity(0.28) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.64)).frame(height: 1)
        }
    }

    private func candidateContractFact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(EditorialOfficeTheme.graphite)
                .frame(width: 84, alignment: .leading)
            Text(value.isEmpty ? "None declared" : value)
                .font(.caption)
                .foregroundStyle(EditorialOfficeTheme.ink.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func candidateConnectionNames(_ package: EmployeePackage) -> String {
        guard !package.requiredConnectionIDs.isEmpty else { return "None required" }
        let definitions = model.organization.knowledge?.connectionDefinitions ?? []
        return package.requiredConnectionIDs.map { id in
            definitions.first(where: { $0.id == id })?.name ?? id
        }.joined(separator: ", ")
    }

    private var onboardingActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if step == 4 {
                Label(finalHireSummary, systemImage: "person.2.fill")
                    .font(.caption)
                    .foregroundStyle(EditorialOfficeTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Hiring summary. \(finalHireSummary)")
            }

            HStack(spacing: 18) {
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(.plain)
                        .underline()
                } else if model.organization.setupCompleted == true {
                    Button("Return to the office", action: model.cancelOnboarding)
                        .buttonStyle(.plain)
                        .underline()
                } else {
                    Button("Use the prepared office") {
                        Task {
                            isCompleting = true
                            _ = await model.completeOnboarding(
                                name: model.organization.name,
                                ownerName: model.organization.employee("owner")?.name ?? "Founder",
                                outcome: model.organization.outcome,
                                productBrief: model.organization.productBrief,
                                profile: model.organization.knowledge?.profile ?? .empty,
                                startImmediately: false
                            )
                            isCompleting = false
                        }
                    }
                    .buttonStyle(.plain)
                    .underline()
                    .disabled(isCompleting)
                }

                Spacer()

                Button {
                    if step < 4 {
                        step += 1
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isCompleting {
                            ProgressView().controlSize(.small)
                        }
                        Text(primaryActionTitle)
                    }
                }
                .buttonStyle(EditorialPrimaryButtonStyle())
                .frame(minWidth: 260)
                .disabled(!currentStepIsValid || isCompleting)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
    }

    private var primaryActionTitle: String {
        if isCompleting { return step == 4 ? "Hiring…" : "Opening…" }
        guard step == 4 else { return "Continue" }
        let noun = selectedStarterPackageIDs.count == 1 ? "employee" : "employees"
        return "Hire \(selectedStarterPackageIDs.count) \(noun) and open office"
    }

    private var finalHireSummary: String {
        let noun = selectedStarterPackageIDs.count == 1 ? "employee" : "employees"
        let execution = useLocalCodex ? "Local Codex" : "practice mode"
        let connections = allowWebResearch && useLocalCodex ? "Nia gets read-only research" : "no connections granted"
        let openingWork = startImmediately ? "first outcomes prepared" : "no work starts yet"
        return "\(selectedStarterPackageIDs.count) \(noun) · \(execution) · \(connections) · no publishing · \(openingWork)"
    }

    private func promise(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Circle()
                .fill(EditorialOfficeTheme.ink)
                .frame(width: 7, height: 7)
                .padding(.top, 7)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(EditorialOfficeTheme.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func editorialLineField(_ label: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(.title3, design: .serif, weight: .medium))
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.vertical, 9)
                .accessibilityLabel(label)
            Rectangle()
                .fill(EditorialOfficeTheme.rule)
                .frame(height: 1)
        }
    }

    private func editorialTextField(
        _ label: String,
        prompt: String,
        text: Binding<String>,
        lineLimit: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(.title3, design: .serif, weight: .medium))
            TextField(prompt, text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(lineLimit)
                .padding(.vertical, 9)
                .accessibilityLabel(label)
            Rectangle()
                .fill(EditorialOfficeTheme.rule)
                .frame(height: 1)
        }
    }

    private func editorialToggle(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(EditorialOfficeTheme.graphite)
            }
        }
        .toggleStyle(.switch)
        .tint(EditorialOfficeTheme.controlInk)
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EditorialOfficeTheme.rule.opacity(0.7)).frame(height: 1)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: "Set up your office"
        case 1: "Name the company"
        case 2: "Describe the work"
        case 3: "Set the first mission"
        default: "Hire your first team"
        }
    }

    private var stepSubtitle: String {
        switch step {
        case 0: "A small company of AI employees, living and working on your Mac."
        case 1: "Give your team a home and a reason to gather."
        case 2: "Tell your team what you are building and what matters."
        case 3: "Give them one outcome they can break down, discuss, and execute."
        default: "Choose who joins, how they begin, and which narrow local permissions they receive."
        }
    }

    private var currentStepIsValid: Bool {
        switch step {
        case 1: !organizationName.trimmed.isEmpty && !ownerName.trimmed.isEmpty && !purpose.trimmed.isEmpty
        case 2: !product.trimmed.isEmpty && !audience.trimmed.isEmpty
        case 3: !outcome.trimmed.isEmpty
        case 4: !selectedStarterPackageIDs.isEmpty
        default: true
        }
    }

    private func loadDrafts() {
        organizationName = model.organization.name
        ownerName = model.organization.employee("owner")?.name ?? ""
        outcome = model.organization.outcome
        let profile = model.organization.knowledge?.profile ?? .empty
        purpose = profile.purpose
        product = profile.product
        audience = profile.audience
        stage = profile.stage
        operatingPrinciples = profile.operatingPrinciples
        constraints = profile.constraints
        useLocalCodex = model.organization.executionMode == .localCodex
        allowWebResearch = model.webResearchGranted
        startImmediately = model.organization.setupCompleted == true ? false : true
    }

    private func completeOnboarding() {
        Task {
            isCompleting = true
            _ = await model.completeOnboarding(
                name: organizationName,
                ownerName: ownerName,
                outcome: outcome,
                productBrief: onboardingProductBrief,
                profile: currentProfile,
                executionMode: useLocalCodex ? .localCodex : .demo,
                webResearchGranted: allowWebResearch,
                hiredPackageIDs: selectedStarterPackageIDs,
                startImmediately: startImmediately
            )
            isCompleting = false
        }
    }

    private var currentProfile: OrganizationProfile {
        OrganizationProfile(
            purpose: purpose.trimmed,
            product: product.trimmed,
            audience: audience.trimmed,
            stage: stage.trimmed,
            operatingPrinciples: operatingPrinciples.trimmed,
            constraints: constraints.trimmed
        )
    }

    private var onboardingProductBrief: String {
        """
        # Product brief

        ## Organization purpose
        \(purpose.trimmed)

        ## Product
        \(product.trimmed)

        ## Audience
        \(audience.trimmed)

        ## Current stage
        \(stage.trimmed)

        ## Current outcome
        \(outcome.trimmed)

        ## Operating principles
        \(operatingPrinciples.trimmed)

        ## Constraints and claims we can support
        \(constraints.trimmed)
        """
    }
}

extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
