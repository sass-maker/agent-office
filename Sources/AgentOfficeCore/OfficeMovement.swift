import Foundation

public struct OfficePoint: Equatable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public func distance(to other: OfficePoint) -> Double {
    hypot(x - other.x, y - other.y)
  }
}

public enum OfficeStation: String, CaseIterable, Sendable {
  case entry
  case managerDesk
  case researchNook
  case writerDesk
  case reviewTable
  case reportDesk
  case readingChair
  case kitchen
  case sofa
  case helpDesk
}

/// A tiny authored navigation graph for the POC office. The work engine owns
/// what employees do; this planner only decides how they move through the room.
public struct OfficeRoutePlanner: Sendable {
  private enum Waypoint: String, CaseIterable {
    case entry
    case upperHall
    case managerAisle
    case center
    case lowerHall
    case westAisle
    case eastAisle
    case southAisle
  }

  private let points: [Waypoint: OfficePoint] = [
    .entry: OfficePoint(x: 0.50, y: 0.72),
    .upperHall: OfficePoint(x: 0.50, y: 0.58),
    .managerAisle: OfficePoint(x: 0.39, y: 0.49),
    .center: OfficePoint(x: 0.52, y: 0.40),
    .lowerHall: OfficePoint(x: 0.52, y: 0.28),
    .westAisle: OfficePoint(x: 0.25, y: 0.36),
    .eastAisle: OfficePoint(x: 0.76, y: 0.37),
    .southAisle: OfficePoint(x: 0.72, y: 0.20),
  ]

  private let links: [Waypoint: Set<Waypoint>] = [
    .entry: [.upperHall],
    .upperHall: [.entry, .managerAisle, .center, .eastAisle],
    .managerAisle: [.upperHall, .westAisle],
    .center: [.upperHall, .lowerHall, .westAisle, .eastAisle],
    .lowerHall: [.center, .westAisle, .southAisle, .eastAisle],
    .westAisle: [.managerAisle, .center, .lowerHall],
    .eastAisle: [.upperHall, .center, .lowerHall, .southAisle],
    .southAisle: [.lowerHall, .eastAisle],
  ]

  public init() {}

  public func destination(for station: OfficeStation, occupancySlot: Int = 0) -> OfficePoint {
    let base =
      switch station {
      case .entry: OfficePoint(x: 0.50, y: 0.72)
      case .managerDesk: OfficePoint(x: 0.68, y: 0.31)
      case .researchNook: OfficePoint(x: 0.78, y: 0.27)
      case .writerDesk: OfficePoint(x: 0.86, y: 0.16)
      case .reviewTable: OfficePoint(x: 0.49, y: 0.19)
      case .reportDesk: OfficePoint(x: 0.61, y: 0.30)
      case .readingChair: OfficePoint(x: 0.72, y: 0.32)
      case .kitchen: OfficePoint(x: 0.84, y: 0.27)
      case .sofa: OfficePoint(x: 0.88, y: 0.18)
      case .helpDesk: OfficePoint(x: 0.54, y: 0.27)
      }

    guard occupancySlot > 0 else { return base }
    let offsets = [
      OfficePoint(x: -0.048, y: -0.018),
      OfficePoint(x: 0.048, y: -0.018),
      OfficePoint(x: 0, y: 0.045),
    ]
    let offset = offsets[(occupancySlot - 1) % offsets.count]
    return OfficePoint(x: base.x + offset.x, y: base.y + offset.y)
  }

  public func route(
    from origin: OfficePoint,
    to station: OfficeStation,
    occupancySlot: Int = 0,
    laneOffset: Double = 0
  ) -> [OfficePoint] {
    let destination = destination(for: station, occupancySlot: occupancySlot)
    if origin.distance(to: destination) < 0.025 { return [destination] }

    let start = nearestWaypoint(to: origin)
    let finish = nearestWaypoint(to: destination)
    let waypointRoute = shortestRoute(from: start, to: finish)
    let interior = waypointRoute.map { point in
      OfficePoint(x: point.x + laneOffset, y: point.y)
    }
    return compact([origin] + interior + [destination])
  }

  private func nearestWaypoint(to point: OfficePoint) -> Waypoint {
    points.min { lhs, rhs in
      lhs.value.distance(to: point) < rhs.value.distance(to: point)
    }?.key ?? .center
  }

  private func shortestRoute(from start: Waypoint, to finish: Waypoint) -> [OfficePoint] {
    guard start != finish else { return points[start].map { [$0] } ?? [] }
    var frontier = [start]
    var previous: [Waypoint: Waypoint] = [:]
    var visited: Set<Waypoint> = [start]

    while !frontier.isEmpty {
      let current = frontier.removeFirst()
      if current == finish { break }
      for neighbor in (links[current] ?? []).sorted(by: { $0.rawValue < $1.rawValue })
      where !visited.contains(neighbor) {
        visited.insert(neighbor)
        previous[neighbor] = current
        frontier.append(neighbor)
      }
    }

    var route = [finish]
    while let prior = previous[route.last!], route.last != start {
      route.append(prior)
    }
    if route.last != start { route.append(start) }
    return route.reversed().compactMap { points[$0] }
  }

  private func compact(_ route: [OfficePoint]) -> [OfficePoint] {
    route.reduce(into: []) { result, point in
      if result.last?.distance(to: point) ?? 1 > 0.012 {
        result.append(point)
      }
    }
  }
}
