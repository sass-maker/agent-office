import SwiftUI

enum EditorialOfficeTheme {
    static let sidebarInk = Color(hex: "090A0B")
    static let ink = Color(hex: "181817")
    static let bone = Color(hex: "F3EFE7")
    static let paper = Color(hex: "FAF8F3")
    static let softGrey = Color(hex: "DDD9D1")
    static let graphite = Color(hex: "5D5B57")
    static let rule = Color(hex: "B9B5AC")
    // Meaning comes from language, symbols, weight, and fill—not status hue.
    static let success = Color(hex: "5D5B57")
    static let attention = Color(hex: "181817")

    static let workingField = LinearGradient(
        colors: [paper, bone],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let quietField = LinearGradient(
        colors: [softGrey.opacity(0.48), paper, bone.opacity(0.94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct EditorialPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .medium))
            .foregroundStyle(EditorialOfficeTheme.paper.opacity(isEnabled ? 1 : 0.58))
            .padding(.horizontal, 18)
            .frame(minHeight: 42)
            .background(
                EditorialOfficeTheme.sidebarInk.opacity(
                    isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.34
                ),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
            .offset(y: configuration.isPressed && isEnabled ? 1 : 0)
    }
}

struct EditorialSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .regular))
            .foregroundStyle(EditorialOfficeTheme.ink.opacity(isEnabled ? 1 : 0.45))
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(
                EditorialOfficeTheme.paper.opacity(configuration.isPressed ? 0.62 : 0.88),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(EditorialOfficeTheme.rule.opacity(0.9), lineWidth: 1)
            }
    }
}

struct EditorialPaperSurface: ViewModifier {
    var cornerRadius: CGFloat = 7
    var shadow: Bool = true

    func body(content: Content) -> some View {
        content
            .background(EditorialOfficeTheme.paper, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(EditorialOfficeTheme.rule.opacity(0.76), lineWidth: 1)
            }
            .shadow(
                color: shadow ? EditorialOfficeTheme.sidebarInk.opacity(0.16) : .clear,
                radius: shadow ? 18 : 0,
                x: shadow ? 5 : 0,
                y: shadow ? 12 : 0
            )
    }
}

extension View {
    func editorialPaper(cornerRadius: CGFloat = 7, shadow: Bool = true) -> some View {
        modifier(EditorialPaperSurface(cornerRadius: cornerRadius, shadow: shadow))
    }
}
