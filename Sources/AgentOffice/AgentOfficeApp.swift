import SwiftUI

@main
struct AgentOfficeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            OrganizationHomeView()
                .environmentObject(model)
                .task {
                    await model.load()
                }
                .frame(minWidth: 1_180, minHeight: 760)
        }
        .defaultSize(width: 1_420, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button(model.organization.workdayStatus == .active ? "End Day" : "Start Day") {
                    model.toggleDay()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}

