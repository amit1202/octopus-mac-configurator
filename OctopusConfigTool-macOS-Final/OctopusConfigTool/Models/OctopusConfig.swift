import Foundation

struct AuthenticationMethod: Codable, Identifiable, Sendable {
    var id = UUID()
    var method: String
    var methodFriendlyName: String
    var message: String
    var passwordHint: String

    enum CodingKeys: String, CodingKey {
        case method, methodFriendlyName, message, passwordHint
    }
}

struct OctopusConfig: Codable, Sendable {
    // Required fields
    var server: String = ""
    var domain: String = ""
    var service: String = ""
    var certificate: String = ""
    
    // Features
    var sudo: Bool = false
    var silentsudo: Bool = true
    var kerberosrealm: String = ""
    var automatickerberossync: Bool = true
    
    // Authentication settings
    var validPasswordIsSufficient: Bool = false
    var validPasswordIsSufficientForOffline: Bool = false
    var passwordlessModeTriggerMethod: String = ""
    var noPasswordLogonMessage: String = ""
    var mfa: Bool = false
    var forceLockAfterOfflineLogin: Bool = false
    var passwordfree: Bool = false
    var thirdparty: Bool = false
    var customUnlockScreen: Bool = false
    var authenticationMethods: [AuthenticationMethod] = []
    
    // SSO
    var ssourl: String = ""
    var ssobrowser: String = "system"
    var hideUserNameInSSOMode: Bool = false
    var ssoButtonCaption: String = ""
    var idpMetadataURL: String = ""

    // Password Sync
    var autoPasswordSync: Bool = true

    // Force Password Rotation
    var forcePasswordRotation: Bool = false
    var passwordRotationPeriod: String = ""

    // FileVault settings
    var filevaultlogin: String = ""
    var fileVaultUser: String = ""
    var fileVault: String = ""
    var directLogin: Bool = false
    var enableFileVault: Bool = false
    var autoEnableFileVault: Bool = false
    var fileVaultRecoveryKey: String = ""
    var fileVaultDeploymentType: String = ""
    var autoRotateRecoveryKey: Bool = false
    var recoveryKeyRotationCommand: String = "sudo fdesetup changerecovery -personal"
    var recoveryKeySaveAsFile: Bool = false
    var recoveryKeyFilePath: String = ""
    var recoveryKeySendEmail: Bool = false
    var recoveryKeyEmailAddress: String = ""

    // Shared accounts
    var sharedaccounts: Bool = false
    var showSharedAccountLink: Bool = false
    var defaultToRegularAccount: Bool = true
    var nameForUseSharedAccountLink: String = ""
    var nameForRemoveSharedAccountLink: String = ""
    
    // Other
    var logging: String = "info"
    var maxAuditFileSize: String = ""
    var maxLogFileSize: String = ""
    var sendAuditToServer: Bool = false
    
    static let standardAuthMethods = [
        AuthenticationMethod(method: "octopus", methodFriendlyName: "Octopus Push", message: "", passwordHint: ""),
        AuthenticationMethod(method: "fido2", methodFriendlyName: "FIDO2 Security Key", message: "", passwordHint: ""),
        AuthenticationMethod(method: "fido2bio", methodFriendlyName: "FIDO2 Biometric", message: "", passwordHint: ""),
        AuthenticationMethod(method: "octopusotp", methodFriendlyName: "Octopus OTP", message: "", passwordHint: ""),
        AuthenticationMethod(method: "sms", methodFriendlyName: "SMS", message: "", passwordHint: ""),
        AuthenticationMethod(method: "voiceCall", methodFriendlyName: "Voice Call", message: "", passwordHint: ""),
        AuthenticationMethod(method: "email", methodFriendlyName: "Email", message: "", passwordHint: ""),
        AuthenticationMethod(method: "whatsApp", methodFriendlyName: "WhatsApp", message: "", passwordHint: "")
    ]
}
