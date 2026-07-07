import SwiftUI
import MusterCore

public struct PanelRootView: View {
    @ObservedObject private var vm: SessionViewModel
    @State private var selected: Session?

    public init(vm: SessionViewModel) { self.vm = vm }

    public var body: some View {
        VStack(spacing: 0) {
            if let session = currentSelection {
                SessionDetailView(session: session) { selected = nil }
            } else {
                header
                Divider()
                SessionListView(vm: vm) { selected = $0 }
            }
        }
        .frame(minWidth: 320, minHeight: 380)
        .background(.regularMaterial)
    }

    /// Keep the detail bound to the freshest copy of the selected session.
    private var currentSelection: Session? {
        guard let selected else { return nil }
        return vm.sessions.first { $0.id == selected.id } ?? selected
    }

    private var header: some View {
        HStack {
            Text("Muster").font(.system(size: 13, weight: .semibold))
            Spacer()
            if vm.badge.isAlert {
                Text("\(vm.badge.needsYouCount) needs you")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
