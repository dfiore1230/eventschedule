import SwiftUI
import PhotosUI

struct TalentFormView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    let talent: Talent?
    let onSave: () -> Void
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var website: String
    @State private var description: String
    @State private var address1: String
    @State private var city: String
    @State private var state: String
    @State private var postalCode: String
    @State private var timezone: String
    
    // Profile & Header Images
    @State private var profileImageUrl: String
    @State private var headerImageUrl: String
    @State private var profileImageSelection: PhotosPickerItem?
    @State private var headerImageSelection: PhotosPickerItem?
    @State private var isUploadingProfileImage = false
    @State private var isUploadingHeaderImage = false
    @State private var showProfileMediaLibraryPicker = false
    @State private var showHeaderMediaLibraryPicker = false
    
    // Privacy Settings
    @State private var showEmail: Bool
    
    // Schedule Style
    @State private var scheduleBackgroundType: String
    @State private var scheduleBackgroundImageUrl: String
    @State private var scheduleAccentColor: String
    
    // Schedule Settings
    @State private var scheduleLanguage: String
    @State private var scheduleTimezone: String
    @State private var schedule24Hour: Bool
    
    // Subschedules
    @State private var subschedules: [String]
    @State private var newSubschedule: String = ""
    
    // Auto Import Settings
    @State private var autoImportUrls: [String]
    @State private var newImportUrl: String = ""
    @State private var autoImportCities: [String]
    @State private var newImportCity: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(talent: Talent? = nil, onSave: @escaping () -> Void) {
        self.talent = talent
        self.onSave = onSave
        
        _name = State(initialValue: talent?.name ?? "")
        _email = State(initialValue: talent?.email ?? "")
        _phone = State(initialValue: talent?.phone ?? "")
        _website = State(initialValue: talent?.website ?? "")
        _description = State(initialValue: talent?.description ?? "")
        _address1 = State(initialValue: talent?.address1 ?? "")
        _city = State(initialValue: talent?.city ?? "")
        _state = State(initialValue: talent?.state ?? "")
        _postalCode = State(initialValue: talent?.postalCode ?? "")
        _timezone = State(initialValue: talent?.timezone ?? "")
        _profileImageUrl = State(initialValue: talent?.profileImageUrl ?? "")
        _headerImageUrl = State(initialValue: talent?.headerImageUrl ?? "")
        _showEmail = State(initialValue: talent?.showEmail ?? true)
        _scheduleBackgroundType = State(initialValue: talent?.scheduleBackgroundType ?? "gradient")
        _scheduleBackgroundImageUrl = State(initialValue: talent?.scheduleBackgroundImageUrl ?? "")
        _scheduleAccentColor = State(initialValue: talent?.scheduleAccentColor ?? "#4E81FA")
        _scheduleLanguage = State(initialValue: talent?.scheduleLanguage ?? "en")
        _scheduleTimezone = State(initialValue: talent?.scheduleTimezone ?? TimeZone.current.identifier)
        _schedule24Hour = State(initialValue: talent?.schedule24Hour ?? false)
        _subschedules = State(initialValue: talent?.subschedules ?? [])
        _autoImportUrls = State(initialValue: talent?.autoImportUrls ?? [])
        _autoImportCities = State(initialValue: talent?.autoImportCities ?? [])
    }
    
    var isEditMode: Bool {
        talent != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Website", text: $website)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                
                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section("Address") {
                    TextField("Street Address", text: $address1)
                    TextField("City", text: $city)
                    TextField("State/Province", text: $state)
                    TextField("Postal Code", text: $postalCode)
                    TextField("Timezone", text: $timezone)
                }
                
                Section("Profile & Header Images") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Profile Image")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $profileImageSelection, matching: .images) {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text(isUploadingProfileImage ? "Uploading..." : "Upload New")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isUploadingProfileImage)
                            
                            Button {
                                showProfileMediaLibraryPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("From Library")
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            if !profileImageUrl.isEmpty {
                                Button(role: .destructive) {
                                    profileImageUrl = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                        }
                        
                        TextField("Or enter URL", text: $profileImageUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        if !profileImageUrl.isEmpty {
                            AsyncImage(url: URL(string: profileImageUrl)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 100)
                            .cornerRadius(8)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Header Image")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $headerImageSelection, matching: .images) {
                                HStack {
                                    Image(systemName: "photo.badge.plus")
                                    Text(isUploadingHeaderImage ? "Uploading..." : "Upload New")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isUploadingHeaderImage)
                            
                            Button {
                                showHeaderMediaLibraryPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("From Library")
                                }
                            }
                            .buttonStyle(.bordered)
                            
                            if !headerImageUrl.isEmpty {
                                Button(role: .destructive) {
                                    headerImageUrl = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                        }
                        
                        TextField("Or enter URL", text: $headerImageUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        
                        if !headerImageUrl.isEmpty {
                            AsyncImage(url: URL(string: headerImageUrl)) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(height: 100)
                            .cornerRadius(8)
                        }
                    }
                }
                .onChange(of: profileImageSelection) { _, newValue in
                    Task {
                        await uploadProfileImage(newValue)
                    }
                }
                .onChange(of: headerImageSelection) { _, newValue in
                    Task {
                        await uploadHeaderImage(newValue)
                    }
                }
                
                Section("Privacy Settings") {
                    Toggle("Show Email Address", isOn: $showEmail)
                }
                
                Section("Schedule Style") {
                    Picker("Background Type", selection: $scheduleBackgroundType) {
                        Text("Gradient").tag("gradient")
                        Text("Solid").tag("solid")
                        Text("Image").tag("image")
                    }
                    
                    if scheduleBackgroundType == "image" {
                        TextField("Background Image URL", text: $scheduleBackgroundImageUrl)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                    }
                    
                    TextField("Accent Color (Hex)", text: $scheduleAccentColor)
                        .autocapitalization(.none)
                }
                
                Section("Schedule Settings") {
                    TextField("Language Code (e.g., en, es, fr)", text: $scheduleLanguage)
                        .autocapitalization(.none)
                    
                    TextField("Timezone", text: $scheduleTimezone)
                    
                    Toggle("24-Hour Time Format", isOn: $schedule24Hour)
                }
                
                Section {
                    ForEach(subschedules.indices, id: \.self) { index in
                        HStack {
                            Text(subschedules[index])
                            Spacer()
                            Button(role: .destructive) {
                                subschedules.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add subschedule", text: $newSubschedule)
                        Button {
                            guard !newSubschedule.isEmpty else { return }
                            subschedules.append(newSubschedule)
                            newSubschedule = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newSubschedule.isEmpty)
                    }
                } header: {
                    Text("Subschedules")
                }
                
                Section {
                    ForEach(autoImportUrls.indices, id: \.self) { index in
                        HStack {
                            Text(autoImportUrls[index])
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                autoImportUrls.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add import URL", text: $newImportUrl)
                            .autocapitalization(.none)
                            .keyboardType(.URL)
                        Button {
                            guard !newImportUrl.isEmpty else { return }
                            autoImportUrls.append(newImportUrl)
                            newImportUrl = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newImportUrl.isEmpty)
                    }
                } header: {
                    Text("Auto Import URLs")
                }
                
                Section {
                    ForEach(autoImportCities.indices, id: \.self) { index in
                        HStack {
                            Text(autoImportCities[index])
                            Spacer()
                            Button(role: .destructive) {
                                autoImportCities.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add city", text: $newImportCity)
                        Button {
                            guard !newImportCity.isEmpty else { return }
                            autoImportCities.append(newImportCity)
                            newImportCity = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newImportCity.isEmpty)
                    }
                } header: {
                    Text("Auto Import Cities")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Talent" : "Add Talent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Save" : "Add") {
                        Task { await saveTalent() }
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
        .sheet(isPresented: $showProfileMediaLibraryPicker) {
            MediaLibraryPicker(instance: instanceStore.activeInstance!, onSelect: selectProfileMediaLibraryImage)
        }
        .sheet(isPresented: $showHeaderMediaLibraryPicker) {
            MediaLibraryPicker(instance: instanceStore.activeInstance!, onSelect: selectHeaderMediaLibraryImage)
        }
        .accentColor(theme.accent)
    }
    
    private func saveTalent() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTalentRepository(httpClient: httpClient)
            
            let talentToSave = Talent(
                id: talent?.id ?? 0,
                name: name,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                website: website.isEmpty ? nil : website,
                description: description.isEmpty ? nil : description,
                address1: address1.isEmpty ? nil : address1,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                postalCode: postalCode.isEmpty ? nil : postalCode,
                timezone: timezone.isEmpty ? nil : timezone,
                profileImageUrl: profileImageUrl.isEmpty ? nil : profileImageUrl,
                headerImageUrl: headerImageUrl.isEmpty ? nil : headerImageUrl,
                backgroundImageUrl: scheduleBackgroundImageUrl.isEmpty ? nil : scheduleBackgroundImageUrl,
                showEmail: showEmail,
                scheduleBackgroundType: scheduleBackgroundType.isEmpty ? nil : scheduleBackgroundType,
                scheduleBackgroundImageUrl: scheduleBackgroundImageUrl.isEmpty ? nil : scheduleBackgroundImageUrl,
                scheduleAccentColor: scheduleAccentColor.isEmpty ? nil : scheduleAccentColor,
                scheduleLanguage: scheduleLanguage.isEmpty ? nil : scheduleLanguage,
                scheduleTimezone: scheduleTimezone.isEmpty ? nil : scheduleTimezone,
                schedule24Hour: schedule24Hour,
                subschedules: subschedules.isEmpty ? nil : subschedules,
                autoImportUrls: autoImportUrls.isEmpty ? nil : autoImportUrls,
                autoImportCities: autoImportCities.isEmpty ? nil : autoImportCities
            )
            
            if isEditMode {
                _ = try await repository.update(talentToSave, instance: instance)
            } else {
                _ = try await repository.create(talentToSave, instance: instance)
            }
            
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func uploadProfileImage(_ item: PhotosPickerItem?) async {
        guard let item = item else {
            DebugLogger.log("TalentFormView: uploadProfileImage called with nil item")
            return
        }
        guard let instance = instanceStore.activeInstance else {
            DebugLogger.log("TalentFormView: No active instance")
            return
        }
        
        DebugLogger.log("TalentFormView: Starting profile image upload")
        isUploadingProfileImage = true
        defer { isUploadingProfileImage = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image"
                DebugLogger.log("TalentFormView: Failed to load image data")
                return
            }
            
            DebugLogger.log("TalentFormView: Image data loaded, size: \(data.count) bytes")
            let url = try await uploadImageToServer(data: data, instance: instance)
            DebugLogger.log("TalentFormView: Upload successful, URL: \(url)")
            await MainActor.run {
                profileImageUrl = url
                profileImageSelection = nil
            }
        } catch {
            errorMessage = "Failed to upload image: \(error.localizedDescription)"
            DebugLogger.log("TalentFormView: Upload error: \(error)")
        }
    }
    
    private func uploadHeaderImage(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        guard let instance = instanceStore.activeInstance else { return }
        
        isUploadingHeaderImage = true
        defer { isUploadingHeaderImage = false }
        
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image"
                return
            }
            
            let url = try await uploadImageToServer(data: data, instance: instance)
            await MainActor.run {
                headerImageUrl = url
                headerImageSelection = nil
            }
        } catch {
            errorMessage = "Failed to upload image: \(error.localizedDescription)"
        }
    }
    
    private func uploadImageToServer(data: Data, instance: InstanceProfile) async throws -> String {
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        let uploadURL = instance.baseURL.appendingPathComponent("media")
        DebugLogger.log("TalentFormView: Uploading to: \(uploadURL.absoluteString)")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        // Add authentication - use same method as HTTPClient
        if let token = AuthTokenStore.shared.token(for: instance) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            DebugLogger.log("TalentFormView: Using Bearer token")
        } else if let apiKey = APIKeyStore.shared.load(for: instance) {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            DebugLogger.log("TalentFormView: Using X-API-Key")
        } else {
            DebugLogger.log("TalentFormView: No auth available")
        }
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugLogger.log("TalentFormView: Invalid HTTP response")
            throw URLError(.badServerResponse)
        }
        
        DebugLogger.log("TalentFormView: Upload response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let responseString = String(data: responseData, encoding: .utf8) {
                DebugLogger.log("TalentFormView: Error response: \(responseString)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Parse response to get image URL from nested asset object
        if let responseString = String(data: responseData, encoding: .utf8) {
            DebugLogger.log("TalentFormView: Upload response: \(responseString)")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let asset = json["asset"] as? [String: Any],
           let imageUrl = asset["url"] as? String {
            let absoluteURL = makeAbsoluteURL(imageUrl, baseURL: instance.baseURL)
            DebugLogger.log("TalentFormView: Parsed URL: \(imageUrl) -> Absolute: \(absoluteURL)")
            return absoluteURL
        }
        
        DebugLogger.log("TalentFormView: Failed to parse URL from response")
        throw URLError(.badServerResponse)
    }
    
    private func makeAbsoluteURL(_ urlString: String, baseURL: URL) -> String {
        // If it's already absolute, return as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // Remove /api from base URL if present, then append the relative path
        var baseURLString = baseURL.absoluteString
        if baseURLString.hasSuffix("/api") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        if baseURLString.hasSuffix("/") {
            baseURLString = String(baseURLString.dropLast())
        }
        
        // Ensure relative path starts with /
        let path = urlString.hasPrefix("/") ? urlString : "/" + urlString
        return baseURLString + path
    }
    
    private func selectProfileMediaLibraryImage(_ mediaItem: MediaItem) {
        guard let instance = instanceStore.activeInstance else { return }
        let absoluteURL = makeAbsoluteURL(mediaItem.url, baseURL: instance.baseURL)
        profileImageUrl = absoluteURL
        DebugLogger.log("TalentFormView: Selected profile image from library: \(absoluteURL)")
    }
    
    private func selectHeaderMediaLibraryImage(_ mediaItem: MediaItem) {
        guard let instance = instanceStore.activeInstance else { return }
        let absoluteURL = makeAbsoluteURL(mediaItem.url, baseURL: instance.baseURL)
        headerImageUrl = absoluteURL
        DebugLogger.log("TalentFormView: Selected header image from library: \(absoluteURL)")
    }
}
