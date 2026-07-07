import SwiftUI

public struct OnboardingView: View {
    @ObservedObject private var model: OnboardingModel
    private let onClose: () -> Void

    public init(model: OnboardingModel, onClose: @escaping () -> Void) {
        self.model = model
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set up Muster")
                .font(.system(size: 18, weight: .semibold))
            Text("Muster watches your Claude Code sessions using hooks. It will add the following to ~/.claude/settings.json. Your existing settings are preserved.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                Text(model.isInstalled ? "Hooks are installed." : model.diff.addedLines.joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(height: 180)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            Toggle("Launch Muster at login", isOn: $model.launchAtLogin)
                .font(.system(size: 12))
                .onChange(of: model.launchAtLogin) { newValue in
                    model.setLaunch(newValue)
                }

            if let error = model.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                if model.isInstalled {
                    Button("Uninstall hooks") { model.uninstall() }
                    Spacer()
                    Button("Done") { onClose() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Not now") { onClose() }
                    Spacer()
                    Button("Install hooks") {
                        model.install()
                        if model.isInstalled && model.lastError == nil { onClose() }
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
