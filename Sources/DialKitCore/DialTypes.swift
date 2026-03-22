import CoreGraphics
import Foundation

public protocol DialNumericValue: Comparable {
    var dialDoubleValue: Double { get }
    init(dialDoubleValue: Double)
}

extension Double: DialNumericValue {
    public var dialDoubleValue: Double { self }

    public init(dialDoubleValue: Double) {
        self = dialDoubleValue
    }
}

extension Float: DialNumericValue {
    public var dialDoubleValue: Double { Double(self) }

    public init(dialDoubleValue: Double) {
        self = Float(dialDoubleValue)
    }
}

extension CGFloat: DialNumericValue {
    public var dialDoubleValue: Double { Double(self) }

    public init(dialDoubleValue: Double) {
        self = CGFloat(dialDoubleValue)
    }
}

extension Int: DialNumericValue {
    public var dialDoubleValue: Double { Double(self) }

    public init(dialDoubleValue: Double) {
        self = Int(dialDoubleValue.rounded())
    }
}

public struct DialOption: Hashable, Codable, Identifiable {
    public let value: String
    public let label: String

    public var id: String { value }

    public init(_ value: String, label: String? = nil) {
        self.value = value
        self.label = label ?? dialFormattedLabel(value)
    }

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

public struct DialBezier: Hashable, Codable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }

    public static let standard = DialBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)
}

public struct ResolvedSpringPhysics: Equatable {
    public let stiffness: Double
    public let damping: Double
    public let mass: Double

    public init(stiffness: Double, damping: Double, mass: Double) {
        self.stiffness = stiffness
        self.damping = damping
        self.mass = mass
    }
}

package enum DialSpringEditorMode: String, CaseIterable {
    case simple
    case advanced
}

public enum DialSpring: Equatable, Codable {
    case time(duration: Double, bounce: Double)
    case physics(stiffness: Double, damping: Double, mass: Double)

    public static let `default` = DialSpring.time(duration: 0.35, bounce: 0.24)

    package var editorMode: DialSpringEditorMode {
        switch self {
        case .time:
            return .simple
        case .physics:
            return .advanced
        }
    }

    public var resolvedPhysics: ResolvedSpringPhysics {
        switch self {
        case let .time(duration, bounce):
            let clampedDuration = max(duration, 0.1)
            let mass = 1.0
            let stiffness = pow((2 * Double.pi) / clampedDuration, 2)
            let dampingRatio = 1 - min(max(bounce, 0), 1)
            let damping = 2 * dampingRatio * sqrt(stiffness * mass)
            return ResolvedSpringPhysics(stiffness: stiffness, damping: damping, mass: mass)
        case let .physics(stiffness, damping, mass):
            return ResolvedSpringPhysics(
                stiffness: max(stiffness, 1),
                damping: max(damping, 1),
                mass: max(mass, 0.1)
            )
        }
    }

    package var durationHint: Double {
        switch self {
        case let .time(duration, _):
            return duration
        case .physics:
            return 0.3
        }
    }

    public func updatingTime(duration: Double? = nil, bounce: Double? = nil) -> DialSpring {
        switch self {
        case let .time(currentDuration, currentBounce):
            return .time(duration: duration ?? currentDuration, bounce: bounce ?? currentBounce)
        case .physics:
            return .time(duration: duration ?? 0.3, bounce: bounce ?? 0.2)
        }
    }

    public func updatingPhysics(stiffness: Double? = nil, damping: Double? = nil, mass: Double? = nil) -> DialSpring {
        switch self {
        case .time:
            return .physics(stiffness: stiffness ?? 200, damping: damping ?? 25, mass: mass ?? 1)
        case let .physics(currentStiffness, currentDamping, currentMass):
            return .physics(
                stiffness: stiffness ?? currentStiffness,
                damping: damping ?? currentDamping,
                mass: mass ?? currentMass
            )
        }
    }
}

public enum DialTransitionMode: String, CaseIterable, Codable {
    case easing
    case simple
    case advanced
}

public enum DialTransition: Equatable, Codable {
    case easing(duration: Double, bezier: DialBezier)
    case spring(DialSpring)

    public static let `default` = DialTransition.spring(.default)

    public var mode: DialTransitionMode {
        switch self {
        case .easing:
            return .easing
        case let .spring(spring):
            return spring.editorMode == .simple ? .simple : .advanced
        }
    }

    public func switching(to mode: DialTransitionMode) -> DialTransition {
        switch mode {
        case .easing:
            switch self {
            case let .easing(duration, bezier):
                return .easing(duration: duration, bezier: bezier)
            case let .spring(spring):
                return .easing(duration: spring.durationHint, bezier: .standard)
            }
        case .simple:
            switch self {
            case let .easing(duration, _):
                return .spring(.time(duration: duration, bounce: 0.2))
            case let .spring(spring):
                switch spring {
                case let .time(duration, bounce):
                    return .spring(.time(duration: duration, bounce: bounce))
                case .physics:
                    return .spring(.time(duration: spring.durationHint, bounce: 0.2))
                }
            }
        case .advanced:
            switch self {
            case .easing:
                return .spring(.physics(stiffness: 200, damping: 25, mass: 1))
            case let .spring(spring):
                switch spring {
                case let .physics(stiffness, damping, mass):
                    return .spring(.physics(stiffness: stiffness, damping: damping, mass: mass))
                case .time:
                    return .spring(.physics(stiffness: 200, damping: 25, mass: 1))
                }
            }
        }
    }
}

public struct DialPreset<Model: Codable & Equatable>: Identifiable, Equatable, Codable {
    public let id: UUID
    public var name: String
    public var values: Model

    public init(id: UUID = UUID(), name: String, values: Model) {
        self.id = id
        self.name = name
        self.values = values
    }
}

package struct DialPresetSummary: Identifiable, Equatable {
    package let id: UUID
    package let name: String
}

package func dialFormattedLabel(_ path: String) -> String {
    let token = path.split(separator: ".").last.map(String.init) ?? path
    return token
        .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
        .replacingOccurrences(of: "[_-]+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .capitalized
}

package func dialResolvedPath(prefix: String, path: String) -> String {
    guard !prefix.isEmpty else { return path }
    if path.contains(".") {
        return path
    }
    return "\(prefix).\(path)"
}

package func dialIsValidHexColor(_ value: String) -> Bool {
    let pattern = "^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$"
    return value.range(of: pattern, options: .regularExpression) != nil
}

package func dialStepPrecision(_ step: Double) -> Int {
    let safeStep = abs(step)
    guard safeStep > 0 else {
        return 0
    }

    for precision in 0...6 {
        let factor = pow(10.0, Double(precision))
        let scaled = safeStep * factor
        if abs(scaled.rounded() - scaled) < 0.000_000_1 {
            return precision
        }
    }

    return 6
}

package func dialRound(_ value: Double, step: Double, within range: ClosedRange<Double>) -> Double {
    let safeStep = max(step, 0.000_001)
    let stepped = (value / safeStep).rounded() * safeStep
    let clamped = min(max(stepped, range.lowerBound), range.upperBound)
    let precision = dialStepPrecision(safeStep)
    return Double(String(format: "%0.*f", precision, clamped)) ?? clamped
}

package func dialFormattedNumber(_ value: Double, step: Double) -> String {
    let precision = dialStepPrecision(step)
    return String(format: "%0.*f", precision, value)
}

package func dialInferredStep(for range: ClosedRange<Double>) -> Double {
    let width = range.upperBound - range.lowerBound
    if width <= 1 {
        return 0.01
    }
    if width <= 10 {
        return 0.1
    }
    if width <= 100 {
        return 1
    }
    return 10
}
