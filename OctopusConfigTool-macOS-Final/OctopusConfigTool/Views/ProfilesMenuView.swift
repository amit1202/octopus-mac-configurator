import SwiftUI
import UniformTypeIdentifiers

struct ProfilesMenuView: View {
    @ObservedObject var viewModel: ConfigViewModel

    var body: some View {
        Menu {
            // Save current configuration as a new profile
            Button(action: {
                viewModel.profileNameInput = ""
                viewModel.pendingProfileAction = .saveNew
                viewModel.showProfileNamePrompt = true
            }) {
                Label("Save Current as New Profile...", systemImage: "plus.circle")
            }

            Divider()

            // Import / Export
            Button(action: { viewModel.importProfileFromFile() }) {
                Label("Import Profile from File...", systemImage: "square.and.arrow.down")
            }

            Button(action: { viewModel.exportCurrentConfigAsProfile() }) {
                Label("Export Current Config to File...", systemImage: "square.and.arrow.up")
            }

            Divider()

            // Saved profiles list
            if viewModel.profiles.isEmpty {
                Text("No saved profiles")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.profiles) { profile in
                    Menu(profile.name) {
                        Button(action: { viewModel.loadProfile(profile) }) {
                            Label("Load", systemImage: "arrow.down.doc")
                        }

                        Button(action: { viewModel.updateProfile(profile) }) {
                            Label("Update with Current Settings", systemImage: "arrow.triangle.2.circlepath")
                        }

                        Button(action: {
                            viewModel.profileNameInput = profile.name
                            viewModel.pendingProfileAction = .rename(profile)
                            viewModel.showProfileNamePrompt = true
                        }) {
                            Label("Rename...", systemImage: "pencil")
                        }

                        Button(action: { viewModel.exportProfile(profile) }) {
                            Label("Export...", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            viewModel.profileToDelete = profile
                            viewModel.showDeleteConfirmation = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } label: {
            Label("Profiles", systemImage: "archivebox")
        }
    }
}
