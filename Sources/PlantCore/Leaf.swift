import Foundation

public enum LeafPhase: String, Codable { case green, yellow, withered, empty }

public struct Leaf: Codable, Equatable, Identifiable {
    public let id: Int
    public internal(set) var phase: LeafPhase = .green
    /// A replacement leaf expands over 48 hours of good growing conditions.
    public internal(set) var maturity = 1.0
    public internal(set) var yellowHours = 0.0
    public var isPresent: Bool { phase != .empty }
    public var canPrune: Bool { phase == .yellow || phase == .withered }
    public var yellowFraction: Double {
        switch phase {
        case .green, .empty: return 0
        case .yellow: return min(1, 0.40 + yellowHours / 20)
        case .withered: return 1
        }
    }
    public init(id: Int) { self.id = id }
}
