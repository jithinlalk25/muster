import SwiftUI
import MusterCore

public struct SessionDetailView: View {
    private let session: Session
    private let onBack: () -> Void
    @StateObject private var transcript: TranscriptViewModel

    public init(session: Session, onBack: @escaping () -> Void) {
        self.session = session
        self.onBack = onBack
        _transcript = StateObject(wrappedValue: TranscriptViewModel(path: session.transcriptPath ?? ""))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                StatusDotView(dot(for: session.status))
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName).font(.system(size: 13, weight: .semibold))
                    Text(transcript.title ?? session.title ?? statusLabel(for: session.status))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(transcript.messages.enumerated()), id: \.offset) { _, msg in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.role == .user ? "You" : msg.role == .assistant ? "Claude" : "—")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(msg.text)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(12)
            }
        }
        .onAppear { transcript.start() }
        .onDisappear { transcript.stop() }
    }
}
