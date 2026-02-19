import Foundation

@MainActor
class CommandRunner: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var lastCommand: String = ""

    func runCommand(_ command: String, withSudo: Bool = false, stdinInput: String? = nil) async throws -> String {
        self.isRunning = true
        self.lastCommand = command
        self.output = "Executing: \(command)\n"

        let fullCommand = withSudo ? "sudo \(command)" : command

        let result = try await Task.detached {
            let process = Process()
            let pipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", fullCommand]
            process.standardOutput = pipe
            process.standardError = errorPipe

            // If we have stdin input, pipe it in
            if let input = stdinInput {
                let inputPipe = Pipe()
                process.standardInput = inputPipe
                try process.run()
                if let inputData = input.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(inputData)
                    inputPipe.fileHandleForWriting.closeFile()
                }
            } else {
                try process.run()
            }

            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

            let output = String(data: data, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""

            return (output: output, error: error, status: process.terminationStatus)
        }.value

        self.isRunning = false
        if !result.output.isEmpty {
            self.output += "\n" + result.output
        }
        if !result.error.isEmpty {
            self.output += "\nError: " + result.error
        }

        if result.status != 0 {
            throw NSError(domain: "CommandRunner", code: Int(result.status),
                         userInfo: [NSLocalizedDescriptionKey: result.error.isEmpty ? "Command failed" : result.error])
        }

        return result.output
    }

    // MARK: - Local Users

    /// Fetch local macOS user accounts (non-system users with UID >= 500)
    func fetchLocalUsers() async -> [String] {
        do {
            let result = try await Task.detached {
                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/dscl")
                process.arguments = [".", "-list", "/Users"]
                process.standardOutput = pipe
                process.standardError = Pipe()

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return String(data: data, encoding: .utf8) ?? ""
            }.value

            // Filter out system users (those starting with _ or special accounts)
            let allUsers = result.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("_") && $0 != "daemon" && $0 != "nobody" && $0 != "root" && $0 != "Guest" }

            return allUsers
        } catch {
            return []
        }
    }

    // MARK: - FileVault Commands

    func checkFileVaultStatus() async throws -> String {
        return try await runCommand("fdesetup status")
    }

    /// Rotate recovery key using -inputplist to pass credentials non-interactively.
    /// fdesetup changerecovery -personal -inputplist reads a plist from stdin:
    ///   <plist><dict>
    ///     <key>Username</key><string>user</string>
    ///     <key>Password</key><string>pass</string>
    ///   </dict></plist>
    func rotateRecoveryKey(username: String, password: String) async throws -> String {
        let plistInput = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Username</key>
            <string>\(username)</string>
            <key>Password</key>
            <string>\(password)</string>
        </dict>
        </plist>
        """
        return try await runCommand("fdesetup changerecovery -personal -inputplist", withSudo: true, stdinInput: plistInput)
    }

    func listFileVaultUsers() async throws -> String {
        return try await runCommand("fdesetup list", withSudo: true)
    }

    // Package creation
    func createPackage(configPath: String, outputPath: String) async throws -> String {
        let command = "pkgbuild --root \(configPath) --identifier com.octopus.config --version 1.0 \(outputPath)"
        return try await runCommand(command)
    }

    // Test configuration
    func validateConfiguration(xmlPath: String) async throws -> String {
        let command = "xmllint --noout \(shellQuote(xmlPath))"
        return try await runCommand(command)
    }

    // MARK: - PKG Repackaging

    /// Shell-quote a string to prevent injection
    func shellQuote(_ string: String) -> String {
        return "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Expand a product .pkg archive to a directory
    func expandPkg(sourcePath: String, destPath: String) async throws -> String {
        let command = "pkgutil --expand \(shellQuote(sourcePath)) \(shellQuote(destPath))"
        return try await runCommand(command)
    }

    /// Extract the Payload (cpio/gzip archive) from a component .pkg directory
    func extractPayload(componentDir: String, destPath: String) async throws -> String {
        let mkdirCmd = "mkdir -p \(shellQuote(destPath))"
        let _ = try await runCommand(mkdirCmd)

        let payloadPath = componentDir + "/Payload"
        let command = """
        cd \(shellQuote(destPath)) && \
        if file \(shellQuote(payloadPath)) | grep -q gzip; then \
            cat \(shellQuote(payloadPath)) | gunzip -dc | cpio -id 2>&1; \
        else \
            cat \(shellQuote(payloadPath)) | cpio -id 2>&1; \
        fi
        """
        return try await runCommand(command)
    }

    /// Rebuild a component .pkg from a payload root using pkgbuild
    func rebuildComponentPkg(
        rootPath: String,
        identifier: String,
        version: String,
        installLocation: String,
        scriptsPath: String?,
        outputPath: String
    ) async throws -> String {
        var command = "pkgbuild"
        command += " --root \(shellQuote(rootPath))"
        command += " --identifier \(shellQuote(identifier))"
        command += " --version \(shellQuote(version))"
        command += " --install-location \(shellQuote(installLocation))"
        if let scripts = scriptsPath {
            command += " --scripts \(shellQuote(scripts))"
        }
        command += " \(shellQuote(outputPath))"
        return try await runCommand(command)
    }

    /// Rebuild a product archive from an expanded directory using productbuild
    func flattenPkg(expandedDir: String, outputPath: String) async throws -> String {
        let command = "productbuild --distribution \(shellQuote(expandedDir + "/Distribution")) --package-path \(shellQuote(expandedDir)) \(shellQuote(outputPath))"
        return try await runCommand(command)
    }
}
