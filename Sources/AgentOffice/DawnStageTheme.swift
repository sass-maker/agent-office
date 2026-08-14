import SwiftUI

enum DawnStageTheme {
  static let proscenium = Color(hex: "08111F")
  static let backstage = Color(hex: "101D34")
  static let cobalt = Color(hex: "273F73")
  static let rose = Color(hex: "B66A82")
  static let coral = Color(hex: "E9826D")
  static let ivory = Color(hex: "F6E8D1")
  static let mint = Color(hex: "72D5A5")
  static let amber = Color(hex: "F0B35D")
  static let steel = Color(hex: "7E90AD")
  static let hairline = Color(hex: "D6A7AD").opacity(0.34)

  static let pageField = LinearGradient(
    colors: [proscenium, backstage, Color(hex: "19294A")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let dawnField = LinearGradient(
    colors: [cobalt.opacity(0.94), rose.opacity(0.72), coral.opacity(0.54)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

struct StagePanelSurface: ViewModifier {
  var accent = DawnStageTheme.rose
  var cornerRadius: CGFloat = 14

  func body(content: Content) -> some View {
    content
      .background {
        RoundedRectangle(cornerRadius: cornerRadius)
          .fill(DawnStageTheme.backstage.opacity(0.96))
          .shadow(color: .black.opacity(0.36), radius: 18, x: 0, y: 12)
      }
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius)
          .stroke(DawnStageTheme.hairline, lineWidth: 1)
      }
      .overlay(alignment: .top) {
        Rectangle()
          .fill(accent.opacity(0.92))
          .frame(height: 2)
          .padding(.horizontal, cornerRadius)
      }
  }
}

struct StageFieldSurface: ViewModifier {
  var accent = DawnStageTheme.rose

  func body(content: Content) -> some View {
    content
      .background(DawnStageTheme.proscenium.opacity(0.78), in: RoundedRectangle(cornerRadius: 10))
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(accent.opacity(0.34), lineWidth: 1)
      }
  }
}

struct StagePrimaryButtonStyle: ButtonStyle {
  var tint = DawnStageTheme.coral
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.callout, design: .rounded, weight: .bold))
      .foregroundStyle(DawnStageTheme.proscenium.opacity(isEnabled ? 1 : 0.58))
      .padding(.horizontal, 14)
      .frame(minHeight: 36)
      .background(
        tint.opacity(isEnabled ? (configuration.isPressed ? 0.76 : 1) : 0.32),
        in: RoundedRectangle(cornerRadius: 9)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 9)
          .stroke(DawnStageTheme.ivory.opacity(0.28), lineWidth: 1)
      }
      .offset(y: configuration.isPressed && isEnabled ? 1 : 0)
  }
}

struct CueLight: View {
  let color: Color
  let active: Bool

  var body: some View {
    Circle()
      .fill(active ? color : color.opacity(0.24))
      .overlay {
        Circle().stroke(DawnStageTheme.ivory.opacity(active ? 0.72 : 0.18), lineWidth: 1)
      }
      .shadow(color: active ? color.opacity(0.5) : .clear, radius: 7)
  }
}
