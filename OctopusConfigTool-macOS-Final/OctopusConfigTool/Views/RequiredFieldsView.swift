import SwiftUI

struct RequiredFieldsView: View {
    @Binding var config: OctopusConfig
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Required Configuration")
                .font(.title)
                .fontWeight(.bold)
            
            Text("These fields are required for Octopus to function")
                .foregroundColor(.secondary)
            
            Form {
                Section("Server") {
                    TextField("Server URL", text: $config.server)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                }

                Section("Domain") {
                    TextField("Domain Name", text: $config.domain)
                        .textFieldStyle(.plain)
                        .modifier(EmphasizedField())
                }

                Section("Service Key") {
                    TextEditor(text: $config.service)
                        .frame(height: 100)
                        .modifier(EmphasizedField())
                }

                Section("Certificate") {
                    TextEditor(text: $config.certificate)
                        .frame(height: 200)
                        .font(.system(.body, design: .monospaced))
                        .modifier(EmphasizedField())
                }
            }
            .formStyle(.grouped)
        }
    }
}
