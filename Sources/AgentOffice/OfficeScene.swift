import AgentOfficeCore
import SpriteKit
import SwiftUI

struct OfficeSceneView: NSViewRepresentable {
    let organization: OrganizationState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        let scene = OfficeScene(size: CGSize(width: 1_536, height: 1_024))
        scene.scaleMode = .resizeFill
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        guard let scene = view.scene as? OfficeScene else { return }
        scene.apply(organization: organization, reduceMotion: reduceMotion)
    }
}

final class OfficeScene: SKScene {
    private let background = SKSpriteNode()
    private var employeeNodes: [String: EmployeeSpriteNode] = [:]
    private var didLoadBackground = false

    override func didMove(to view: SKView) {
        background.zPosition = 0
        addChild(background)
        loadBackground()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
    }

    func apply(organization: OrganizationState, reduceMotion: Bool) {
        loadBackground()

        for employee in organization.employees {
            let node = employeeNodes[employee.id] ?? makeEmployeeNode(employee)
            let currentTask = employee.currentTaskID.flatMap { organization.task($0) }
            node.update(employee: employee, task: currentTask)
            let target = position(for: employee, in: organization)
            node.removeAction(forKey: "travel")
            if reduceMotion || node.position == .zero {
                node.position = target
            } else if distance(node.position, target) > 3 {
                let move = SKAction.move(to: target, duration: 0.85)
                move.timingMode = .easeInEaseOut
                node.run(move, withKey: "travel")
            }
        }

        childNode(withName: "handoff")?.removeFromParent()
        if organization.tasks.contains(where: { $0.status == .review }) {
            addHandoffCue(reduceMotion: reduceMotion)
        }
    }

    private func loadBackground() {
        guard !didLoadBackground else { return }
        didLoadBackground = true
        if let url = Bundle.module.url(forResource: "cozy-office-background", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            background.texture = SKTexture(image: image)
            background.texture?.filteringMode = .linear
        } else {
            background.color = NSColor(red: 0.20, green: 0.15, blue: 0.12, alpha: 1)
        }
        background.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.size = size
    }

    private func makeEmployeeNode(_ employee: Employee) -> EmployeeSpriteNode {
        let node = EmployeeSpriteNode(employee: employee)
        node.zPosition = 20
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        employeeNodes[employee.id] = node
        addChild(node)
        return node
    }

    private func position(for employee: Employee, in organization: OrganizationState) -> CGPoint {
        let normalized: CGPoint

        if employee.status == .blocked {
            normalized = CGPoint(x: 0.56, y: 0.55)
        } else if employee.status == .reviewing {
            normalized = CGPoint(x: 0.53, y: 0.16)
        } else if employee.status == .resting || employee.status == .celebrating {
            normalized = switch employee.id {
            case "maya": CGPoint(x: 0.73, y: 0.17)
            case "nia": CGPoint(x: 0.69, y: 0.55)
            default: CGPoint(x: 0.86, y: 0.16)
            }
        } else if let taskID = employee.currentTaskID,
                  let task = organization.task(taskID) {
            normalized = switch task.kind {
            case .research: CGPoint(x: 0.69, y: 0.55)
            case .draft: CGPoint(x: 0.26, y: 0.19)
            case .report: CGPoint(x: 0.42, y: 0.44)
            }
        } else {
            normalized = switch employee.id {
            case "maya": CGPoint(x: 0.42, y: 0.44)
            case "nia": CGPoint(x: 0.69, y: 0.55)
            default: CGPoint(x: 0.26, y: 0.19)
            }
        }

        return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func addHandoffCue(reduceMotion: Bool) {
        let paper = SKShapeNode(rectOf: CGSize(width: 22, height: 28), cornerRadius: 3)
        paper.name = "handoff"
        paper.fillColor = NSColor(red: 1, green: 0.97, blue: 0.88, alpha: 1)
        paper.strokeColor = NSColor(red: 0.30, green: 0.22, blue: 0.17, alpha: 1)
        paper.lineWidth = 2
        paper.position = CGPoint(x: size.width * 0.43, y: size.height * 0.35)
        paper.zPosition = 25
        addChild(paper)
        guard !reduceMotion else { return }
        paper.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 5, duration: 0.7),
            .moveBy(x: 0, y: -5, duration: 0.7),
        ])))
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}

final class EmployeeSpriteNode: SKNode {
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 58, height: 14))
    private let character = SKSpriteNode()
    private let namePlate = SKShapeNode(rectOf: CGSize(width: 78, height: 23), cornerRadius: 10)
    private let nameLabel = SKLabelNode(fontNamed: "HelveticaNeue-Bold")
    private let statusPlate = SKShapeNode(rectOf: CGSize(width: 108, height: 21), cornerRadius: 8)
    private let statusLabel = SKLabelNode(fontNamed: "HelveticaNeue-Medium")

    init(employee: Employee) {
        super.init()
        isUserInteractionEnabled = false

        shadow.fillColor = NSColor.black.withAlphaComponent(0.28)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: 3)
        shadow.zPosition = -1
        addChild(shadow)

        character.texture = Self.texture(for: employee.id)
        character.texture?.filteringMode = .linear
        character.size = CGSize(width: 92, height: 162)
        character.anchorPoint = CGPoint(x: 0.5, y: 0)
        character.position = .zero
        addChild(character)

        namePlate.fillColor = NSColor(red: 1, green: 0.97, blue: 0.89, alpha: 0.96)
        namePlate.strokeColor = NSColor(red: 0.23, green: 0.18, blue: 0.15, alpha: 0.85)
        namePlate.lineWidth = 2
        namePlate.position = CGPoint(x: 0, y: -15)
        namePlate.zPosition = 3
        addChild(namePlate)

        nameLabel.text = employee.name
        nameLabel.fontSize = 13
        nameLabel.fontColor = NSColor(red: 0.16, green: 0.20, blue: 0.22, alpha: 1)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -16)
        nameLabel.zPosition = 4
        addChild(nameLabel)

        statusPlate.fillColor = NSColor(red: 0.09, green: 0.23, blue: 0.23, alpha: 0.92)
        statusPlate.strokeColor = NSColor.white.withAlphaComponent(0.35)
        statusPlate.lineWidth = 1
        statusPlate.position = CGPoint(x: 0, y: 178)
        statusPlate.zPosition = 3
        addChild(statusPlate)

        statusLabel.fontSize = 11
        statusLabel.fontColor = .white
        statusLabel.verticalAlignmentMode = .center
        statusLabel.position = CGPoint(x: 0, y: 177)
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
        character.alpha = employee.status == .resting ? 0.92 : 1
    }

    private func statusText(employee: Employee, task: WorkTask?) -> String {
        if employee.status == .blocked { return "Needs you" }
        if employee.status == .reviewing { return "Reviewing" }
        if let task {
            return switch task.kind {
            case .research: "Researching"
            case .draft: task.status == .revision ? "Revising" : "Writing"
            case .report: "Reporting"
            }
        }
        return employee.status.rawValue.capitalized
    }

    private static func texture(for employeeID: String) -> SKTexture? {
        guard let url = Bundle.module.url(forResource: "employee-atlas", withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else { return nil }

        let atlas = SKTexture(image: image)
        let index: CGFloat = switch employeeID {
        case "maya": 0
        case "nia": 1
        default: 2
        }
        return SKTexture(
            rect: CGRect(x: index / 3, y: 0, width: 1 / 3, height: 1),
            in: atlas
        )
    }
}
