import SwiftUI

struct FeaturesView: View {
    @Binding var config: OctopusConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Features")
                .font(.title)
                .fontWeight(.bold)
            
            Form {
                Toggle("Enable Sudo", isOn: $config.sudo)
                if config.sudo {
                    Toggle("Silent Sudo", isOn: $config.silentsudo)
                        .padding(.leading)
                }
                
                Section("Kerberos") {
                    LabeledInputField(
                        label: "Kerberos Realm",
                        text: $config.kerberosrealm,
                        placeholder: "e.g. COMPANY.COM",
                        hint: "Leave blank to disable Kerberos."
                    )
                    Toggle("Automatic Kerberos Sync", isOn: $config.automatickerberossync)
                }
            }
            .formStyle(.grouped)
        }
    }
}
