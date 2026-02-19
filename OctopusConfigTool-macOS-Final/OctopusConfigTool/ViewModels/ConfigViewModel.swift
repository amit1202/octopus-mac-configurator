import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum AuthMethod: String, CaseIterable {
    case authenticator
    case password
}

@MainActor
class ConfigViewModel: ObservableObject {
    @Published var config = OctopusConfig()
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var alertTitle = "Success"

    // FileVault CLI credentials
    @Published var localUsers: [String] = []
    @Published var selectedLocalUser: String = ""
    @Published var localUserPassword: String = ""
    @Published var lastRecoveryKey: String = ""

    // Deployment
    @Published var isRepackaging: Bool = false
    @Published var repackageProgress: String = ""
    @Published var repackageLog: String = ""
    @Published var lastOutputPkgPath: String = ""
    @Published var repackageSucceeded: Bool = false

    // Profiles
    @Published var profiles: [Profile] = []
    @Published var showProfileNamePrompt: Bool = false
    @Published var profileNameInput: String = ""
    @Published var pendingProfileAction: ProfileAction? = nil
    @Published var showDeleteConfirmation: Bool = false
    @Published var profileToDelete: Profile? = nil

    enum ProfileAction {
        case saveNew
        case rename(Profile)
    }

    let profileManager = ProfileManager.shared

    // Server Connection — persisted settings
    @Published var octopusServerURL: String {
        didSet { UserDefaults.standard.set(octopusServerURL, forKey: "octopusServerURL") }
    }
    @Published var octopusAdminEmail: String {
        didSet { UserDefaults.standard.set(octopusAdminEmail, forKey: "octopusAdminEmail") }
    }

    // Server Connection — auth state (in-memory only)
    @Published var selectedAuthMethod: AuthMethod = .authenticator
    @Published var serverPassword: String = ""
    @Published var isConnecting: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = ""
    @Published var authToken: String = ""

    // Server Connection — services state
    @Published var availableServices: [OctopusService] = []
    @Published var selectedService: OctopusService? = nil
    @Published var isLoadingServices: Bool = false
    @Published var isDownloadingConfig: Bool = false

    let commandRunner = CommandRunner()
    let apiClient = OctopusAPIClient()

    var canConnect: Bool {
        !octopusServerURL.isEmpty && !octopusAdminEmail.isEmpty && !isConnecting &&
        (selectedAuthMethod == .authenticator || !serverPassword.isEmpty)
    }

    init() {
        self.octopusServerURL = UserDefaults.standard.string(forKey: "octopusServerURL") ?? ""
        self.octopusAdminEmail = UserDefaults.standard.string(forKey: "octopusAdminEmail") ?? ""
        loadProfiles()
    }

    // MARK: - XML Operations
    
    func generateXML() -> String {
        return XMLHandler.generateXML(from: config)
    }
    
    func importXML(from url: URL) {
        do {
            let xmlString = try String(contentsOf: url, encoding: .utf8)
            config = try XMLHandler.parseXML(xmlString)
            showSuccessAlert("XML imported successfully!")
        } catch {
            showErrorAlert("Failed to import XML: \(error.localizedDescription)")
        }
    }
    
    func exportXML(to url: URL) {
        do {
            let xml = generateXML()
            try xml.write(to: url, atomically: true, encoding: .utf8)
            showSuccessAlert("XML exported successfully!")
        } catch {
            showErrorAlert("Failed to export XML: \(error.localizedDescription)")
        }
    }
    
    // MARK: - JSON Operations
    
    func importJSON(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            config = try JSONDecoder().decode(OctopusConfig.self, from: data)
            showSuccessAlert("JSON imported successfully!")
        } catch {
            showErrorAlert("Failed to import JSON: \(error.localizedDescription)")
        }
    }
    
    func exportJSON(to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(config)
            try data.write(to: url)
            showSuccessAlert("JSON exported successfully!")
        } catch {
            showErrorAlert("Failed to export JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Authentication Methods
    
    func addAllStandardMethods() {
        config.authenticationMethods = OctopusConfig.standardAuthMethods
        showSuccessAlert("Added all 8 standard authentication methods!")
    }
    
    func addAuthenticationMethod() {
        config.authenticationMethods.append(
            AuthenticationMethod(method: "", methodFriendlyName: "", message: "", passwordHint: "")
        )
    }
    
    func removeAuthenticationMethod(at index: IndexSet) {
        config.authenticationMethods.remove(atOffsets: index)
    }
    
    // MARK: - FileVault Commands

    func loadLocalUsers() async {
        let users = await commandRunner.fetchLocalUsers()
        localUsers = users
        if selectedLocalUser.isEmpty, let first = users.first {
            selectedLocalUser = first
        }
    }

    func checkFileVaultStatus() async {
        do {
            let status = try await commandRunner.checkFileVaultStatus()
            showSuccessAlert("FileVault Status:\n\(status)")
        } catch {
            showErrorAlert("Failed to check FileVault status: \(error.localizedDescription)")
        }
    }

    func rotateRecoveryKey() async {
        guard !selectedLocalUser.isEmpty else {
            showErrorAlert("Please select a local user.")
            return
        }
        guard !localUserPassword.isEmpty else {
            showErrorAlert("Please enter the user password.")
            return
        }
        do {
            let result = try await commandRunner.rotateRecoveryKey(
                username: selectedLocalUser,
                password: localUserPassword
            )
            // Parse the recovery key from output
            if let key = parseRecoveryKey(from: result) {
                lastRecoveryKey = key
            }
            localUserPassword = ""
            showSuccessAlert("Recovery key rotated successfully!\n\(result)")
        } catch {
            localUserPassword = ""
            showErrorAlert("Failed to rotate recovery key: \(error.localizedDescription)")
        }
    }

    func listFileVaultUsers() async {
        do {
            let users = try await commandRunner.listFileVaultUsers()
            showSuccessAlert("FileVault Users:\n\(users)")
        } catch {
            showErrorAlert("Failed to list FileVault users: \(error.localizedDescription)")
        }
    }

    /// Parses recovery key from fdesetup output, e.g.:
    /// "New personal recovery key = '77CW-QBNT-BXW6-7ZUR-5XJR-NF8A'"
    private func parseRecoveryKey(from output: String) -> String? {
        // Match pattern: key = 'XXXX-XXXX-...'
        let pattern = #"recovery key\s*=\s*'([^']+)'"#
        if let range = output.range(of: pattern, options: .regularExpression) {
            let match = String(output[range])
            // Extract just the key value between quotes
            if let start = match.firstIndex(of: "'"),
               let end = match.lastIndex(of: "'"), start < end {
                let keyStart = match.index(after: start)
                return String(match[keyStart..<end])
            }
        }
        return nil
    }
    
    // MARK: - Recovery Key Actions

    /// Save the last generated recovery key to a file using NSSavePanel
    func saveRecoveryKeyToFile() {
        guard !lastRecoveryKey.isEmpty else {
            showErrorAlert("No recovery key to save. Generate one first.")
            return
        }
        let panel = NSSavePanel()
        panel.title = "Save Recovery Key"
        panel.nameFieldStringValue = "recovery-key.txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            do {
                let content = """
                FileVault Recovery Key
                ======================
                User: \(selectedLocalUser)
                Date: \(Date().formatted(date: .long, time: .shortened))

                Recovery Key: \(lastRecoveryKey)

                Store this key in a safe place. It is required to unlock the disk if the password is lost.
                """
                try content.write(to: url, atomically: true, encoding: .utf8)
                showSuccessAlert("Recovery key saved to:\n\(url.path)")
            } catch {
                showErrorAlert("Failed to save recovery key: \(error.localizedDescription)")
            }
        }
    }

    /// Open a new email draft with the recovery key using the default mail client
    func emailRecoveryKey() {
        guard !lastRecoveryKey.isEmpty else {
            showErrorAlert("No recovery key to send. Generate one first.")
            return
        }
        let subject = "FileVault Recovery Key for \(selectedLocalUser)"
        let body = """
        FileVault Recovery Key
        ======================
        User: \(selectedLocalUser)
        Date: \(Date().formatted(date: .long, time: .shortened))

        Recovery Key: \(lastRecoveryKey)

        Store this key in a safe place. It is required to unlock the disk if the password is lost.
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Pre-fill email address from config if available
        var mailTo = ""
        if config.recoveryKeySendEmail && !config.recoveryKeyEmailAddress.isEmpty {
            mailTo = config.recoveryKeyEmailAddress
        }

        if let url = URL(string: "mailto:\(mailTo)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        } else {
            showErrorAlert("Could not open mail client.")
        }
    }

    // MARK: - Package Creation

    @MainActor
    func createMacPKG() async {
        // Create temporary directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Save XML to temp directory
            let xmlURL = tempDir.appendingPathComponent("octopus-config.xml")
            try generateXML().write(to: xmlURL, atomically: true, encoding: .utf8)

            // Create PKG
            let savePanel = NSSavePanel()
            savePanel.title = "Save Mac PKG"
            savePanel.allowedContentTypes = [UTType.data]
            savePanel.nameFieldStringValue = "OctopusConfig.pkg"

            let response = savePanel.runModal()

            if response == .OK, let url = savePanel.url {
                let _ = try await commandRunner.createPackage(configPath: tempDir.path, outputPath: url.path)
                showSuccessAlert("Mac PKG created successfully!")
            }

            // Cleanup
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            showErrorAlert("Failed to create PKG: \(error.localizedDescription)")
        }
    }
    
    // MARK: - XML Validation

    func validateXML() {
        let xml = generateXML()
        let issues = XMLHandler.validateXML(xml)
        if issues.isEmpty {
            showSuccessAlert("XML is valid! No issues found.")
        } else {
            let issueList = issues.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            showErrorAlert("XML validation found \(issues.count) issue(s):\n\n\(issueList)")
        }
    }

    func exportXMLWithPanel() {
        let panel = NSSavePanel()
        panel.title = "Export XML Configuration"
        panel.nameFieldStringValue = "octopus-config.xml"
        panel.allowedContentTypes = [.xml]
        panel.canCreateDirectories = true

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            exportXML(to: url)
        }
    }

    // MARK: - Deployment / Repackaging

    @MainActor
    func repackagePKG(sourcePkgPath: String, xmlFilename: String, saveXmlCopy: Bool) async {
        // 1. Validate config first
        let xml = generateXML()
        let issues = XMLHandler.validateXML(xml)
        if !issues.isEmpty {
            showErrorAlert("Configuration has validation issues. Please fix them before building:\n\n" + issues.joined(separator: "\n"))
            return
        }

        // 2. Show NSSavePanel for output location
        let savePanel = NSSavePanel()
        savePanel.title = "Save Repackaged PKG"
        savePanel.nameFieldStringValue = "Octopus-Configured.pkg"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "pkg") ?? .data]
        savePanel.canCreateDirectories = true

        let response = savePanel.runModal()
        guard response == .OK, let outputURL = savePanel.url else { return }

        // 3. Begin async repackaging
        isRepackaging = true
        repackageLog = ""
        repackageProgress = "Starting..."
        repackageSucceeded = false
        lastOutputPkgPath = ""

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("octopus-repackage-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            let expandedDir = tempDir.appendingPathComponent("expanded")
            let payloadDir = tempDir.appendingPathComponent("payload")
            let rebuiltComponentPath = tempDir.appendingPathComponent("rebuilt-component.pkg")

            // Step 1: Expand the product .pkg
            repackageProgress = "Expanding source package..."
            let _ = try await commandRunner.expandPkg(
                sourcePath: sourcePkgPath,
                destPath: expandedDir.path
            )
            appendLog("Expanded package to \(expandedDir.path)")

            // Step 2: Find the component .pkg inside expanded dir
            repackageProgress = "Locating component package..."
            let componentPkgName = try findComponentPkg(in: expandedDir)
            let componentDir = expandedDir.appendingPathComponent(componentPkgName)
            appendLog("Found component: \(componentPkgName)")

            // Step 3: Extract Payload from component
            repackageProgress = "Extracting payload..."
            let _ = try await commandRunner.extractPayload(
                componentDir: componentDir.path,
                destPath: payloadDir.path
            )
            appendLog("Extracted payload to \(payloadDir.path)")

            // Step 4: Find the .app bundle inside the payload
            repackageProgress = "Locating application bundle..."
            let appBundlePath = try findAppBundle(in: payloadDir)
            appendLog("Found app bundle: \(appBundlePath)")

            // Step 5: Inject the XML config into .app/Contents/Resources/
            repackageProgress = "Injecting configuration XML..."
            let resourcesPath = appBundlePath + "/Contents/Resources"
            try FileManager.default.createDirectory(
                atPath: resourcesPath, withIntermediateDirectories: true
            )
            let xmlDestPath = resourcesPath + "/" + xmlFilename
            try xml.write(toFile: xmlDestPath, atomically: true, encoding: .utf8)
            appendLog("Wrote \(xmlFilename) to \(resourcesPath)")

            // Step 6: Optionally save XML copy alongside output
            if saveXmlCopy {
                let xmlCopyPath = outputURL.deletingLastPathComponent()
                    .appendingPathComponent(xmlFilename)
                try xml.write(to: xmlCopyPath, atomically: true, encoding: .utf8)
                appendLog("Saved XML copy to \(xmlCopyPath.path)")
            }

            // Step 7: Read PackageInfo from the component to get identifier and version
            repackageProgress = "Reading package metadata..."
            let (identifier, version, installLocation) = try readPackageInfo(
                componentDir: componentDir
            )
            appendLog("Package ID: \(identifier), Version: \(version), Install-location: \(installLocation)")

            // Step 8: Rebuild component .pkg with pkgbuild
            repackageProgress = "Rebuilding component package..."
            let scriptsDir = componentDir.appendingPathComponent("Scripts").path
            let hasScripts = FileManager.default.fileExists(atPath: scriptsDir)
            let _ = try await commandRunner.rebuildComponentPkg(
                rootPath: payloadDir.path,
                identifier: identifier,
                version: version,
                installLocation: installLocation,
                scriptsPath: hasScripts ? scriptsDir : nil,
                outputPath: rebuiltComponentPath.path
            )
            appendLog("Rebuilt component package")

            // Step 9: Check if Distribution file exists (product archive) or just use component
            let distributionFile = expandedDir.appendingPathComponent("Distribution")
            if FileManager.default.fileExists(atPath: distributionFile.path) {
                // Product archive — rebuild with productbuild
                repackageProgress = "Rebuilding product archive..."
                // Replace the expanded component directory with the rebuilt flat .pkg
                let targetComponentPath = expandedDir.appendingPathComponent(componentPkgName)
                try? FileManager.default.removeItem(at: targetComponentPath)
                try FileManager.default.copyItem(
                    at: rebuiltComponentPath, to: targetComponentPath
                )
                // Remove output if it already exists
                try? FileManager.default.removeItem(at: outputURL)
                let _ = try await commandRunner.flattenPkg(
                    expandedDir: expandedDir.path,
                    outputPath: outputURL.path
                )
            } else {
                // Simple component .pkg — just copy rebuilt component as output
                try? FileManager.default.removeItem(at: outputURL)
                try FileManager.default.copyItem(
                    at: rebuiltComponentPath, to: outputURL
                )
            }
            appendLog("Output package: \(outputURL.path)")

            repackageProgress = "Done!"
            lastOutputPkgPath = outputURL.path
            repackageSucceeded = true
            showSuccessAlert("Deployment package created successfully!\n\n\(outputURL.path)")

        } catch {
            repackageProgress = "Failed"
            repackageSucceeded = false
            appendLog("ERROR: \(error.localizedDescription)")
            showErrorAlert("Failed to repackage: \(error.localizedDescription)")
        }

        // Cleanup temp directory
        try? FileManager.default.removeItem(at: tempDir)
        isRepackaging = false
    }

    private func appendLog(_ message: String) {
        repackageLog += "[\(Date().formatted(date: .omitted, time: .standard))] \(message)\n"
    }

    /// Finds the first .pkg directory inside an expanded product archive
    private func findComponentPkg(in expandedDir: URL) throws -> String {
        let contents = try FileManager.default.contentsOfDirectory(atPath: expandedDir.path)
        guard let pkg = contents.first(where: { $0.hasSuffix(".pkg") }) else {
            throw NSError(domain: "Deployment", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No component .pkg found inside expanded package"])
        }
        return pkg
    }

    /// Finds the .app bundle inside an extracted payload directory (searches recursively)
    private func findAppBundle(in payloadDir: URL) throws -> String {
        let enumerator = FileManager.default.enumerator(atPath: payloadDir.path)
        while let item = enumerator?.nextObject() as? String {
            if item.hasSuffix(".app") {
                return payloadDir.path + "/" + item
            }
        }
        throw NSError(domain: "Deployment", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "No .app bundle found in payload"])
    }

    /// Reads PackageInfo XML from expanded component .pkg to extract identifier, version, install-location
    private func readPackageInfo(componentDir: URL) throws -> (String, String, String) {
        let packageInfoPath = componentDir.appendingPathComponent("PackageInfo")
        let xmlString = try String(contentsOf: packageInfoPath, encoding: .utf8)

        let identifier = extractAttribute(from: xmlString, attribute: "identifier") ?? "com.octopus.pkg"
        let version = extractAttribute(from: xmlString, attribute: "version") ?? "1.0"
        let installLocation = extractAttribute(from: xmlString, attribute: "install-location") ?? "/"

        return (identifier, version, installLocation)
    }

    private func extractAttribute(from xml: String, attribute: String) -> String? {
        let pattern = "\(attribute)=\"([^\"]*)\""
        if let range = xml.range(of: pattern, options: .regularExpression) {
            let match = String(xml[range])
            if let start = match.firstIndex(of: "\""),
               let end = match.lastIndex(of: "\""), start < end {
                let valueStart = match.index(after: start)
                return String(match[valueStart..<end])
            }
        }
        return nil
    }

    // MARK: - Server Connection

    func connectToServer() async {
        isConnecting = true
        connectionStatus = selectedAuthMethod == .authenticator
            ? "Sending push notification... Approve on your device."
            : "Authenticating..."

        do {
            let token: String
            if selectedAuthMethod == .authenticator {
                token = try await apiClient.loginWithAuthenticator(
                    serverURL: octopusServerURL, email: octopusAdminEmail
                )
            } else {
                token = try await apiClient.loginWithPassword(
                    serverURL: octopusServerURL, email: octopusAdminEmail, password: serverPassword
                )
            }

            authToken = token
            serverPassword = "" // Clear password from memory
            isConnected = true
            connectionStatus = "Connected"
            isConnecting = false

            // Automatically fetch services after login
            await fetchServices()

        } catch {
            isConnecting = false
            isConnected = false
            authToken = ""
            connectionStatus = ""
            showErrorAlert("Connection failed: \(error.localizedDescription)")
        }
    }

    func fetchServices() async {
        guard !authToken.isEmpty else {
            showErrorAlert("Not authenticated. Please connect first.")
            return
        }
        isLoadingServices = true
        do {
            availableServices = try await apiClient.listServices(
                serverURL: octopusServerURL, token: authToken
            )
            isLoadingServices = false
            if availableServices.isEmpty {
                showErrorAlert("No services found on this server.")
            }
        } catch {
            isLoadingServices = false
            handleAPIError(error)
        }
    }

    func downloadAndLoadConfig() async {
        guard let service = selectedService else {
            showErrorAlert("Please select a service first.")
            return
        }
        guard !authToken.isEmpty else {
            showErrorAlert("Not authenticated. Please connect first.")
            return
        }
        isDownloadingConfig = true
        do {
            let signOn = try await apiClient.fetchServiceSignOn(
                serverURL: octopusServerURL, token: authToken, serviceId: service.id
            )
            // Map signOn JSON fields → Required config fields
            config.server = signOn.restEndpoint
            config.certificate = signOn.certificate.publicKey
            config.service = signOn.serviceKey.key
            // Note: config.domain is NOT set — user must enter it manually in the Required tab

            isDownloadingConfig = false
            showSuccessAlert("Configuration loaded from service '\(service.name)'!\n\nPlease enter your Domain in the Required tab.")
        } catch {
            isDownloadingConfig = false
            handleAPIError(error)
        }
    }

    func disconnect() {
        authToken = ""
        isConnected = false
        isConnecting = false
        connectionStatus = ""
        availableServices = []
        selectedService = nil
        serverPassword = ""
    }

    private func handleAPIError(_ error: Error) {
        if let apiError = error as? OctopusAPIError {
            switch apiError {
            case .invalidCredentials, .noToken:
                disconnect()
                showErrorAlert("Session expired. Please reconnect.\n\(apiError.localizedDescription)")
            default:
                showErrorAlert(apiError.localizedDescription)
            }
        } else {
            showErrorAlert("Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Profiles

    func loadProfiles() {
        profiles = profileManager.loadAllProfiles()
    }

    func saveNewProfile(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showErrorAlert("Profile name cannot be empty.")
            return
        }
        let profile = Profile(name: trimmed, config: config)
        do {
            try profileManager.save(profile)
            loadProfiles()
            showSuccessAlert("Profile '\(trimmed)' saved successfully!")
        } catch {
            showErrorAlert("Failed to save profile: \(error.localizedDescription)")
        }
    }

    func loadProfile(_ profile: Profile) {
        config = profile.config
        showSuccessAlert("Profile '\(profile.name)' loaded successfully!")
    }

    func updateProfile(_ profile: Profile) {
        var updated = profile
        updated.config = config
        updated.updatedAt = Date()
        do {
            try profileManager.save(updated)
            loadProfiles()
            showSuccessAlert("Profile '\(profile.name)' updated with current settings!")
        } catch {
            showErrorAlert("Failed to update profile: \(error.localizedDescription)")
        }
    }

    func renameProfile(_ profile: Profile, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showErrorAlert("Profile name cannot be empty.")
            return
        }
        var updated = profile
        updated.name = trimmed
        updated.updatedAt = Date()
        do {
            try profileManager.save(updated)
            loadProfiles()
            showSuccessAlert("Profile renamed to '\(trimmed)'!")
        } catch {
            showErrorAlert("Failed to rename profile: \(error.localizedDescription)")
        }
    }

    func deleteProfile(_ profile: Profile) {
        do {
            try profileManager.delete(profile)
            loadProfiles()
            showSuccessAlert("Profile '\(profile.name)' deleted.")
        } catch {
            showErrorAlert("Failed to delete profile: \(error.localizedDescription)")
        }
    }

    func exportProfile(_ profile: Profile) {
        let panel = NSSavePanel()
        panel.title = "Export Profile"
        panel.nameFieldStringValue = "\(profile.name).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            do {
                try profileManager.exportProfile(profile, to: url)
                showSuccessAlert("Profile '\(profile.name)' exported successfully!")
            } catch {
                showErrorAlert("Failed to export profile: \(error.localizedDescription)")
            }
        }
    }

    func exportCurrentConfigAsProfile() {
        let panel = NSSavePanel()
        panel.title = "Export Current Configuration as Profile"
        panel.nameFieldStringValue = "OctopusProfile.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            let profile = Profile(name: url.deletingPathExtension().lastPathComponent, config: config)
            do {
                try profileManager.exportProfile(profile, to: url)
                showSuccessAlert("Configuration exported as profile successfully!")
            } catch {
                showErrorAlert("Failed to export: \(error.localizedDescription)")
            }
        }
    }

    func importProfileFromFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Profile"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        let response = panel.runModal()
        if response == .OK, let url = panel.url {
            do {
                let profile = try profileManager.importProfile(from: url)
                loadProfiles()
                showSuccessAlert("Profile '\(profile.name)' imported successfully!")
            } catch {
                showErrorAlert("Failed to import profile: \(error.localizedDescription)")
            }
        }
    }

    func confirmProfileNameAction() {
        guard let action = pendingProfileAction else { return }
        switch action {
        case .saveNew:
            saveNewProfile(name: profileNameInput)
        case .rename(let profile):
            renameProfile(profile, newName: profileNameInput)
        }
        pendingProfileAction = nil
        profileNameInput = ""
    }

    func confirmDeleteProfile() {
        if let profile = profileToDelete {
            deleteProfile(profile)
        }
        profileToDelete = nil
    }

    // MARK: - Alerts

    func showSuccessAlert(_ message: String) {
        alertTitle = "Success"
        alertMessage = message
        showAlert = true
    }
    
    func showErrorAlert(_ message: String) {
        alertTitle = "Error"
        alertMessage = message
        showAlert = true
    }
}
