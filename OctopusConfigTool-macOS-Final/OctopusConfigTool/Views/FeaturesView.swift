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
                    TextField("Kerberos Realm", text: $config.kerberosrealm)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                    Toggle("Automatic Kerberos Sync", isOn: $config.automatickerberossync)
                }
            }
            .formStyle(.grouped)
        }
    }
}
