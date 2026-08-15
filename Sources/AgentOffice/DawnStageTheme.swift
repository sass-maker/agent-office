import SwiftUI

enum DawnStageTheme {
  static let proscenium = Color(hex: "08111F")
  static let backstage = Color(hex: "101D34")
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
