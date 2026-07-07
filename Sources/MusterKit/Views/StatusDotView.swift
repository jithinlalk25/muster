import SwiftUI

public struct StatusDotView: View {
    private let dot: StatusDot
    public init(_ dot: StatusDot) { self.dot = dot }

    private var color: Color {
        switch dot {
        case .working: return .blue
        case .needsYou: return .orange
        case .idle: return .gray
        }
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .accessibilityHidden(true)
    }
}
