import Foundation

// Simple XML Parser using XMLParser (SAX-style parsing)
class SimpleXMLParser: NSObject, XMLParserDelegate {
    var currentElement = ""
    var currentValue = ""
    var config = OctopusConfig()
    var currentStruct: [String: String] = [:]
    var authMethods: [AuthenticationMethod] = []
    var insideAuthMethods = false
    var insideStruct = false
    
    func parse(_ xmlString: String) throws -> OctopusConfig {
        guard let data = xmlString.data(using: .utf8) else {
            throw NSError(domain: "SimpleXMLParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert XML to data"])
        }
        
        let parser = XMLParser(data: data)
        parser.delegate = self
        
        if parser.parse() {
            config.authenticationMethods = authMethods
            return config
        } else {
            throw parser.parserError ?? NSError(domain: "SimpleXMLParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML"])
        }
    }
    
    // XMLParserDelegate methods
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentValue = ""
        
        if elementName == "authenticationMethods" {
            insideAuthMethods = true
        } else if elementName == "struct" && insideAuthMethods {
            insideStruct = true
            currentStruct = [:]
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if insideStruct {
            currentStruct[elementName] = currentValue
        } else if insideAuthMethods && elementName == "struct" {
            let method = AuthenticationMethod(
                method: currentStruct["method"] ?? "",
                methodFriendlyName: currentStruct["methodFriendlyName"] ?? "",
                message: currentStruct["message"] ?? "",
                passwordHint: currentStruct["passwordHint"] ?? ""
            )
            authMethods.append(method)
            currentStruct = [:]
            insideStruct = false
        } else if elementName == "authenticationMethods" {
            insideAuthMethods = false
        } else {
            setValue(for: elementName, value: currentValue)
        }
        
        currentValue = ""
    }
    
    private func setValue(for element: String, value: String) {
        switch element {
        // Required
        case "server": config.server = value
        case "domain": config.domain = value
        case "service": config.service = value
        case "certificate": config.certificate = value
        
        // Features
        case "sudo": config.sudo = parseBool(value)
        case "silentsudo": config.silentsudo = parseBool(value)
        case "kerberosrealm": config.kerberosrealm = value
        case "automatickerberossync": config.automatickerberossync = parseBool(value)
        
        // Authentication
        case "validPasswordIsSufficient": config.validPasswordIsSufficient = parseBool(value)
        case "validPasswordIsSufficientForOffline": config.validPasswordIsSufficientForOffline = parseBool(value)
        case "mfa": config.mfa = parseBool(value)
        case "forceLockAfterOfflineLogin": config.forceLockAfterOfflineLogin = parseBool(value)
        case "passwordfree": config.passwordfree = parseBool(value)
        case "thirdparty": config.thirdparty = parseBool(value)
        case "customUnlockScreen": config.customUnlockScreen = parseBool(value)
        case "passwordlessModeTriggerMethod": config.passwordlessModeTriggerMethod = value
        case "noPasswordLogonMessage": config.noPasswordLogonMessage = value
        
        // SSO
        case "ssourl": config.ssourl = value
        case "ssobrowser": config.ssobrowser = value
        case "hideUserNameInSSOMode": config.hideUserNameInSSOMode = parseBool(value)
        case "ssoButtonCaption": config.ssoButtonCaption = value
        case "idpMetadataURL": config.idpMetadataURL = value

        // Password Sync
        case "autoPasswordSync": config.autoPasswordSync = parseBool(value)

        // Force Password Rotation
        case "forcePasswordRotation": config.forcePasswordRotation = parseBool(value)
        case "passwordRotationPeriod": config.passwordRotationPeriod = value

        // FileVault
        case "filevaultlogin": config.filevaultlogin = value
        case "fileVaultUser": config.fileVaultUser = value
        case "fileVault": config.fileVault = value
        case "directLogin": config.directLogin = parseBool(value)
        case "enableFileVault": config.enableFileVault = parseBool(value)
        case "autoEnableFileVault": config.autoEnableFileVault = parseBool(value)
        case "fileVaultRecoveryKey": config.fileVaultRecoveryKey = value
        case "fileVaultDeploymentType": config.fileVaultDeploymentType = value
        case "autoRotateRecoveryKey": config.autoRotateRecoveryKey = parseBool(value)
        case "recoveryKeyRotationCommand": config.recoveryKeyRotationCommand = value
        case "recoveryKeySaveAsFile": config.recoveryKeySaveAsFile = parseBool(value)
        case "recoveryKeyFilePath": config.recoveryKeyFilePath = value
        case "recoveryKeySendEmail": config.recoveryKeySendEmail = parseBool(value)
        case "recoveryKeyEmailAddress": config.recoveryKeyEmailAddress = value
        
        // Shared Accounts
        case "sharedaccounts": config.sharedaccounts = parseBool(value)
        case "showSharedAccountLink": config.showSharedAccountLink = parseBool(value)
        case "defaultToRegularAccount": config.defaultToRegularAccount = parseBool(value)
        case "nameForUseSharedAccountLink": config.nameForUseSharedAccountLink = value
        case "nameForRemoveSharedAccountLink": config.nameForRemoveSharedAccountLink = value
        
        // Other
        case "logging": config.logging = value
        case "maxAuditFileSize": config.maxAuditFileSize = value
        case "maxLogFileSize": config.maxLogFileSize = value
        case "sendAuditToServer": config.sendAuditToServer = parseBool(value)

        default: break
        }
    }
    
    private func parseBool(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased == "true" || lowercased == "1" || lowercased == "yes"
    }
}
