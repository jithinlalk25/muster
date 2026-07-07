import SwiftUI
import MusterCore

public struct SessionRowView: View {
    private let session: Session
    private let now: Date

    public init(session: Session, now: Date) {
        self.session = session
        self.now = now
    }

    private var activity: String? {
        if case let .working(activity) = session.status { return activity }
        return nil
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            StatusDotView(dot(for: session.status))
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.projectName)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(relativeTime(from: session.lastEventAt, to: now))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                if let title = session.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(activity ?? statusLabel(for: session.status))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
