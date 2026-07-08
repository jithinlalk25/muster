import SwiftUI
import MusterCore
import AppKit

public struct SessionListView: View {
    @ObservedObject private var vm: SessionViewModel
    private let onSelect: (Session) -> Void

    public init(vm: SessionViewModel, onSelect: @escaping (Session) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        Group {
            if vm.sessions.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                    Text("No active sessions")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.sessions) { session in
                            Button { onSelect(session) } label: {
                                SessionRowView(session: session, now: Date())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .contextMenu {
                                if let url = revealTarget(for: session) {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    }
                                    Button("Copy path") {
                                        NSPasteboard.general.clearContents()
                                        _ = NSPasteboard.general.setString(url.path, forType: .string)
                                    }
                                }
                            }
                            Divider().opacity(0.4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}
