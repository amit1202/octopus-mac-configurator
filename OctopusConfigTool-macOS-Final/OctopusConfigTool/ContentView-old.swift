import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConfigViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
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
                Label("Password Policy", systemImage: "lock.rotation")
                    .tag(5)
                Label("Shared Accounts", systemImage: "person.3.fill")
                    .tag(6)
                Label("Other", systemImage: "gear")
                    .tag(7)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 220)
            
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
    }
}

struct HeaderView: View {
    @ObservedObject var viewModel: ConfigViewModel
    @State private var showingImportXML = false
    @State private var showingExportXML = false
    @State private var showingImportJSON = false
    @State private var showingExportJSON = false
    
    var body: some View {
        HStack {
            Text("Octopus Config Tool")
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            // Import XML
            Button(action: { showingImportXML = true }) {
                Label("Import XML", systemImage: "square.and.arrow.down")
            }
            .fileImporter(isPresented: $showingImportXML, 
                         allowedContentTypes: [UTType.xml]) { result in
                if case .success(let url) = result {
                    viewModel.importXML(from: url)
                }
            }
            
            // Export XML
            Button(action: { showingExportXML = true }) {
                Label("Export XML", systemImage: "square.and.arrow.up")
            }
            .fileMover(isPresented: $showingExportXML,
                      file: createTempXMLFile(),
                      onCompletion: { _ in })
            
            // Import JSON
            Button(action: { showingImportJSON = true }) {
                Label("Import JSON", systemImage: "doc.badge.arrow.up")
            }
            .fileImporter(isPresented: $showingImportJSON,
                         allowedContentTypes: [UTType.json]) { result in
                if case .success(let url) = result {
                    viewModel.importJSON(from: url)
                }
            }
            
            // Export JSON
            Button(action: { showingExportJSON = true }) {
                Label("Export JSON", systemImage: "doc.badge.arrow.up")
            }
            .fileMover(isPresented: $showingExportJSON,
                      file: createTempJSONFile(),
                      onCompletion: { _ in })
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func createTempXMLFile() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("octopus-config.xml")
        try? viewModel.generateXML().write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }
    
    private func createTempJSONFile() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("octopus-config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(viewModel.config) {
            try? data.write(to: tempURL)
            return tempURL
        }
        return nil
    }
}
// Additional View Components for ContentView.swift

import SwiftUI

struct SSOView: View {
    @Binding var config: OctopusConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Single Sign-On (SSO)")
                .font(.title)
                .fontWeight(.bold)
            
            Form {
                Toggle("Hide Username in SSO Mode", isOn: $config.hideUserNameInSSOMode)
                TextField("SSO Button Caption", text: $config.ssoButtonCaption)
                    .textFieldStyle(.roundedBorder)
                TextField("IDP Metadata URL", text: $config.idpMetadataURL)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct PasswordPolicyView: View {
    @Binding var config: OctopusConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Password Policy")
                .font(.title)
                .fontWeight(.bold)
            
            Form {
                Toggle("Enable Local Password Change", isOn: $config.enableLocalPasswordChange)
                Stepper("Minimum Password Length: \(config.minPasswordLength)", 
                       value: $config.minPasswordLength, in: 4...32)
                Toggle("Require Uppercase", isOn: $config.requireUpperCase)
                Toggle("Require Lowercase", isOn: $config.requireLowerCase)
                Toggle("Require Numbers", isOn: $config.requireNumbers)
                Toggle("Require Special Characters", isOn: $config.requireSpecialChars)
            }
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
                        .textFieldStyle(.roundedBorder)
                    TextField("Name for Remove Shared Account Link", text: $config.nameForRemoveSharedAccountLink)
                        .textFieldStyle(.roundedBorder)
                }
            }
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
                Picker("Logging Level", selection: $config.logging) {
                    Text("None").tag("none")
                    Text("Error").tag("error")
                    Text("Info").tag("info")
                    Text("Debug").tag("debug")
                    Text("Verbose").tag("verbose")
                }
                .pickerStyle(.menu)
                
                TextField("Max Audit File Size (KB)", text: $config.maxAuditFileSize)
                    .textFieldStyle(.roundedBorder)
                TextField("Max Log File Size (KB)", text: $config.maxLogFileSize)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
