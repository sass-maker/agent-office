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
                .preferredColorScheme(visualTestColorScheme)
                .task {
                    await model.load()
                }
                .frame(minWidth: 760, minHeight: 620)
        }
        .defaultSize(width: 1_420, height: 900)
        .windowStyle(.hiddenTitleBar)
    }

    private var visualTestColorScheme: ColorScheme? {
#if DEBUG
        if CommandLine.arguments.contains("--appearance-light") { return .light }
        if CommandLine.arguments.contains("--appearance-dark") { return .dark }
        return nil
#else
        nil
#endif
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
