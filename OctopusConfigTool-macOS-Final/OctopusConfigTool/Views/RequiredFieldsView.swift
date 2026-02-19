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
                    LabeledInputField(
                        label: "Server URL",
                        text: $config.server,
                        placeholder: "https://yourserver.doubleoctopus.io"
                    )
                }

                Section("Domain") {
                    LabeledInputField(
                        label: "Domain Name",
                        text: $config.domain,
                        placeholder: "e.g. company.com",
                        hint: "Your Active Directory or LDAP domain name."
                    )
                }

                Section("Service Key") {
                    LabeledTextEditor(
                        label: "Service Key",
                        text: $config.service,
                        height: 100,
                        hint: "Paste the service key provided by your Octopus server."
                    )
                }

                Section("Certificate") {
                    LabeledTextEditor(
                        label: "X.509 Certificate",
                        text: $config.certificate,
                        height: 200,
                        monospaced: true,
                        hint: "Paste the PEM-encoded public certificate from your Octopus server."
                    )
                }
            }
            .formStyle(.grouped)
        }
    }
}
