import SwiftUI
import UniformTypeIdentifiers

// MARK: - Emphasised Field Modifier

/// Custom modifier that gives text fields a visible border and subtle background
/// so they stand out against the white window (fixes white-on-white issue).
struct EmphasizedField: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(6)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(6)
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ConfigViewModel()
    @State private var selectedTab: Int? = 0

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                Label("Required", systemImage: "key.fill")
                    .tag(0)
                Label("Features", systemImage: "star.fill")
                    .tag(1)
                Label("Authentication", systemImage: "lock.shield.fill")
                    .tag(2)
                Label("FileVault", systemImage: "lock.fill")
                    .tag(3)
                Label("SSO", systemImage: "person.2.fill")
                    .tag(4)
                Label("Password Sync", systemImage: "lock.rotation")
                    .tag(5)
                Label("Shared Accounts", systemImage: "person.3.fill")
                    .tag(6)
                Label("Other", systemImage: "gear")
                    .tag(7)

                Divider()

                Label("Server", systemImage: "cloud.fill")
                    .tag(9)
                Label("Deployment", systemImage: "shippingbox.fill")
                    .tag(8)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
        } detail: {
            // Main Content
            VStack(spacing: 0) {
                // Header
                HeaderView(viewModel: viewModel)

                Divider()

                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case 0:
                            RequiredFieldsView(config: $viewModel.config)
                        case 1:
                            FeaturesView(config: $viewModel.config)
                        case 2:
                            AuthenticationView(config: $viewModel.config, viewModel: viewModel)
                        case 3:
                            FileVaultView(config: $viewModel.config, viewModel: viewModel)
                        case 4:
                            SSOView(config: $viewModel.config)
                        case 5:
                            PasswordPolicyView(config: $viewModel.config)
                        case 6:
                            SharedAccountsView(config: $viewModel.config)
                        case 7:
                            OtherSettingsView(config: $viewModel.config)
                        case 8:
                            DeploymentView(config: $viewModel.config, viewModel: viewModel)
                        case 9:
                            ServerConnectionView(config: $viewModel.config, viewModel: viewModel)
                        default:
                            Text("Select a section")
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .alert(
            viewModel.pendingProfileAction.map { action in
                switch action {
                case .saveNew: return "Save New Profile"
                case .rename: return "Rename Profile"
                }
            } ?? "Profile Name",
            isPresented: $viewModel.showProfileNamePrompt
        ) {
            TextField("Profile name", text: $viewModel.profileNameInput)
            Button("Save") {
                viewModel.confirmProfileNameAction()
            }
            Button("Cancel", role: .cancel) {
                viewModel.pendingProfileAction = nil
                viewModel.profileNameInput = ""
            }
        } message: {
            Text(viewModel.pendingProfileAction.map { action in
                switch action {
                case .saveNew: return "Enter a name for this profile:"
                case .rename: return "Enter the new name:"
                }
            } ?? "")
        }
        .alert("Delete Profile", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.confirmDeleteProfile()
            }
            Button("Cancel", role: .cancel) {
                viewModel.profileToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete the profile '\(viewModel.profileToDelete?.name ?? "")'? This cannot be undone.")
        }
    }
}

struct HeaderView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var showingImportXML = false
    var body: some View {
        HStack {
            Image("sdo-logo-blue-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.trailing, 6)
            
            Text("Octopus Config Tool")
                .font(.title2)
                .fontWeight(.bold)

            if viewModel.isConnected {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Profiles menu
            ProfilesMenuView(viewModel: viewModel)

            Divider()
                .frame(height: 20)

            // Import XML
            Button(action: { showingImportXML = true }) {
                Label("Import XML", systemImage: "square.and.arrow.down")
            }
            .fileImporter(
                isPresented: $showingImportXML,
                allowedContentTypes: [UTType.xml],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    // Request access to the file
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        viewModel.importXML(from: url)
                    }
                case .failure(let error):
                    viewModel.showErrorAlert("Failed to select file: \(error.localizedDescription)")
                }
            }
            
            // Export XML (NSSavePanel with custom name/path)
            Button(action: { viewModel.exportXMLWithPanel() }) {
                Label("Export XML", systemImage: "square.and.arrow.up")
            }

            // Validate XML
            Button(action: { viewModel.validateXML() }) {
                Label("Validate", systemImage: "checkmark.shield")
            }
            
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// Document wrappers for fileExporter
struct XMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.xml] }
    
    var xml: String
    
    init(xml: String) {
        self.xml = xml
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        xml = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = xml.data(using: .utf8)!
        return .init(regularFileWithContents: data)
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var config: OctopusConfig
    
    init(config: OctopusConfig) {
        self.config = config
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        config = try JSONDecoder().decode(OctopusConfig.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        return .init(regularFileWithContents: data)
    }
}

// Additional View Components
struct SSOView: View {
    @Binding var config: OctopusConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Single Sign-On (SSO)")
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section("SSO Portal") {
                    TextField("SSO URL", text: $config.ssourl)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    Picker("SSO Browser", selection: $config.ssobrowser) {
                        Text("System Default").tag("system")
                        Text("Safari").tag("safari")
                        Text("Chrome").tag("chrome")
                        Text("Firefox").tag("firefox")
                    }
                    .pickerStyle(.menu)
                }

                Section("Advanced") {
                    Toggle("Hide Username in SSO Mode", isOn: $config.hideUserNameInSSOMode)
                    TextField("SSO Button Caption", text: $config.ssoButtonCaption)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    TextField("IDP Metadata URL", text: $config.idpMetadataURL)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct PasswordPolicyView: View {
    @Binding var config: OctopusConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Password Sync & Rotation")
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section("Password Sync") {
                    Toggle("Automatic Password Sync", isOn: $config.autoPasswordSync)
                    Text("When enabled, passwords sync automatically when the server rotates the user's password.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Force Password Rotation") {
                    Toggle("Force Password Rotation", isOn: $config.forcePasswordRotation)
                    Text("When enabled, periodic password rotation is performed for users who authenticate infrequently.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if config.forcePasswordRotation {
                        TextField("Password Rotation Period (days)", text: $config.passwordRotationPeriod)
                            .textFieldStyle(.plain)
                            .modifier(EmphasizedField())
                        Text("Default: 30 days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct SharedAccountsView: View {
    @Binding var config: OctopusConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Shared Accounts")
                .font(.title)
                .fontWeight(.bold)
            
            Form {
                Toggle("Enable Shared Accounts", isOn: $config.sharedaccounts)
                if config.sharedaccounts {
                    Toggle("Show Shared Account Link", isOn: $config.showSharedAccountLink)
                    Toggle("Default to Regular Account", isOn: $config.defaultToRegularAccount)
                    TextField("Name for Use Shared Account Link", text: $config.nameForUseSharedAccountLink)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    TextField("Name for Remove Shared Account Link", text: $config.nameForRemoveSharedAccountLink)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                }
            }
            .formStyle(.grouped)
        }
    }
}

struct OtherSettingsView: View {
    @Binding var config: OctopusConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Other Settings")
                .font(.title)
                .fontWeight(.bold)

            Form {
                Section("Logging") {
                    Picker("Logging Level", selection: $config.logging) {
                        Text("None").tag("none")
                        Text("Error").tag("error")
                        Text("Info").tag("info")
                        Text("Debug").tag("debug")
                        Text("Verbose").tag("verbose")
                    }
                    .pickerStyle(.menu)

                    TextField("Max Log File Size (KB)", text: $config.maxLogFileSize)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                }

                Section("Audit") {
                    TextField("Max Audit File Size (KB)", text: $config.maxAuditFileSize)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    Toggle("Send Audit to Server", isOn: $config.sendAuditToServer)
                }
            }
            .formStyle(.grouped)
        }
    }
}

