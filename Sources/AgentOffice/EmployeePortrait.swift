import AgentOfficeCore
import AppKit
import SwiftUI

struct EmployeePortrait: View {
  private static let portraitCache = NSCache<NSString, NSImage>()

  let employee: Employee
  var size = CGSize(width: 52, height: 62)

  var body: some View {
    ZStack(alignment: .bottom) {
      RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.26)
        .fill(
          LinearGradient(
            colors: [EditorialOfficeTheme.softGrey, EditorialOfficeTheme.paper],
            startPoint: .top,
            endPoint: .bottom
          )
        )

      if let portrait = Self.portrait(for: employee.id) {
        Image(nsImage: portrait)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .saturation(0)
          .contrast(1.12)
      } else {
        Text(String(employee.name.prefix(1)))
          .font(.system(size: size.width * 0.42, weight: .bold, design: .rounded))
          .foregroundStyle(EditorialOfficeTheme.ink)
          .frame(maxHeight: .infinity)
      }
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.26))
    .overlay {
      RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.26)
        .stroke(Color.white.opacity(0.48), lineWidth: 1)
    }
    .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
    .accessibilityHidden(true)
  }

  private static func portrait(for employeeID: String) -> NSImage? {
    let cacheKey = "\(employeeID)-face" as NSString
    if let cached = portraitCache.object(forKey: cacheKey) {
      return cached
    }

    guard let portrait = fullPortrait(for: employeeID) else { return nil }
    guard let source = portrait.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
      portraitCache.setObject(portrait, forKey: cacheKey)
      return portrait
    }

    let crop = faceCrop(in: source, employeeID: employeeID)
    guard let face = source.cropping(to: crop) else { return portrait }
    let croppedPortrait = NSImage(
      cgImage: face, size: NSSize(width: crop.width, height: crop.height))
    portraitCache.setObject(croppedPortrait, forKey: cacheKey)
    return croppedPortrait
  }

  private static func fullPortrait(for employeeID: String) -> NSImage? {
    if ["mira", "iris", "owner"].contains(employeeID),
      let url = Bundle.module.url(forResource: "\(employeeID)-character", withExtension: "png")
    {
      return NSImage(contentsOf: url)
    }
    guard let url = Bundle.module.url(forResource: "employee-atlas", withExtension: "png"),
      let source = NSImage(contentsOf: url),
      let cgImage = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else { return nil }

    let index: Int
    switch employeeID {
    case "maya": index = 0
    case "nia": index = 1
    case "theo": index = 2
    default: return nil
    }
    let width = cgImage.width / 3
    let crop = CGRect(x: index * width, y: 0, width: width, height: cgImage.height)
    guard let character = cgImage.cropping(to: crop) else { return nil }
    return NSImage(cgImage: character, size: NSSize(width: width, height: cgImage.height))
  }

  private static func faceCrop(in image: CGImage, employeeID: String) -> CGRect {
    let width = CGFloat(image.width)
    let height = CGFloat(image.height)
    let horizontalInset: CGFloat = employeeID == "owner" ? 0.14 : 0.2
    let cropHeight: CGFloat = employeeID == "owner" ? 0.31 : 0.32
    return CGRect(
      x: width * horizontalInset,
      y: 0,
      width: width * (1 - horizontalInset * 2),
      height: height * cropHeight
    ).integral
  }
}
