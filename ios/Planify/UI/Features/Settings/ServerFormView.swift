import SwiftUI

struct ServerFormView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    let server: InstanceProfile?
    let onSave: () -> Void
    
    @State private var displayName: String
    @State private var baseURL: String
    @State private var environment: InstanceEnvironment
    @State private var authMethod: InstanceProfile.AuthMethod
    @State private var errorMessage: String?
    
    init(server: InstanceProfile? = nil, onSave: @escaping () -> Void) {
        self.server = server
        self.onSave = onSave
        
        _displayName = State(initialValue: server?.displayName ?? "")
        _baseURL = State(initialValue: server?.baseURL.absoluteString ?? "")
        _environment = State(initialValue: server?.environment ?? .prod)
        _authMethod = State(initialValue: server?.authMethod ?? .sanctum)
    }
    
    var isEditMode: Bool {
        server != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Server Information") {
                    TextField("Display Name", text: $displayName)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Base URL", text: $baseURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    
                    Picker("Environment", selection: $environment) {
                        ForEach(InstanceEnvironment.allCases, id: \.self) { env in
                            Text(env.rawValue.capitalized).tag(env)
                        }
                    }
                    
                    Picker("Auth Method", selection: $authMethod) {
                        Text("Sanctum").tag(InstanceProfile.AuthMethod.sanctum)
                        Text("OAuth2").tag(InstanceProfile.AuthMethod.oauth2)
                        Text("JWT").tag(InstanceProfile.AuthMethod.jwt)
                    }
                }
                
                Section {
                    Text("Enter the base URL of your server (e.g., https://api.example.com)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Server" : "Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Save" : "Add") {
                        saveServer()
                    }
                    .disabled(displayName.isEmpty || baseURL.isEmpty)
                }
            }
        }
        .accentColor(theme.accent)
    }
    
    private func saveServer() {
        errorMessage = nil
        
        // Validate URL
        guard let url = URL(string: baseURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = "Invalid URL format"
            return
        }
        
        // Create the instance profile
        let instanceProfile = InstanceProfile(
            id: server?.id ?? UUID(),
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            baseURL: url,
            environment: environment,
            authMethod: authMethod,
            authEndpoints: server?.authEndpoints,
            featureFlags: server?.featureFlags ?? [:],
            minAppVersion: server?.minAppVersion,
            rateLimits: server?.rateLimits,
            tokenIdentifier: server?.tokenIdentifier,
            theme: server?.theme
        )
        
        if isEditMode {
            // For edit mode, we need to update the instance in the store
            // Remove the old one and add the updated one
            if let oldId = server?.id {
                instanceStore.removeInstance(oldId)
            }
            instanceStore.addInstance(instanceProfile)
        } else {
            instanceStore.addInstance(instanceProfile)
        }
        
        onSave()
        dismiss()
    }
}
