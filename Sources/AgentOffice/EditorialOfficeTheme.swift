import AppKit
import SwiftUI

enum EditorialOfficeTheme {
  static let sidebarInk = Color(lightHex: "090A0B", darkHex: "08090A")
  static let controlInk = Color(lightHex: "090A0B", darkHex: "D8D1C6")
  static let ink = Color(lightHex: "181817", darkHex: "EEE9DF")
  static let bone = Color(lightHex: "F3EFE7", darkHex: "1C1B19")
  static let paper = Color(lightHex: "FAF8F3", darkHex: "262421")
  static let softGrey = Color(lightHex: "DDD9D1", darkHex: "34312D")
  static let graphite = Color(lightHex: "5D5B57", darkHex: "B9B3A9")
  static let rule = Color(lightHex: "B9B5AC", darkHex: "575149")
  static let onInk = Color(hex: "FAF8F3")
  static let sidebarMuted = Color(hex: "B9B5AC")
  // Meaning comes from language, symbols, weight, and fill—not status hue.
  static let success = Color(lightHex: "5D5B57", darkHex: "C2BBB0")
  static let attention = Color(lightHex: "181817", darkHex: "EEE9DF")

  static let workingField = LinearGradient(
    colors: [paper, bone],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

struct EditorialPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(.body, design: .default, weight: .medium))
      .foregroundStyle(EditorialOfficeTheme.onInk.opacity(isEnabled ? 1 : 0.58))
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

extension Color {
  init(lightHex: String, darkHex: String) {
    self.init(
      nsColor: NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return NSColor(editorialHex: match == .darkAqua ? darkHex : lightHex)
      })
  }
}

extension NSColor {
  fileprivate convenience init(editorialHex hex: String) {
    let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var value: UInt64 = 0
    Scanner(string: clean).scanHexInt64(&value)
    self.init(
      calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: 1
    )
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
