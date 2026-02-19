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

// MARK: - App Mode

enum AppMode {
    case basic
    case advanced
}

// MARK: - Advanced Tab

enum AdvancedTab: Int, CaseIterable {
    case server = 0
    case required = 1
    case features = 2
    case authentication = 3
    case fileVault = 4
    case sso = 5
    case passwordSync = 6
    case sharedAccounts = 7
    case other = 8
    case deployment = 9

    var label: String {
        switch self {
        case .server: return "Server & Import"
        case .required: return "Required"
        case .features: return "Features"
        case .authentication: return "Authentication"
        case .fileVault: return "FileVault"
        case .sso: return "SSO"
        case .passwordSync: return "Password Sync"
        case .sharedAccounts: return "Shared Accounts"
        case .other: return "Other"
        case .deployment: return "Deployment"
        }
    }

    var icon: String {
        switch self {
        case .server: return "cloud.fill"
        case .required: return "key.fill"
        case .features: return "star.fill"
        case .authentication: return "lock.shield.fill"
        case .fileVault: return "lock.fill"
        case .sso: return "person.2.fill"
        case .passwordSync: return "lock.rotation"
        case .sharedAccounts: return "person.3.fill"
        case .other: return "gear"
        case .deployment: return "shippingbox.fill"
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var viewModel = ConfigViewModel()
    @State private var appMode: AppMode = .basic
    @State private var selectedTab: AdvancedTab = .server

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: logo + title + mode picker + actions
            TopBarView(viewModel: viewModel, appMode: $appMode)

            Divider()

            // Body
            if appMode == .basic {
                BasicModeView(viewModel: viewModel)
            } else {
                AdvancedModeView(viewModel: viewModel, selectedTab: $selectedTab)
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

// MARK: - Top Bar

struct TopBarView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @Binding var appMode: AppMode

    var body: some View {
        HStack(spacing: 12) {
            // Logo + title
            Image("sdo-logo-blue-icon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))

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

            // Basic / Advanced picker
            Picker("Mode", selection: $appMode) {
                Text("Basic").tag(AppMode.basic)
                Text("Advanced").tag(AppMode.advanced)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
            .help("Basic: quick setup with defaults. Advanced: full control over all settings.")

            Divider().frame(height: 20)

            // Profiles menu
            ProfilesMenuView(viewModel: viewModel)

            Divider().frame(height: 20)

            // Export XML
            Button(action: { viewModel.exportXMLWithPanel() }) {
                Label("Export XML", systemImage: "square.and.arrow.up")
            }

            // Validate XML
            Button(action: { viewModel.validateXML() }) {
                Label("Validate", systemImage: "checkmark.shield")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Basic Mode

struct BasicModeView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var showingImportXML = false
    @State private var showingXmlPreview = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Setup")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Connect to your Octopus server or import an XML file. All feature settings will use recommended defaults.")
                        .foregroundColor(.secondary)
                }

                Divider()

                // ── Section 1: Import XML ──────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Import Configuration XML", systemImage: "square.and.arrow.down")
                            .font(.headline)

                        Text("If you have an existing configuration XML file, import it here to load all settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: { showingImportXML = true }) {
                            Label("Choose XML File…", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .fileImporter(
                            isPresented: $showingImportXML,
                            allowedContentTypes: [UTType.xml],
                            allowsMultipleSelection: false
                        ) { result in
                            switch result {
                            case .success(let urls):
                                guard let url = urls.first else { return }
                                if url.startAccessingSecurityScopedResource() {
                                    defer { url.stopAccessingSecurityScopedResource() }
                                    viewModel.importXML(from: url)
                                }
                            case .failure(let error):
                                viewModel.showErrorAlert("Failed to select file: \(error.localizedDescription)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                // Divider between import and server
                HStack {
                    Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                    Text("or connect to a server")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                }

                // ── Section 2: Server Connection ──────────────────────────
                GroupBox {
                    ServerConnectionView(config: $viewModel.config, viewModel: viewModel)
                        .padding(8)
                }

                Divider()

                // ── Section 3: XML Preview ────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("XML Preview", systemImage: "doc.text.magnifyingglass")
                            .font(.headline)

                        Text("Preview the configuration XML that will be generated using Basic mode defaults.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        DisclosureGroup("Show XML Preview", isExpanded: $showingXmlPreview) {
                            ScrollView {
                                Text(viewModel.generateBasicXML())
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 260)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.top, 6)
                        }

                        HStack(spacing: 10) {
                            Button(action: { viewModel.exportXMLWithPanel() }) {
                                Label("Export XML…", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(action: { viewModel.validateXML() }) {
                                Label("Validate XML", systemImage: "checkmark.shield")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }

                Divider()

                // ── Section 4: Deployment ─────────────────────────────────
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Deployment", systemImage: "shippingbox.fill")
                            .font(.headline)
                        Text("Repackage an Octopus installer with your configuration for MDM distribution.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                    DeploymentView(config: $viewModel.config, viewModel: viewModel)
                        .padding(.horizontal, 4)
                }

                // ── Info note ─────────────────────────────────────────────
                GroupBox {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Basic Mode Defaults")
                                .fontWeight(.semibold)
                            Text("All feature settings (Authentication, FileVault, SSO, etc.) use recommended defaults. Switch to Advanced mode to customise individual settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
            }
            .padding(24)
        }
    }
}

// MARK: - Advanced Mode

struct AdvancedModeView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @Binding var selectedTab: AdvancedTab

    var body: some View {
        NavigationSplitView {
            List(AdvancedTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.label, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    advancedContent(for: selectedTab)
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func advancedContent(for tab: AdvancedTab) -> some View {
        switch tab {
        case .server:
            AdvancedServerImportView(viewModel: viewModel)
        case .required:
            RequiredFieldsView(config: $viewModel.config)
        case .features:
            FeaturesView(config: $viewModel.config)
        case .authentication:
            AuthenticationView(config: $viewModel.config, viewModel: viewModel)
        case .fileVault:
            FileVaultView(config: $viewModel.config, viewModel: viewModel)
        case .sso:
            SSOView(config: $viewModel.config)
        case .passwordSync:
            PasswordPolicyView(config: $viewModel.config)
        case .sharedAccounts:
            SharedAccountsView(config: $viewModel.config)
        case .other:
            OtherSettingsView(config: $viewModel.config)
        case .deployment:
            DeploymentView(config: $viewModel.config, viewModel: viewModel)
        }
    }
}

// MARK: - Advanced: Server & Import tab

struct AdvancedServerImportView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var showingImportXML = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("Server & Import")
                .font(.title)
                .fontWeight(.bold)

            // Import XML card
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Import Configuration XML", systemImage: "square.and.arrow.down")
                        .font(.headline)

                    Text("Load all settings from an existing XML configuration file.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: { showingImportXML = true }) {
                        Label("Choose XML File…", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .fileImporter(
                        isPresented: $showingImportXML,
                        allowedContentTypes: [UTType.xml],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            guard let url = urls.first else { return }
                            if url.startAccessingSecurityScopedResource() {
                                defer { url.stopAccessingSecurityScopedResource() }
                                viewModel.importXML(from: url)
                            }
                        case .failure(let error):
                            viewModel.showErrorAlert("Failed to select file: \(error.localizedDescription)")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }

            HStack {
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
                Text("or connect to a server")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle().frame(height: 1).foregroundColor(.secondary.opacity(0.3))
            }

            // Server connection (full view)
            ServerConnectionView(config: $viewModel.config, viewModel: viewModel)
        }
    }
}

// MARK: - Document wrappers for fileExporter

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

// MARK: - Additional View Components (SSO, Password, Shared Accounts, Other)

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
