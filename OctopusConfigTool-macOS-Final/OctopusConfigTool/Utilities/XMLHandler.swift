import Foundation

class XMLHandler {
    static func generateXML(from config: OctopusConfig) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<octopus>\n"

        // ── Required Fields ──
        xml += "\n    <!-- Required Fields -->\n"
        xml += "    <server>\(escapeXML(config.server))</server>\n"
        xml += "    <domain>\(escapeXML(config.domain))</domain>\n"
        xml += "    <service>\(escapeXML(config.service))</service>\n"
        xml += "    <certificate>\(escapeXML(config.certificate))</certificate>\n"

        // ── Features ──
        xml += "\n    <!-- Features -->\n"
        xml += "    <sudo>\(config.sudo)</sudo>\n"
        xml += "    <silentsudo>\(config.silentsudo)</silentsudo>\n"
        if !config.kerberosrealm.isEmpty { xml += "    <kerberosrealm>\(escapeXML(config.kerberosrealm))</kerberosrealm>\n" }
        xml += "    <automatickerberossync>\(config.automatickerberossync)</automatickerberossync>\n"

        // ── Authentication ──
        xml += "\n    <!-- Authentication -->\n"
        xml += "    <validPasswordIsSufficient>\(config.validPasswordIsSufficient)</validPasswordIsSufficient>\n"
        xml += "    <validPasswordIsSufficientForOffline>\(config.validPasswordIsSufficientForOffline)</validPasswordIsSufficientForOffline>\n"
        xml += "    <mfa>\(config.mfa)</mfa>\n"
        if config.forceLockAfterOfflineLogin { xml += "    <forceLockAfterOfflineLogin>\(config.forceLockAfterOfflineLogin)</forceLockAfterOfflineLogin>\n" }
        xml += "    <passwordfree>\(config.passwordfree)</passwordfree>\n"
        xml += "    <thirdparty>\(config.thirdparty)</thirdparty>\n"
        if config.directLogin { xml += "    <directLogin>\(config.directLogin)</directLogin>\n" }
        if config.customUnlockScreen { xml += "    <customUnlockScreen>\(config.customUnlockScreen)</customUnlockScreen>\n" }

        if !config.passwordlessModeTriggerMethod.isEmpty {
            xml += "    <passwordlessModeTriggerMethod>\(escapeXML(config.passwordlessModeTriggerMethod))</passwordlessModeTriggerMethod>\n"
        }
        if !config.noPasswordLogonMessage.isEmpty {
            xml += "    <noPasswordLogonMessage>\(escapeXML(config.noPasswordLogonMessage))</noPasswordLogonMessage>\n"
        }

        // ── Authentication Methods ──
        if !config.authenticationMethods.isEmpty {
            xml += "\n    <!-- Authentication Methods -->\n"
            xml += "    <authenticationMethods>\n"
            for method in config.authenticationMethods {
                xml += "        <struct>\n"
                xml += "            <method>\(escapeXML(method.method))</method>\n"
                xml += "            <methodFriendlyName>\(escapeXML(method.methodFriendlyName))</methodFriendlyName>\n"
                xml += "            <message>\(escapeXML(method.message))</message>\n"
                xml += "            <passwordHint>\(escapeXML(method.passwordHint))</passwordHint>\n"
                xml += "        </struct>\n"
            }
            xml += "    </authenticationMethods>\n"
        }

        // ── Single Sign-On ──
        xml += "\n    <!-- Single Sign-On -->\n"
        if !config.ssourl.isEmpty { xml += "    <ssourl>\(escapeXML(config.ssourl))</ssourl>\n" }
        if !config.ssobrowser.isEmpty { xml += "    <ssobrowser>\(escapeXML(config.ssobrowser))</ssobrowser>\n" }
        if config.hideUserNameInSSOMode { xml += "    <hideUserNameInSSOMode>\(config.hideUserNameInSSOMode)</hideUserNameInSSOMode>\n" }
        if !config.ssoButtonCaption.isEmpty { xml += "    <ssoButtonCaption>\(escapeXML(config.ssoButtonCaption))</ssoButtonCaption>\n" }
        if !config.idpMetadataURL.isEmpty { xml += "    <idpMetadataURL>\(escapeXML(config.idpMetadataURL))</idpMetadataURL>\n" }

        // ── Password Sync & Rotation ──
        xml += "\n    <!-- Password Sync & Rotation -->\n"
        xml += "    <autoPasswordSync>\(config.autoPasswordSync)</autoPasswordSync>\n"
        xml += "    <forcePasswordRotation>\(config.forcePasswordRotation)</forcePasswordRotation>\n"
        if !config.passwordRotationPeriod.isEmpty { xml += "    <passwordRotationPeriod>\(escapeXML(config.passwordRotationPeriod))</passwordRotationPeriod>\n" }

        // ── FileVault ──
        xml += "\n    <!-- FileVault -->\n"
        xml += "    <enableFileVault>\(config.enableFileVault)</enableFileVault>\n"
        if !config.fileVaultDeploymentType.isEmpty {
            xml += "    <fileVaultDeploymentType>\(escapeXML(config.fileVaultDeploymentType))</fileVaultDeploymentType>\n"
            xml += "    <filevaultlogin>\(escapeXML(config.fileVaultDeploymentType))</filevaultlogin>\n"
        }
        if !config.fileVaultUser.isEmpty { xml += "    <fileVaultUser>\(escapeXML(config.fileVaultUser))</fileVaultUser>\n" }
        if !config.fileVault.isEmpty { xml += "    <fileVault>\(escapeXML(config.fileVault))</fileVault>\n" }
        if config.autoEnableFileVault { xml += "    <autoEnableFileVault>\(config.autoEnableFileVault)</autoEnableFileVault>\n" }

        // ── Recovery Key ──
        xml += "\n    <!-- Recovery Key -->\n"
        if !config.fileVaultRecoveryKey.isEmpty { xml += "    <fileVaultRecoveryKey>\(escapeXML(config.fileVaultRecoveryKey))</fileVaultRecoveryKey>\n" }
        if config.autoRotateRecoveryKey { xml += "    <autoRotateRecoveryKey>\(config.autoRotateRecoveryKey)</autoRotateRecoveryKey>\n" }
        if config.autoRotateRecoveryKey && !config.recoveryKeyRotationCommand.isEmpty {
            xml += "    <recoveryKeyRotationCommand>\(escapeXML(config.recoveryKeyRotationCommand))</recoveryKeyRotationCommand>\n"
        }
        if config.recoveryKeySaveAsFile { xml += "    <recoveryKeySaveAsFile>\(config.recoveryKeySaveAsFile)</recoveryKeySaveAsFile>\n" }
        if !config.recoveryKeyFilePath.isEmpty { xml += "    <recoveryKeyFilePath>\(escapeXML(config.recoveryKeyFilePath))</recoveryKeyFilePath>\n" }
        if config.recoveryKeySendEmail { xml += "    <recoveryKeySendEmail>\(config.recoveryKeySendEmail)</recoveryKeySendEmail>\n" }
        if !config.recoveryKeyEmailAddress.isEmpty { xml += "    <recoveryKeyEmailAddress>\(escapeXML(config.recoveryKeyEmailAddress))</recoveryKeyEmailAddress>\n" }

        // ── Shared Accounts ──
        xml += "\n    <!-- Shared Accounts -->\n"
        if config.sharedaccounts { xml += "    <sharedaccounts>\(config.sharedaccounts)</sharedaccounts>\n" }
        if config.showSharedAccountLink { xml += "    <showSharedAccountLink>\(config.showSharedAccountLink)</showSharedAccountLink>\n" }
        if config.defaultToRegularAccount { xml += "    <defaultToRegularAccount>\(config.defaultToRegularAccount)</defaultToRegularAccount>\n" }
        if !config.nameForUseSharedAccountLink.isEmpty { xml += "    <nameForUseSharedAccountLink>\(escapeXML(config.nameForUseSharedAccountLink))</nameForUseSharedAccountLink>\n" }
        if !config.nameForRemoveSharedAccountLink.isEmpty { xml += "    <nameForRemoveSharedAccountLink>\(escapeXML(config.nameForRemoveSharedAccountLink))</nameForRemoveSharedAccountLink>\n" }

        // ── Logging & Audit ──
        xml += "\n    <!-- Logging & Audit -->\n"
        if !config.logging.isEmpty { xml += "    <logging>\(escapeXML(config.logging))</logging>\n" }
        if !config.maxAuditFileSize.isEmpty { xml += "    <maxAuditFileSize>\(escapeXML(config.maxAuditFileSize))</maxAuditFileSize>\n" }
        if !config.maxLogFileSize.isEmpty { xml += "    <maxLogFileSize>\(escapeXML(config.maxLogFileSize))</maxLogFileSize>\n" }
        if config.sendAuditToServer { xml += "    <sendAuditToServer>\(config.sendAuditToServer)</sendAuditToServer>\n" }

        xml += "\n</octopus>\n"
        return xml
    }

    static func parseXML(_ xmlString: String) throws -> OctopusConfig {
        let parser = SimpleXMLParser()
        return try parser.parse(xmlString)
    }

    /// Validates the XML string and returns a list of issues found (empty list = valid)
    static func validateXML(_ xmlString: String) -> [String] {
        var issues: [String] = []

        // 1. Check basic XML well-formedness using Foundation XMLParser
        guard let data = xmlString.data(using: .utf8) else {
            issues.append("XML string could not be converted to UTF-8 data.")
            return issues
        }

        let validator = XMLValidatorDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = validator

        if !parser.parse() {
            if let error = parser.parserError {
                issues.append("XML parsing error (line \(parser.lineNumber)): \(error.localizedDescription)")
            } else {
                issues.append("XML parsing failed at line \(parser.lineNumber).")
            }
        }
        issues.append(contentsOf: validator.warnings)

        // 2. Check for required root element
        if !xmlString.contains("<octopus>") || !xmlString.contains("</octopus>") {
            issues.append("Missing <octopus> root element.")
        }

        // 3. Check required fields have values
        let config: OctopusConfig
        do {
            config = try parseXML(xmlString)
        } catch {
            issues.append("Failed to parse XML into config: \(error.localizedDescription)")
            return issues
        }

        if config.server.isEmpty {
            issues.append("Required field 'server' is empty.")
        }
        if config.domain.isEmpty {
            issues.append("Required field 'domain' is empty.")
        }
        if config.service.isEmpty {
            issues.append("Required field 'service' is empty.")
        }
        if config.certificate.isEmpty {
            issues.append("Required field 'certificate' is empty.")
        }

        // 4. Validate email format if recovery key email is enabled
        if config.recoveryKeySendEmail && !config.recoveryKeyEmailAddress.isEmpty {
            let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
            if config.recoveryKeyEmailAddress.range(of: emailRegex, options: .regularExpression) == nil {
                issues.append("Recovery key email address '\(config.recoveryKeyEmailAddress)' is not a valid email format.")
            }
        }
        if config.recoveryKeySendEmail && config.recoveryKeyEmailAddress.isEmpty {
            issues.append("Recovery key email sending is enabled but no email address is specified.")
        }

        // 5. Validate recovery key file path if save as file is enabled
        if config.recoveryKeySaveAsFile && config.recoveryKeyFilePath.isEmpty {
            issues.append("Recovery key file saving is enabled but no file path is specified.")
        }

        return issues
    }

    private static func escapeXML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// Helper delegate for XML well-formedness validation
private class XMLValidatorDelegate: NSObject, XMLParserDelegate {
    var warnings: [String] = []
    var elementStack: [String] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        elementStack.append(elementName)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let last = elementStack.last, last == elementName {
            elementStack.removeLast()
        } else {
            warnings.append("Mismatched closing tag '</\(elementName)>' at line \(parser.lineNumber).")
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        warnings.append("Parse error: \(parseError.localizedDescription)")
    }
}
