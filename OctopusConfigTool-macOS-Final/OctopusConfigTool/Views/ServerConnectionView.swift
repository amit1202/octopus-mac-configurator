import SwiftUI

struct ServerConnectionView: View {
    @Binding var config: OctopusConfig
    @ObservedObject var viewModel: ConfigViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Server Connection")
                .font(.title)
                .fontWeight(.bold)

            Text("Connect to your Octopus management console to download service configurations directly.")
                .foregroundColor(.secondary)

            Form {
                // ── Server Settings ──
                Section("Server Settings") {
                    LabeledInputField(
                        label: "Octopus Server URL",
                        text: $viewModel.octopusServerURL,
                        placeholder: "https://yourserver.doubleoctopus.io"
                    )
                    LabeledInputField(
                        label: "Admin Email",
                        text: $viewModel.octopusAdminEmail,
                        placeholder: "admin@company.com"
                    )
                }

                // ── Authentication ──
                Section("Authentication") {
                    Picker("Auth Method", selection: $viewModel.selectedAuthMethod) {
                        Text("Octopus Authenticator").tag(AuthMethod.authenticator)
                        Text("Password").tag(AuthMethod.password)
                    }
                    .pickerStyle(.segmented)

                    if viewModel.selectedAuthMethod == .password {
                        LabeledSecureField(label: "Password", text: $viewModel.serverPassword)
                    } else {
                        Text("A push notification will be sent to your Octopus Authenticator app. Approve it to connect.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !viewModel.isConnected {
                        Button(action: {
                            Task {
                                await viewModel.connectToServer()
                            }
                        }) {
                            Label(
                                viewModel.selectedAuthMethod == .authenticator
                                    ? "Send Push & Connect"
                                    : "Connect",
                                systemImage: "network"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canConnect)
                    }

                    if viewModel.isConnecting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text(viewModel.connectionStatus)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if viewModel.isConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to \(viewModel.octopusServerURL)")
                                .foregroundColor(.primary)
                            Spacer()
                            Button("Disconnect") {
                                viewModel.disconnect()
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Services (only when connected) ──
                if viewModel.isConnected {
                    Section("Services") {
                        if viewModel.isLoadingServices {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading services...")
                                    .foregroundColor(.secondary)
                            }
                        } else if viewModel.availableServices.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("No services found on this server.")
                                    .foregroundColor(.secondary)
                            }

                            Button("Retry") {
                                Task {
                                    await viewModel.fetchServices()
                                }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Picker("Select Service", selection: $viewModel.selectedService) {
                                Text("-- Select a service --").tag(nil as OctopusService?)
                                ForEach(viewModel.availableServices) { service in
                                    Text(service.name).tag(service as OctopusService?)
                                }
                            }

                            Button(action: {
                                Task {
                                    await viewModel.downloadAndLoadConfig()
                                }
                            }) {
                                Label("Download & Load Configuration", systemImage: "arrow.down.doc")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.selectedService == nil || viewModel.isDownloadingConfig)

                            if viewModel.isDownloadingConfig {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Downloading configuration...")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }

                            if viewModel.selectedService != nil && !viewModel.isDownloadingConfig {
                                Text("This will replace your current configuration with the one from the server.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
