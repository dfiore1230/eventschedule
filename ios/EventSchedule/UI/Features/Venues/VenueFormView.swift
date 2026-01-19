import SwiftUI
import PhotosUI

struct VenueFormView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    let venue: VenueDetail?
    let onSave: () -> Void
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var website: String
    @State private var description: String
    @State private var address1: String
    @State private var address2: String
    @State private var city: String
    @State private var state: String
    @State private var postalCode: String
    @State private var timezone: String
    @State private var geoLat: String
    @State private var geoLon: String
    
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
    
    // Rooms
    @State private var rooms: [VenueDetail.VenueRoom]
    @State private var newRoomName: String = ""
    @State private var newRoomCapacity: String = ""
    @State private var newRoomDescription: String = ""
    
    // Contacts
    @State private var contacts: [VenueDetail.VenueContact]
    @State private var newContactName: String = ""
    @State private var newContactRole: String = ""
    @State private var newContactEmail: String = ""
    @State private var newContactPhone: String = ""
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    init(venue: VenueDetail? = nil, onSave: @escaping () -> Void) {
        self.venue = venue
        self.onSave = onSave
        
        _name = State(initialValue: venue?.name ?? "")
        _email = State(initialValue: venue?.email ?? "")
        _phone = State(initialValue: venue?.phone ?? "")
        _website = State(initialValue: venue?.website ?? "")
        _description = State(initialValue: venue?.description ?? "")
        _address1 = State(initialValue: venue?.address1 ?? "")
        _address2 = State(initialValue: venue?.address2 ?? "")
        _city = State(initialValue: venue?.city ?? "")
        _state = State(initialValue: venue?.state ?? "")
        _postalCode = State(initialValue: venue?.postalCode ?? "")
        _timezone = State(initialValue: venue?.timezone ?? "")
        _geoLat = State(initialValue: venue?.geoLat.map { String($0) } ?? "")
        _geoLon = State(initialValue: venue?.geoLon.map { String($0) } ?? "")
        _profileImageUrl = State(initialValue: venue?.profileImageUrl ?? "")
        _headerImageUrl = State(initialValue: venue?.headerImageUrl ?? "")
        _showEmail = State(initialValue: venue?.showEmail ?? true)
        _scheduleBackgroundType = State(initialValue: venue?.scheduleBackgroundType ?? "gradient")
        _scheduleBackgroundImageUrl = State(initialValue: venue?.scheduleBackgroundImageUrl ?? "")
        _scheduleAccentColor = State(initialValue: venue?.scheduleAccentColor ?? "#007AFF")
        _scheduleLanguage = State(initialValue: venue?.scheduleLanguage ?? "en")
        _scheduleTimezone = State(initialValue: venue?.scheduleTimezone ?? TimeZone.current.identifier)
        _schedule24Hour = State(initialValue: venue?.schedule24Hour ?? false)
        _subschedules = State(initialValue: venue?.subschedules ?? [])
        _autoImportUrls = State(initialValue: venue?.autoImportUrls ?? [])
        _autoImportCities = State(initialValue: venue?.autoImportCities ?? [])
        _rooms = State(initialValue: venue?.rooms ?? [])
        _contacts = State(initialValue: venue?.contacts ?? [])
    }
    
    var isEditMode: Bool {
        venue != nil
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
                    TextField("Address Line 2", text: $address2)
                    TextField("City", text: $city)
                    TextField("State/Province", text: $state)
                    TextField("Postal Code", text: $postalCode)
                    TextField("Timezone", text: $timezone)
                }
                
                Section("Location") {
                    TextField("Latitude", text: $geoLat)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $geoLon)
                        .keyboardType(.decimalPad)
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
                
                Section {
                    ForEach(rooms) { room in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(room.name)
                                    .font(.headline)
                                Spacer()
                                if let capacity = room.capacity {
                                    Text("Capacity: \(capacity)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Button(role: .destructive) {
                                    rooms.removeAll { $0.id == room.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            if let desc = room.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        TextField("Room Name", text: $newRoomName)
                        HStack {
                            TextField("Capacity", text: $newRoomCapacity)
                                .keyboardType(.numberPad)
                            TextField("Description (optional)", text: $newRoomDescription)
                        }
                        Button {
                            guard !newRoomName.isEmpty else { return }
                            let capacity = Int(newRoomCapacity)
                            let room = VenueDetail.VenueRoom(
                                name: newRoomName,
                                capacity: capacity,
                                description: newRoomDescription.isEmpty ? nil : newRoomDescription
                            )
                            rooms.append(room)
                            newRoomName = ""
                            newRoomCapacity = ""
                            newRoomDescription = ""
                        } label: {
                            Label("Add Room", systemImage: "plus.circle.fill")
                        }
                        .disabled(newRoomName.isEmpty)
                    }
                } header: {
                    Text("Rooms")
                }
                
                Section {
                    ForEach(contacts) { contact in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(contact.name)
                                        .font(.headline)
                                    if let role = contact.role, !role.isEmpty {
                                        Text(role)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    contacts.removeAll { $0.id == contact.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            if let email = contact.email, !email.isEmpty {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            if let phone = contact.phone, !phone.isEmpty {
                                Text(phone)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    VStack(spacing: 8) {
                        TextField("Contact Name", text: $newContactName)
                        TextField("Role (optional)", text: $newContactRole)
                        HStack {
                            TextField("Email (optional)", text: $newContactEmail)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                            TextField("Phone (optional)", text: $newContactPhone)
                                .keyboardType(.phonePad)
                        }
                        Button {
                            guard !newContactName.isEmpty else { return }
                            let contact = VenueDetail.VenueContact(
                                name: newContactName,
                                role: newContactRole.isEmpty ? nil : newContactRole,
                                email: newContactEmail.isEmpty ? nil : newContactEmail,
                                phone: newContactPhone.isEmpty ? nil : newContactPhone
                            )
                            contacts.append(contact)
                            newContactName = ""
                            newContactRole = ""
                            newContactEmail = ""
                            newContactPhone = ""
                        } label: {
                            Label("Add Contact", systemImage: "plus.circle.fill")
                        }
                        .disabled(newContactName.isEmpty)
                    }
                } header: {
                    Text("Contacts")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Venue" : "Add Venue")
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
                        Task { await saveVenue() }
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
    
    private func saveVenue() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteVenueDetailRepository(httpClient: httpClient)
            
            let venueToSave = VenueDetail(
                id: venue?.id ?? 0,
                name: name,
                email: email.isEmpty ? nil : email,
                phone: phone.isEmpty ? nil : phone,
                website: website.isEmpty ? nil : website,
                description: description.isEmpty ? nil : description,
                address1: address1.isEmpty ? nil : address1,
                address2: address2.isEmpty ? nil : address2,
                city: city.isEmpty ? nil : city,
                state: state.isEmpty ? nil : state,
                postalCode: postalCode.isEmpty ? nil : postalCode,
                geoLat: Double(geoLat),
                geoLon: Double(geoLon),
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
                autoImportCities: autoImportCities.isEmpty ? nil : autoImportCities,
                rooms: rooms.isEmpty ? nil : rooms,
                contacts: contacts.isEmpty ? nil : contacts
            )
            
            if isEditMode {
                _ = try await repository.update(venueToSave, instance: instance)
            } else {
                _ = try await repository.create(venueToSave, instance: instance)
            }
            
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Image Upload Methods
    
    @MainActor
    private func uploadProfileImage(_ item: PhotosPickerItem?) async {
        guard let item = item else {
            DebugLogger.log("VenueFormView: uploadProfileImage called with nil item")
            return
        }
        guard let instance = instanceStore.activeInstance else {
            DebugLogger.log("VenueFormView: No active instance")
            return
        }
        
        DebugLogger.log("VenueFormView: Starting profile image upload")
        isUploadingProfileImage = true
        
        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image data"
                DebugLogger.log("VenueFormView: Failed to load image data")
                isUploadingProfileImage = false
                return
            }
            
            DebugLogger.log("VenueFormView: Image data loaded, size: \(imageData.count) bytes")
            let uploadedURL = try await uploadImageToServer(imageData: imageData, instance: instance)
            DebugLogger.log("VenueFormView: Upload successful, URL: \(uploadedURL)")
            profileImageUrl = uploadedURL
        } catch {
            errorMessage = "Failed to upload profile image: \(error.localizedDescription)"
            DebugLogger.log("VenueFormView: Upload error: \(error)")
        }
        
        isUploadingProfileImage = false
        profileImageSelection = nil
    }
    
    @MainActor
    private func uploadHeaderImage(_ item: PhotosPickerItem?) async {
        guard let item = item else {
            DebugLogger.log("VenueFormView: uploadHeaderImage called with nil item")
            return
        }
        guard let instance = instanceStore.activeInstance else {
            DebugLogger.log("VenueFormView: No active instance")
            return
        }
        
        DebugLogger.log("VenueFormView: Starting header image upload")
        isUploadingHeaderImage = true
        
        do {
            guard let imageData = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Failed to load image data"
                DebugLogger.log("VenueFormView: Failed to load image data")
                isUploadingHeaderImage = false
                return
            }
            
            DebugLogger.log("VenueFormView: Image data loaded, size: \(imageData.count) bytes")
            let uploadedURL = try await uploadImageToServer(imageData: imageData, instance: instance)
            DebugLogger.log("VenueFormView: Upload successful, URL: \(uploadedURL)")
            headerImageUrl = uploadedURL
        } catch {
            errorMessage = "Failed to upload header image: \(error.localizedDescription)"
            DebugLogger.log("VenueFormView: Upload error: \(error)")
        }
        
        isUploadingHeaderImage = false
        headerImageSelection = nil
    }
    
    private func uploadImageToServer(imageData: Data, instance: InstanceProfile) async throws -> String {
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add form field for the image
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let uploadURL = instance.baseURL.appendingPathComponent("media")
        DebugLogger.log("VenueFormView: Uploading to: \(uploadURL.absoluteString)")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Add authentication - use same method as HTTPClient
        if let token = AuthTokenStore.shared.token(for: instance) {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            DebugLogger.log("VenueFormView: Using Bearer token")
        } else if let apiKey = APIKeyStore.shared.load(for: instance) {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            DebugLogger.log("VenueFormView: Using X-API-Key")
        } else {
            DebugLogger.log("VenueFormView: No auth available")
        }
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            DebugLogger.log("VenueFormView: Invalid HTTP response")
            throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        DebugLogger.log("VenueFormView: Upload response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            if let responseString = String(data: data, encoding: .utf8) {
                DebugLogger.log("VenueFormView: Error response: \(responseString)")
            }
            throw NSError(domain: "Upload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(httpResponse.statusCode)"])
        }
        
        // Parse response to get the uploaded image URL from nested asset object
        if let responseString = String(data: data, encoding: .utf8) {
            DebugLogger.log("VenueFormView: Upload response: \(responseString)")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let asset = json["asset"] as? [String: Any],
           let url = asset["url"] as? String {
            let absoluteURL = makeAbsoluteURL(url, baseURL: instance.baseURL)
            DebugLogger.log("VenueFormView: Parsed URL: \(url) -> Absolute: \(absoluteURL)")
            return absoluteURL
        }
        
        DebugLogger.log("VenueFormView: Failed to parse URL from response")
        throw NSError(domain: "Upload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse URL from response"])
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
        DebugLogger.log("VenueFormView: Selected profile image from library: \(absoluteURL)")
    }
    
    private func selectHeaderMediaLibraryImage(_ mediaItem: MediaItem) {
        guard let instance = instanceStore.activeInstance else { return }
        let absoluteURL = makeAbsoluteURL(mediaItem.url, baseURL: instance.baseURL)
        headerImageUrl = absoluteURL
        DebugLogger.log("VenueFormView: Selected header image from library: \(absoluteURL)")
    }
}
