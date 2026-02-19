import SwiftUI

struct AuthenticationView: View {
    @Binding var config: OctopusConfig
    @ObservedObject var viewModel: ConfigViewModel

    // For the "add single method" picker
    @State private var selectedMethodToAdd: String = OctopusConfig.standardAuthMethods[0].method

    /// Standard methods not yet added to the current config
    private var availableToAdd: [AuthenticationMethod] {
        OctopusConfig.standardAuthMethods.filter { standard in
            !config.authenticationMethods.contains { $0.method == standard.method }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Authentication Settings")
                .font(.title)
                .fontWeight(.bold)

            Form {
                // ── Basic Auth Toggles ──────────────────────────────────
                Section("Basic Authentication") {
                    Toggle("Allow Password Login", isOn: $config.validPasswordIsSufficient)
                    Toggle("Allow Password Login While Offline", isOn: $config.validPasswordIsSufficientForOffline)
                    Toggle("Multi-Factor Authentication (MFA)", isOn: $config.mfa)
                    Toggle("Force Lock After Offline Login", isOn: $config.forceLockAfterOfflineLogin)
                    Toggle("Password-Free Experience", isOn: $config.passwordfree)
                    Toggle("Third-Party Authentication", isOn: $config.thirdparty)
                    Toggle("Direct Login", isOn: $config.directLogin)
                    Text("When enabled, users skip the Octopus Login screen after entering FileVault credentials.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("Custom Unlock Screen", isOn: $config.customUnlockScreen)
                }

                // ── Authentication Methods ──────────────────────────────
                Section {
                    // ── Toolbar: add controls ──
                    VStack(alignment: .leading, spacing: 10) {

                        // Add All
                        Button(action: { viewModel.addAllStandardMethods() }) {
                            Label("Add All Standard Methods", systemImage: "rectangle.stack.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)

                        Divider()

                        // Add Single
                        HStack(spacing: 8) {
                            if availableToAdd.isEmpty {
                                Text("All standard methods already added.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Picker("Add method", selection: $selectedMethodToAdd) {
                                    ForEach(availableToAdd, id: \.method) { m in
                                        Text(m.methodFriendlyName.isEmpty ? m.method : m.methodFriendlyName)
                                            .tag(m.method)
                                    }
                                }
                                .labelsHidden()
                                .frame(maxWidth: 260)
                                .onAppear {
                                    // Keep selection valid when list shrinks
                                    if !availableToAdd.contains(where: { $0.method == selectedMethodToAdd }),
                                       let first = availableToAdd.first {
                                        selectedMethodToAdd = first.method
                                    }
                                }
                                .onChange(of: availableToAdd.count) {
                                    if !availableToAdd.contains(where: { $0.method == selectedMethodToAdd }),
                                       let first = availableToAdd.first {
                                        selectedMethodToAdd = first.method
                                    }
                                }

                                Button(action: { addSingleMethod() }) {
                                    Label("Add", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.bordered)
                                .disabled(availableToAdd.isEmpty)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // ── Method rows ──
                    if config.authenticationMethods.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.secondary)
                            Text("No authentication methods configured. Add at least one.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach($config.authenticationMethods) { $method in
                            AuthMethodRow(method: $method) {
                                // Delete this method
                                config.authenticationMethods.removeAll { $0.id == method.id }
                            }
                        }
                        .onDelete { indexSet in
                            config.authenticationMethods.remove(atOffsets: indexSet)
                        }
                        .onMove { from, to in
                            config.authenticationMethods.move(fromOffsets: from, toOffset: to)
                        }
                    }

                } header: {
                    HStack {
                        Text("Authentication Methods")
                        Spacer()
                        if !config.authenticationMethods.isEmpty {
                            Text("\(config.authenticationMethods.count) method\(config.authenticationMethods.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - Actions

    private func addSingleMethod() {
        guard let standard = OctopusConfig.standardAuthMethods.first(where: { $0.method == selectedMethodToAdd }),
              !config.authenticationMethods.contains(where: { $0.method == selectedMethodToAdd })
        else { return }

        config.authenticationMethods.append(
            AuthenticationMethod(
                method: standard.method,
                methodFriendlyName: standard.methodFriendlyName,
                message: standard.message,
                passwordHint: standard.passwordHint
            )
        )

        // Advance picker to next available method
        if let next = availableToAdd.first(where: { $0.method != selectedMethodToAdd }) {
            selectedMethodToAdd = next.method
        }
    }
}

// MARK: - Method Row

struct AuthMethodRow: View {
    @Binding var method: AuthenticationMethod
    var onDelete: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header row (always visible) ──
            HStack(spacing: 8) {
                // Expand/collapse chevron
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.methodFriendlyName.isEmpty ? method.method : method.methodFriendlyName)
                        .fontWeight(.medium)
                    if !method.methodFriendlyName.isEmpty {
                        Text(method.method)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .help("Remove this authentication method")
            }
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }
            .padding(.vertical, 6)

            // ── Expanded detail fields ──
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    Group {
                        LabeledField("Method Key", text: $method.method)
                        LabeledField("Friendly Name", text: $method.methodFriendlyName)
                        LabeledField("Message", text: $method.message)
                        LabeledField("Password Hint", text: $method.passwordHint)
                    }
                }
                .padding(.leading, 20)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(8)
    }
}

// MARK: - Small helper

private struct LabeledField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .modifier(EmphasizedField())
        }
    }
}
