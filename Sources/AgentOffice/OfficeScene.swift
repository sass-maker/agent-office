import AgentOfficeCore
import AppKit
import SpriteKit
import SwiftUI

struct OfficeSceneView: NSViewRepresentable {
  let organization: OrganizationState
  let selectedEmployeeID: String?
  let showsLabels: Bool
  let onSelectEmployee: (String) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(
    organization: OrganizationState,
    selectedEmployeeID: String? = nil,
    showsLabels: Bool = true,
    onSelectEmployee: @escaping (String) -> Void = { _ in }
  ) {
    self.organization = organization
    self.selectedEmployeeID = selectedEmployeeID
    self.showsLabels = showsLabels
    self.onSelectEmployee = onSelectEmployee
  }

  func makeNSView(context: Context) -> SKView {
    let view = SKView()
    view.ignoresSiblingOrder = true
    view.preferredFramesPerSecond = 60
    let scene = OfficeScene(size: CGSize(width: 1_536, height: 1_024))
    scene.scaleMode = .resizeFill
    scene.onSelectEmployee = onSelectEmployee
    view.presentScene(scene)
    return view
  }

  func updateNSView(_ view: SKView, context: Context) {
    guard let scene = view.scene as? OfficeScene else { return }
    let hasActiveMovement =
      organization.workdayStatus == .active
      || organization.employees.contains {
        ![.resting, .waiting, .celebrating].contains($0.status)
      }
    view.preferredFramesPerSecond =
      reduceMotion && !hasActiveMovement
      ? 1
      : (hasActiveMovement && !reduceMotion ? 60 : 20)
    scene.onSelectEmployee = onSelectEmployee
    scene.apply(
      organization: organization,
      selectedEmployeeID: selectedEmployeeID,
      showsLabels: showsLabels,
      reduceMotion: reduceMotion
    )
  }
}

final class OfficeScene: SKScene {
  private let background = SKSpriteNode()
  private let planner = OfficeRoutePlanner()
  private var employeeNodes: [String: EmployeeSpriteNode] = [:]
  private var handoffCue: SKShapeNode?
  private var handoffUsesReducedMotion: Bool?
  private var didLoadBackground = false
  private var latestOrganization: OrganizationState?
  private var latestSelectedEmployeeID: String?
  private var latestShowsLabels = true
  private var latestReduceMotion = false
  var onSelectEmployee: ((String) -> Void)?

  override func didMove(to view: SKView) {
    background.zPosition = 0
    addChild(background)
    loadBackground()
  }

  override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    updateBackgroundSize()
    guard size.width > 0, size.height > 0 else { return }

    if oldSize.width > 0, oldSize.height > 0 {
      let xScale = size.width / oldSize.width
      let yScale = size.height / oldSize.height
      for node in employeeNodes.values {
        node.position = CGPoint(x: node.position.x * xScale, y: node.position.y * yScale)
        node.destinationSignature = nil
        node.updateDepth(in: size)
      }
    } else {
      for node in employeeNodes.values {
        node.stopTravel(at: .zero)
        node.destinationSignature = nil
      }
    }

    if let latestOrganization {
      render(
        organization: latestOrganization,
        selectedEmployeeID: latestSelectedEmployeeID,
        showsLabels: latestShowsLabels,
        reduceMotion: latestReduceMotion
      )
    }
  }

  func apply(
    organization: OrganizationState, selectedEmployeeID: String?, showsLabels: Bool,
    reduceMotion: Bool
  ) {
    latestOrganization = organization
    latestSelectedEmployeeID = selectedEmployeeID
    latestShowsLabels = showsLabels
    latestReduceMotion = reduceMotion
    render(
      organization: organization,
      selectedEmployeeID: selectedEmployeeID,
      showsLabels: showsLabels,
      reduceMotion: reduceMotion
    )
  }

  override func mouseDown(with event: NSEvent) {
    let location = event.location(in: self)
    for node in nodes(at: location) {
      var candidate: SKNode? = node
      while let current = candidate {
        if let employeeNode = current as? EmployeeSpriteNode {
          onSelectEmployee?(employeeNode.employeeID)
          return
        }
        candidate = current.parent
      }
    }
  }

  private func render(
    organization: OrganizationState, selectedEmployeeID: String?, showsLabels: Bool,
    reduceMotion: Bool
  ) {
    guard size.width > 0, size.height > 0 else { return }
    loadBackground()
    var stationOccupancy: [OfficeStation: Int] = [:]

    let officeEmployees = organization.employees.filter {
      $0.kind == .ai && [.hired, .paused].contains($0.effectiveEmploymentState)
    }
    let officeEmployeeIDs = Set(officeEmployees.map(\.id))
    let departedEmployeeIDs = Set(employeeNodes.keys).subtracting(officeEmployeeIDs)
    for employeeID in departedEmployeeIDs {
      guard let departedNode = employeeNodes.removeValue(forKey: employeeID) else { continue }
      departedNode.removeAllActions()
      departedNode.removeFromParent()
    }

    for (index, employee) in officeEmployees.enumerated() {
      let currentTask = employee.currentTaskID.flatMap { organization.task($0) }
      let station = station(for: employee, task: currentTask)
      let slot = stationOccupancy[station, default: 0]
      stationOccupancy[station] = slot + 1

      let node: EmployeeSpriteNode
      if let existing = employeeNodes[employee.id] {
        node = existing
      } else {
        node = makeEmployeeNode(
          employee,
          index: index,
          entersFromDoor: organization.workdayStatus == .active,
          reduceMotion: reduceMotion
        )
      }
      node.update(employee: employee, task: currentTask)
      let selected = employee.id == selectedEmployeeID
      let active = ![.resting, .waiting, .celebrating].contains(employee.status)
      node.setLabelsVisible(showsLabels, selected: selected, active: active)
      node.setSelected(selected)

      let destination = planner.destination(for: station, occupancySlot: slot)
      let destinationPoint = screenPoint(destination)
      if isOutsideUsableOffice(node.position) {
        node.stopTravel(at: destinationPoint)
        node.destinationSignature = nil
      }
      let signature =
        "\(station.rawValue):\(slot):\(employee.status.rawValue):\(currentTask?.status.rawValue ?? "none")"
      guard node.destinationSignature != signature || reduceMotion != node.usesReducedMotion else {
        node.updateDepth(in: size)
        continue
      }

      node.destinationSignature = signature
      node.usesReducedMotion = reduceMotion
      if reduceMotion {
        node.stopTravel(at: destinationPoint)
      } else {
        let origin = normalizedPoint(node.position)
        let laneOffset = [-0.012, 0, 0.012][index % 3]
        let route = planner.route(
          from: origin,
          to: station,
          occupancySlot: slot,
          laneOffset: laneOffset
        ).map(screenPoint)
        node.travel(
          along: route,
          in: size,
          idleRoute: nil,
          speed: max(size.width, size.height) * 0.16
        )
      }
    }

    updateHandoffCue(
      isVisible: organization.tasks.contains(where: { $0.status == .review }),
      reduceMotion: reduceMotion
    )
  }

  private func isOutsideUsableOffice(_ point: CGPoint) -> Bool {
    point.x < size.width * 0.08
      || point.x > size.width * 0.95
      || point.y < size.height * 0.06
      || point.y > size.height * 0.94
  }

  private func loadBackground() {
    guard !didLoadBackground else { return }
    didLoadBackground = true
    if let url = Bundle.module.url(
      forResource: "editorial-office-background", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    {
      background.texture = SKTexture(image: image)
      background.texture?.filteringMode = .linear
    } else {
      background.color = NSColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1)
    }
    background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    background.position = CGPoint(x: size.width / 2, y: size.height / 2)
    updateBackgroundSize()
  }

  private func updateBackgroundSize() {
    guard size.width > 0, size.height > 0 else { return }
    let authoredAspect: CGFloat = 1.5
    let sceneAspect = size.width / size.height
    if sceneAspect > authoredAspect {
      background.size = CGSize(width: size.width, height: size.width / authoredAspect)
    } else {
      background.size = CGSize(width: size.height * authoredAspect, height: size.height)
    }
  }

  private func makeEmployeeNode(
    _ employee: Employee,
    index: Int,
    entersFromDoor: Bool,
    reduceMotion: Bool
  ) -> EmployeeSpriteNode {
    let node = EmployeeSpriteNode(employee: employee)
    if entersFromDoor {
      let entry = planner.destination(for: .entry, occupancySlot: index)
      node.position = screenPoint(entry)
      if !reduceMotion {
        node.alpha = 0
        node.run(.fadeIn(withDuration: 0.28))
      }
    } else {
      let restStation = restingStation(for: employee.id)
      node.position = screenPoint(planner.destination(for: restStation))
    }
    node.updateDepth(in: size)
    employeeNodes[employee.id] = node
    addChild(node)
    return node
  }

  private func station(for employee: Employee, task: WorkTask?) -> OfficeStation {
    if employee.status == .blocked { return .helpDesk }
    if employee.status == .reviewing { return .reviewTable }
    if employee.status == .resting || employee.status == .celebrating || employee.status == .waiting
    {
      return restingStation(for: employee.id)
    }
    if let task {
      return switch task.kind {
      case .research: .researchNook
      case .draft: .writerDesk
      case .report: .reportDesk
      case .analysis: .researchNook
      }
    }
    return switch employee.id {
    case "mira": .reportDesk
    case "maya": .managerDesk
    case "nia": .researchNook
    case "iris": .reviewTable
    default: .writerDesk
    }
  }

  private func restingStation(for employeeID: String) -> OfficeStation {
    switch employeeID {
    case "mira": .reportDesk
    case "maya": .readingChair
    case "nia": .kitchen
    case "iris": .reviewTable
    default: .sofa
    }
  }

  private func screenPoint(_ point: OfficePoint) -> CGPoint {
    let shelfSafeFloor = size.width < 1_180 ? size.height * 0.17 : size.height * 0.07
    return CGPoint(
      x: point.x * size.width,
      y: max(point.y * size.height, shelfSafeFloor)
    )
  }

  private func normalizedPoint(_ point: CGPoint) -> OfficePoint {
    guard size.width > 0, size.height > 0 else { return OfficePoint(x: 0.5, y: 0.5) }
    return OfficePoint(x: point.x / size.width, y: point.y / size.height)
  }

  private func updateHandoffCue(isVisible: Bool, reduceMotion: Bool) {
    guard isVisible else {
      handoffCue?.removeFromParent()
      handoffCue = nil
      handoffUsesReducedMotion = nil
      return
    }

    if let handoffCue {
      guard handoffUsesReducedMotion != reduceMotion else { return }
      handoffCue.removeAction(forKey: "float")
      handoffUsesReducedMotion = reduceMotion
      if !reduceMotion { animateHandoffCue(handoffCue) }
      return
    }

    let paper = SKShapeNode(rectOf: CGSize(width: 24, height: 30), cornerRadius: 3)
    paper.name = "handoff"
    paper.fillColor = NSColor(white: 0.96, alpha: 1)
    paper.strokeColor = NSColor(white: 0.08, alpha: 0.9)
    paper.lineWidth = 2
    paper.position = CGPoint(x: size.width * 0.48, y: size.height * 0.28)
    paper.zPosition = 40

    let fold = SKShapeNode(
      path: {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 4, y: 8))
        path.addLine(to: CGPoint(x: 4, y: -7))
        path.addLine(to: CGPoint(x: -5, y: -7))
        return path
      }())
    fold.strokeColor = NSColor(white: 0.22, alpha: 1)
    fold.lineWidth = 2
    paper.addChild(fold)
    addChild(paper)
    handoffCue = paper
    handoffUsesReducedMotion = reduceMotion

    if !reduceMotion { animateHandoffCue(paper) }
  }

  private func animateHandoffCue(_ paper: SKShapeNode) {
    paper.run(
      .repeatForever(
        .sequence([
          .group([.moveBy(x: 0, y: 6, duration: 0.72), .rotate(byAngle: 0.035, duration: 0.72)]),
          .group([.moveBy(x: 0, y: -6, duration: 0.72), .rotate(byAngle: -0.035, duration: 0.72)]),
        ])), withKey: "float")
  }
}

final class EmployeeSpriteNode: SKNode {
  let employeeID: String
  private let selectionRing = SKShapeNode(ellipseOf: CGSize(width: 94, height: 24))
  private let shadow = SKShapeNode(ellipseOf: CGSize(width: 72, height: 16))
  private let character = SKSpriteNode()
  private let namePlate = SKShapeNode(rectOf: CGSize(width: 72, height: 21), cornerRadius: 8)
  private let nameLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
  private let statusPlate = SKShapeNode(rectOf: CGSize(width: 112, height: 22), cornerRadius: 8)
  private let statusLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")
  private let idleTexture: SKTexture?
  private let walkTextures: [SKTexture]

  var destinationSignature: String?
  var usesReducedMotion = false

  init(employee: Employee) {
    employeeID = employee.id
    idleTexture = Self.texture(for: employee.id)
    walkTextures = Self.walkTextures(for: employee.id)
    super.init()
    isUserInteractionEnabled = false
    name = "employee:\(employee.id)"

    selectionRing.fillColor = .clear
    selectionRing.strokeColor = NSColor(white: 0.08, alpha: 0.92)
    selectionRing.lineWidth = 3
    selectionRing.position = CGPoint(x: 0, y: 8)
    selectionRing.zPosition = -0.5
    selectionRing.isHidden = true
    addChild(selectionRing)

    shadow.fillColor = NSColor.black.withAlphaComponent(0.34)
    shadow.strokeColor = .clear
    shadow.position = CGPoint(x: 0, y: 3)
    shadow.zPosition = -1
    addChild(shadow)

    character.texture = idleTexture
    character.texture?.filteringMode = .linear
    character.shader = SKShader(
      source: """
        void main() {
            vec4 source = texture2D(u_texture, v_tex_coord);
            float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
            gl_FragColor = vec4(vec3(gray), source.a);
        }
        """)
    let displayScale = Self.displayScale(for: employee.id)
    character.size = CGSize(width: 110 * displayScale, height: 190 * displayScale)
    character.anchorPoint = CGPoint(x: 0.5, y: 0)
    character.position = .zero
    addChild(character)

    namePlate.fillColor = NSColor(white: 0.035, alpha: 0.94)
    namePlate.strokeColor = NSColor(white: 0.72, alpha: 0.7)
    namePlate.lineWidth = 1
    namePlate.position = CGPoint(x: 0, y: -13)
    namePlate.zPosition = 3
    addChild(namePlate)

    nameLabel.text = employee.name
    nameLabel.fontSize = 11
    nameLabel.fontColor = NSColor(white: 0.97, alpha: 1)
    nameLabel.verticalAlignmentMode = .center
    nameLabel.position = CGPoint(x: 0, y: -14)
    nameLabel.zPosition = 4
    addChild(nameLabel)

    statusPlate.fillColor = NSColor(white: 0.08, alpha: 0.94)
    statusPlate.strokeColor = NSColor(white: 0.72, alpha: 0.5)
    statusPlate.lineWidth = 1
    statusPlate.position = CGPoint(x: 0, y: character.size.height + 16)
    statusPlate.zPosition = 3
    addChild(statusPlate)

    statusLabel.fontSize = 11
    statusLabel.fontColor = .white
    statusLabel.verticalAlignmentMode = .center
    statusLabel.position = CGPoint(x: 0, y: character.size.height + 15)
    statusLabel.zPosition = 4
    addChild(statusLabel)

    update(employee: employee, task: nil)
  }

  @available(*, unavailable)
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func update(employee: Employee, task: WorkTask?) {
    nameLabel.text = employee.name
    statusLabel.text = statusText(employee: employee, task: task)
    statusPlate.isHidden = employee.status == .resting
    statusLabel.isHidden = employee.status == .resting
    character.alpha = employee.status == .resting ? 0.94 : 1

    let color: NSColor =
      switch employee.status {
      case .blocked: NSColor(white: 0.03, alpha: 0.98)
      case .reviewing: NSColor(white: 0.25, alpha: 0.96)
      default: NSColor(white: 0.08, alpha: 0.94)
      }
    statusPlate.fillColor = color
  }

  func setSelected(_ selected: Bool) {
    selectionRing.isHidden = !selected
  }

  func setLabelsVisible(_ visible: Bool, selected: Bool, active: Bool) {
    let showsName = visible && (selected || active)
    namePlate.isHidden = !showsName
    nameLabel.isHidden = !showsName
    let showsStatus = visible && active
    statusPlate.isHidden = !showsStatus
    statusLabel.isHidden = !showsStatus
  }

  func travel(along route: [CGPoint], in sceneSize: CGSize, idleRoute: [CGPoint]?, speed: CGFloat) {
    removeAction(forKey: "travel")
    endWalking()
    guard let final = route.last else { return }

    var previous = position
    var actions: [SKAction] = []
    for point in route.dropFirst() {
      let distance = hypot(point.x - previous.x, point.y - previous.y)
      guard distance > 2 else { continue }
      let duration = max(0.16, min(1.45, distance / speed))
      let direction = point.x - previous.x
      actions.append(.run { [weak self] in self?.beginWalking(horizontalDirection: direction) })
      let move = SKAction.move(to: point, duration: duration)
      move.timingMode = .easeInEaseOut
      actions.append(move)
      actions.append(.run { [weak self] in self?.updateDepth(in: sceneSize) })
      previous = point
    }
    actions.append(.run { [weak self] in self?.endWalking() })

    if let idleRoute, idleRoute.count > 1 {
      var idleActions: [SKAction] = [.wait(forDuration: 1.2)]
      var idlePrevious = final
      for point in idleRoute.dropFirst() + [idleRoute[0]] {
        let distance = hypot(point.x - idlePrevious.x, point.y - idlePrevious.y)
        let duration = max(0.55, distance / (speed * 0.36))
        let direction = point.x - idlePrevious.x
        idleActions.append(
          .run { [weak self] in self?.beginWalking(horizontalDirection: direction) })
        let move = SKAction.move(to: point, duration: duration)
        move.timingMode = .easeInEaseOut
        idleActions.append(move)
        idleActions.append(.run { [weak self] in self?.endWalking() })
        idleActions.append(.wait(forDuration: 1.35))
        idlePrevious = point
      }
      actions.append(.repeatForever(.sequence(idleActions)))
    }

    run(.sequence(actions), withKey: "travel")
  }

  func stopTravel(at point: CGPoint) {
    removeAction(forKey: "travel")
    endWalking()
    position = point
  }

  func updateDepth(in sceneSize: CGSize) {
    guard sceneSize.height > 0 else { return }
    let responsiveScale = min(1, max(0.74, sceneSize.width / 1_000))
    setScale(responsiveScale)
    let labelScale = 1 / responsiveScale
    namePlate.setScale(labelScale)
    nameLabel.setScale(labelScale)
    statusPlate.setScale(labelScale)
    statusLabel.setScale(labelScale)
    zPosition = 20 + (1 - position.y / sceneSize.height) * 16
  }

  private func beginWalking(horizontalDirection: CGFloat) {
    if abs(horizontalDirection) > 1 {
      character.xScale = horizontalDirection < 0 ? -1 : 1
    }
    guard character.action(forKey: "walk-frames") == nil else { return }
    if !walkTextures.isEmpty {
      character.run(
        .repeatForever(
          .animate(with: walkTextures, timePerFrame: 0.13, resize: false, restore: false)),
        withKey: "walk-frames"
      )
    }
    let step = SKAction.sequence([
      .moveBy(x: 0, y: 2, duration: 0.13),
      .moveBy(x: 0, y: -2, duration: 0.13),
    ])
    character.run(.repeatForever(step), withKey: "step-bob")
    shadow.run(.scaleX(to: 0.88, duration: 0.14), withKey: "step-shadow")
  }

  private func endWalking() {
    character.removeAction(forKey: "walk-frames")
    character.removeAction(forKey: "step-bob")
    character.texture = idleTexture
    character.position.y = 0
    shadow.removeAction(forKey: "step-shadow")
    shadow.xScale = 1
  }

  private func statusText(employee: Employee, task: WorkTask?) -> String {
    if employee.status == .blocked { return "Needs you" }
    if employee.status == .reviewing { return "Reviewing" }
    if employee.status == .planning { return "Planning outcome" }
    if employee.id == "iris", employee.status == .working { return "Reading feedback" }
    if let task {
      return switch task.kind {
      case .research: "Researching"
      case .draft: task.status == .revision ? "Revising" : "Writing"
      case .report: "Preparing your note"
      case .analysis: "Reading customer notes"
      }
    }
    return employee.status.rawValue.capitalized
  }

  private static func texture(for employeeID: String) -> SKTexture? {
    if ["mira", "iris"].contains(employeeID),
      let url = Bundle.module.url(forResource: "\(employeeID)-character", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    {
      return SKTexture(image: image)
    }
    guard let url = Bundle.module.url(forResource: "employee-atlas", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else { return nil }

    let atlas = SKTexture(image: image)
    let index: CGFloat
    switch Self.figureID(for: employeeID) {
    case "maya": index = 0
    case "nia": index = 1
    default: index = 2
    }
    return SKTexture(
      rect: CGRect(x: index / 3, y: 0, width: 1 / 3, height: 1),
      in: atlas
    )
  }

  /// The drawn figure an employee borrows when the app ships no art for them.
  ///
  /// Employees hired from any other package — built in or imported — used to
  /// stand in the office with no body at all. They share one of the neutral
  /// atlas figures instead, chosen from the identifier's own bytes so the same
  /// employee always looks the same across launches.
  private static func figureID(for employeeID: String) -> String {
    let figures = ["maya", "nia", "theo"]
    if figures.contains(employeeID) { return employeeID }
    return figures[employeeID.utf8.reduce(0) { ($0 + Int($1)) % figures.count }]
  }

  private static func displayScale(for employeeID: String) -> CGFloat {
    switch employeeID {
    case "mira", "iris": 1
    case "nia": 0.97
    default: Self.figureID(for: employeeID) == "nia" ? 0.97 : 0.94
    }
  }

  private static func walkTextures(for employeeID: String) -> [SKTexture] {
    let sheetID = ["mira", "iris"].contains(employeeID) ? employeeID : figureID(for: employeeID)
    guard let url = Bundle.module.url(forResource: "walk-\(sheetID)", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else { return [] }

    let sheet = SKTexture(image: image)
    sheet.filteringMode = .linear
    let frames = (0..<3).map { index in
      SKTexture(
        rect: CGRect(x: CGFloat(index) / 3, y: 0, width: 1 / 3, height: 1),
        in: sheet
      )
    }
    return frames + [frames[1]]
  }
}
