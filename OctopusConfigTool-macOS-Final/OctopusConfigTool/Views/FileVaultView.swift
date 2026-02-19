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
                // MARK: - FileVault Enable/Disable at the top
                Section("FileVault") {
                    Toggle("Enable FileVault", isOn: $config.enableFileVault)
                    Text("Enable or disable FileVault disk encryption management.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: - Deployment Type
                Section("Deployment Type") {
                    Picker("FileVault Deployment", selection: $config.fileVaultDeploymentType) {
                        Text("None").tag("")
                        Text("Server").tag("server")
                        Text("Client").tag("client")
                    }
                    .pickerStyle(.segmented)
                    Text("Server: Password managed by server. Client: User creates their own FileVault password.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!config.enableFileVault)
                .opacity(config.enableFileVault ? 1.0 : 0.5)

                // MARK: - FileVault Login Settings
                Section("FileVault Login") {
                    TextField("FileVault User", text: $config.fileVaultUser)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())

                    if config.fileVaultDeploymentType == "client" {
                        TextField("FileVault Password/Key", text: $config.fileVault)
                            .textFieldStyle(.plain)
                            .modifier(EmphasizedField())
                        Text("Client mode: user creates their own FileVault password.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Auto-Enable FileVault", isOn: $config.autoEnableFileVault)
                    Text("Automatically enable FileVault for new users.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .disabled(!config.enableFileVault)
                .opacity(config.enableFileVault ? 1.0 : 0.5)

                // MARK: - Recovery Key (Separate Section)
                Section("Recovery Key") {
                    TextField("Recovery Key Location", text: $config.fileVaultRecoveryKey)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    Text("Path where recovery keys are stored on the system.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Auto-Rotate Recovery Key", isOn: $config.autoRotateRecoveryKey)

                    if config.autoRotateRecoveryKey {
                        TextField("Rotation Command", text: $config.recoveryKeyRotationCommand)
                            .textFieldStyle(.plain)
                            .modifier(EmphasizedField())
                    }

                    Divider()

                    Toggle("Save Recovery Key as File", isOn: $config.recoveryKeySaveAsFile)
                    if config.recoveryKeySaveAsFile {
                        HStack {
                            TextField("File Path", text: $config.recoveryKeyFilePath)
                                .textFieldStyle(.plain)
                                .modifier(EmphasizedField())
                            Button("Browse...") {
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

                    Toggle("Send Recovery Key via Email", isOn: $config.recoveryKeySendEmail)
                    if config.recoveryKeySendEmail {
                        TextField("Email Address", text: $config.recoveryKeyEmailAddress)
                            .textFieldStyle(.plain)
                            .modifier(EmphasizedField())
                        Text("The recovery key will be sent to this email address.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(!config.enableFileVault)
                .opacity(config.enableFileVault ? 1.0 : 0.5)

                // MARK: - CLI Commands
                Section("CLI Commands") {
                    HStack {
                        Button("Check FileVault Status") {
                            Task {
                                await viewModel.checkFileVaultStatus()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("List FileVault Users") {
                            Task {
                                await viewModel.listFileVaultUsers()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    if viewModel.commandRunner.isRunning {
                        ProgressView("Executing command...")
                    }

                    if !viewModel.commandRunner.output.isEmpty {
                        Text("Output:")
                            .font(.headline)
                        TextEditor(text: .constant(viewModel.commandRunner.output))
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 120)
                            .modifier(EmphasizedField())
                    }
                }

                // MARK: - Generate / Rotate Recovery Key
                Section("Generate / Rotate Recovery Key") {
                    Text("Provide a local macOS user and password to generate or rotate the FileVault recovery key.")
                        .font(.caption)
                        .foregroundColor(.secondary)

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
                        .frame(maxWidth: 250)

                        Button("Load Users") {
                            Task {
                                await viewModel.loadLocalUsers()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    SecureField("User Password", text: $viewModel.localUserPassword)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                        .frame(maxWidth: 350)

                    HStack {
                        Button("Rotate Recovery Key") {
                            Task {
                                await viewModel.rotateRecoveryKey()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.selectedLocalUser.isEmpty || viewModel.localUserPassword.isEmpty)
                    }

                    if !viewModel.lastRecoveryKey.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Recovery Key:")
                                    .fontWeight(.semibold)
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
                Task {
                    await viewModel.loadLocalUsers()
                }
            }
        }
    }
}
