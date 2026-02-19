import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DeploymentView: View {
    @Binding var config: OctopusConfig
    @ObservedObject var viewModel: ConfigViewModel

    @State private var selectedPkgPath: String = ""
    @State private var xmlFilename: String = "octopus-config.xml"
    @State private var saveXmlCopy: Bool = true
    @State private var showingXmlPreview: Bool = false

    /// Quick check: are the required config fields filled in?
    private var configIsValid: Bool {
        !config.server.isEmpty &&
        !config.domain.isEmpty &&
        !config.service.isEmpty &&
        !config.certificate.isEmpty
    }

    private var canBuild: Bool {
        !selectedPkgPath.isEmpty && configIsValid && !viewModel.isRepackaging
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Deployment")
                .font(.title)
                .fontWeight(.bold)

            Text("Repackage an Octopus installer with your configuration for MDM distribution (JAMF, Mosyle, etc.).")
                .foregroundColor(.secondary)

            Form {
                // ── Source Package ──
                Section("Source Package") {
                    HStack {
                        TextField("Select an Octopus .pkg installer...", text: $selectedPkgPath)
                            .textFieldStyle(.plain)
                            .modifier(EmphasizedField())
                            .disabled(true)

                        Button("Browse...") {
                            browseForPkg()
                        }
                    }
                    Text("Select the original Octopus .pkg installer file. The tool will inject your configuration into it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // ── Configuration ──
                Section("Configuration") {
                    HStack(spacing: 8) {
                        Image(systemName: configIsValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(configIsValid ? .green : .orange)
                        Text(configIsValid ? "Configuration is valid" : "Required fields are missing — check the Required tab")
                            .foregroundColor(configIsValid ? .primary : .orange)
                    }

                    TextField("XML Filename", text: $xmlFilename)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    Text("The configuration file will be placed inside the .app bundle at Contents/Resources/")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Save XML copy alongside .pkg", isOn: $saveXmlCopy)
                    Text("When enabled, an extra copy of the XML file is saved next to the output .pkg for reference.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    DisclosureGroup("Preview XML", isExpanded: $showingXmlPreview) {
                        ScrollView {
                            Text(viewModel.generateXML())
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .background(Color(NSColor.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                // ── Build ──
                Section("Build") {
                    Button(action: {
                        Task {
                            await viewModel.repackagePKG(
                                sourcePkgPath: selectedPkgPath,
                                xmlFilename: xmlFilename,
                                saveXmlCopy: saveXmlCopy
                            )
                        }
                    }) {
                        Label("Build Deployment Package", systemImage: "shippingbox.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canBuild)

                    if !canBuild && !viewModel.isRepackaging {
                        if selectedPkgPath.isEmpty {
                            Text("Select a source .pkg to get started.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !configIsValid {
                            Text("Fill in all required fields before building.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    if viewModel.isRepackaging {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text(viewModel.repackageProgress)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if !viewModel.repackageLog.isEmpty {
                        DisclosureGroup("Build Log") {
                            ScrollView {
                                Text(viewModel.repackageLog)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 150)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // ── Result ──
                if !viewModel.lastOutputPkgPath.isEmpty {
                    Section("Last Build Result") {
                        if viewModel.repackageSucceeded {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Package built successfully")
                                        .fontWeight(.medium)
                                }

                                Text(viewModel.lastOutputPkgPath)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)

                                Button("Reveal in Finder") {
                                    NSWorkspace.shared.selectFile(
                                        viewModel.lastOutputPkgPath,
                                        inFileViewerRootedAtPath: ""
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(10)
                            .background(Color.green.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Build failed")
                                        .fontWeight(.medium)
                                }
                                Text("Check the build log for details.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    // MARK: - File Browsing

    private func browseForPkg() {
        let panel = NSOpenPanel()
        panel.title = "Select Octopus .pkg Installer"
        panel.allowedContentTypes = [UTType(filenameExtension: "pkg") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            selectedPkgPath = url.path
        }
    }
}
