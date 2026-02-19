import SwiftUI
import UniformTypeIdentifiers

struct FileVaultView: View {
    @Binding var config: OctopusConfig
    @ObservedObject var viewModel: ConfigViewModel
    @State private var commandOutput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FileVault Settings")
                .font(.title)
                .fontWeight(.bold)

            Form {
                // MARK: - FileVault Enable/Disable
                Section("FileVault") {
                    Toggle("Enable FileVault", isOn: $config.enableFileVault)
                    Text("Enable or disable FileVault disk encryption management.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Deployment Type
                Section("Deployment Type") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FileVault Deployment")
                            .font(.callout)
                            .fontWeight(.medium)
                        Picker("FileVault Deployment", selection: $config.fileVaultDeploymentType) {
                            Text("None").tag("")
                            Text("Server").tag("server")
                            Text("Client").tag("client")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("Server: Password managed by server. Client: User creates their own FileVault password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!config.enableFileVault)
                .opacity(config.enableFileVault ? 1.0 : 0.5)

                // MARK: - FileVault Login Settings
                Section("FileVault Login") {
                    LabeledInputField(
                        label: "FileVault User",
                        text: $config.fileVaultUser,
                        placeholder: "e.g. _fvunlock"
                    )

                    if config.fileVaultDeploymentType == "client" {
                        LabeledInputField(
                            label: "FileVault Password / Key",
                            text: $config.fileVault,
                            placeholder: "Client FileVault password",
                            hint: "Client mode: user creates their own FileVault password."
                        )
                    }

                    Toggle("Auto-Enable FileVault", isOn: $config.autoEnableFileVault)
                    Text("Automatically enable FileVault for new users.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!config.enableFileVault)
                .opacity(config.enableFileVault ? 1.0 : 0.5)

                // MARK: - Recovery Key
                Section("Recovery Key") {
                    LabeledInputField(
                        label: "Recovery Key Location",
                        text: $config.fileVaultRecoveryKey,
                        placeholder: "/var/octopus/recovery",
                        hint: "Path where recovery keys are stored on the system."
                    )

                    Toggle("Auto-Rotate Recovery Key", isOn: $config.autoRotateRecoveryKey)

                    if config.autoRotateRecoveryKey {
                        LabeledInputField(
                            label: "Rotation Command",
                            text: $config.recoveryKeyRotationCommand,
                            placeholder: "sudo fdesetup changerecovery -personal"
                        )
                    }

                    Divider()

                    Toggle("Save Recovery Key as File", isOn: $config.recoveryKeySaveAsFile)
                    if config.recoveryKeySaveAsFile {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("File Path")
                                .font(.callout)
                                .fontWeight(.medium)
                            HStack {
                                TextField("e.g. /var/octopus/recovery-key.txt", text: $config.recoveryKeyFilePath)
                                    .textFieldStyle(.plain)
                                    .modifier(EmphasizedField())
                                Button("Browse…") {
                                    let panel = NSSavePanel()
                                    panel.title = "Save Recovery Key"
                                    panel.nameFieldStringValue = "recovery-key.txt"
                                    panel.allowedContentTypes = [.plainText]
                                    if panel.runModal() == .OK, let url = panel.url {
                                        config.recoveryKeyFilePath = url.path
                                    }
                                }
                            }
                            Text("The recovery key will be saved to this file path.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Send Recovery Key via Email", isOn: $config.recoveryKeySendEmail)
                    if config.recoveryKeySendEmail {
                        LabeledInputField(
                            label: "Email Address",
                            text: $config.recoveryKeyEmailAddress,
                            placeholder: "admin@company.com",
                            hint: "The recovery key will be sent to this email address."
                        )
                    }
                }
                .disabled(!config.enableFileVault)
                .opacity(config.enableFileVault ? 1.0 : 0.5)

                // MARK: - CLI Commands
                Section("CLI Commands") {
                    HStack {
                        Button("Check FileVault Status") {
                            Task { await viewModel.checkFileVaultStatus() }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("List FileVault Users") {
                            Task { await viewModel.listFileVaultUsers() }
                        }
                        .buttonStyle(.bordered)
                    }

                    if viewModel.commandRunner.isRunning {
                        ProgressView("Executing command…")
                    }

                    if !viewModel.commandRunner.output.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.callout)
                                .fontWeight(.medium)
                            TextEditor(text: .constant(viewModel.commandRunner.output))
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 120)
                                .modifier(EmphasizedField())
                        }
                    }
                }

                // MARK: - Generate / Rotate Recovery Key
                Section("Generate / Rotate Recovery Key") {
                    Text("Provide a local macOS user and password to generate or rotate the FileVault recovery key.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local User")
                            .font(.callout)
                            .fontWeight(.medium)
                        HStack {
                            Picker("Local User", selection: $viewModel.selectedLocalUser) {
                                if viewModel.localUsers.isEmpty {
                                    Text("No users loaded").tag("")
                                }
                                ForEach(viewModel.localUsers, id: \.self) { user in
                                    Text(user).tag(user)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: 250)

                            Button("Load Users") {
                                Task { await viewModel.loadLocalUsers() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    LabeledSecureField(
                        label: "User Password",
                        text: $viewModel.localUserPassword
                    )
                    .frame(maxWidth: 350)

                    Button("Rotate Recovery Key") {
                        Task { await viewModel.rotateRecoveryKey() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.selectedLocalUser.isEmpty || viewModel.localUserPassword.isEmpty)

                    if !viewModel.lastRecoveryKey.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Recovery Key")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(viewModel.lastRecoveryKey)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(viewModel.lastRecoveryKey, forType: .string)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    viewModel.saveRecoveryKeyToFile()
                                } label: {
                                    Label("Save to File", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    viewModel.emailRecoveryKey()
                                } label: {
                                    Label("Send via Email", systemImage: "envelope")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onAppear {
            if viewModel.localUsers.isEmpty {
                Task { await viewModel.loadLocalUsers() }
            }
        }
    }
}
