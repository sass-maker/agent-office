import SwiftUI

@main
struct AgentOfficeApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if !model.isLoaded {
                    LaunchView()
                } else if model.showsOnboarding {
                    OnboardingView()
                } else {
                    OrganizationShellView()
                }
            }
                .environmentObject(model)
                .preferredColorScheme(.light)
                .task {
                    await model.load()
                }
                .frame(minWidth: 760, minHeight: 620)
        }
        .defaultSize(width: 1_420, height: 900)
        .windowStyle(.hiddenTitleBar)
    }
}

private struct LaunchView: View {
    var body: some View {
        ZStack {
            EditorialOfficeTheme.workingField.ignoresSafeArea()
            ProgressView("Opening the office…")
                .controlSize(.large)
                .foregroundStyle(EditorialOfficeTheme.ink)
        }
    }
}
