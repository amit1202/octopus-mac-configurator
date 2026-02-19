import SwiftUI

struct AuthenticationView: View {
    @Binding var config: OctopusConfig
    @ObservedObject var viewModel: ConfigViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Authentication Settings")
                .font(.title)
                .fontWeight(.bold)
            
            Form {
                Section("Basic Authentication") {
                    Toggle("Allow Password Login", isOn: $config.validPasswordIsSufficient)
                    Toggle("Allow Password Login While Offline", isOn: $config.validPasswordIsSufficientForOffline)
                    Toggle("Multi-Factor Authentication (MFA)", isOn: $config.mfa)
                    Toggle("Force Lock After Offline Login", isOn: $config.forceLockAfterOfflineLogin)
                    Toggle("Password-Free Experience", isOn: $config.passwordfree)
                    Toggle("Third-Party Authentication", isOn: $config.thirdparty)
                    Toggle("Direct Login", isOn: $config.directLogin)
                    Text("When enabled, users skip the Octopus Login screen after entering FileVault credentials.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("Custom Unlock Screen", isOn: $config.customUnlockScreen)
                }
                
                Section("Authentication Methods") {
                    Button("Add All Standard Methods") {
                        viewModel.addAllStandardMethods()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    ForEach($config.authenticationMethods) { $method in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Method", text: $method.method)
                                .textFieldStyle(.plain)
                                .modifier(EmphasizedField())
                            TextField("Friendly Name", text: $method.methodFriendlyName)
                                .textFieldStyle(.plain)
                                .modifier(EmphasizedField())
                            TextField("Message", text: $method.message)
                                .textFieldStyle(.plain)
                                .modifier(EmphasizedField())
                            TextField("Password Hint", text: $method.passwordHint)
                                .textFieldStyle(.plain)
                                .modifier(EmphasizedField())
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
