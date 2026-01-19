import SwiftUI

struct VenueDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var venue: VenueDetail
    @State private var isEditing = false
    @State private var isPerformingAction = false
    @State private var actionError: String?
    @State private var showingDeleteConfirm = false
    
    private let onSave: ((VenueDetail) -> Void)?
    private let onDelete: ((VenueDetail) -> Void)?
    
    init(venue: VenueDetail, onSave: ((VenueDetail) -> Void)? = nil, onDelete: ((VenueDetail) -> Void)? = nil) {
        _venue = State(initialValue: venue)
        self.onSave = onSave
        self.onDelete = onDelete
    }
    
    private func makeAbsoluteURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        
        // If already absolute, return as-is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
        
        // Convert relative URL to absolute
        guard let instance = instanceStore.activeInstance else { return nil }
        var baseURLString = instance.baseURL.absoluteString
        if baseURLString.hasSuffix("/api") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        if baseURLString.hasSuffix("/") {
            baseURLString = String(baseURLString.dropLast())
        }
        let path = urlString.hasPrefix("/") ? urlString : "/" + urlString
        return URL(string: baseURLString + path)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header image banner
                if let url = makeAbsoluteURL(venue.headerImageUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(height: 200)
                    .clipped()
                }
                
                // Profile image overlapping header
                VStack(spacing: 16) {
                    if let url = makeAbsoluteURL(venue.profileImageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(UIColor.systemBackground), lineWidth: 4))
                        .offset(y: -60)
                        .padding(.bottom, -60)
                    }
                    
                    // Name and basic info
                    VStack(spacing: 8) {
                        Text(venue.name)
                            .font(.title)
                            .bold()
                        
                        if !venue.displayAddress.isEmpty {
                            Label(venue.displayAddress, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, venue.headerImageUrl != nil ? 0 : 20)
                
                // Details sections
                Form {
                    if venue.email != nil || venue.phone != nil || venue.website != nil {
                        Section("Contact Information") {
                            if let email = venue.email, !email.isEmpty {
                                HStack {
                                    Label("Email", systemImage: "envelope")
                                    Spacer()
                                    if venue.showEmail ?? true {
                                        Text(email)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Hidden")
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                            }
                            
                            if let phone = venue.phone, !phone.isEmpty {
                                HStack {
                                    Label("Phone", systemImage: "phone")
                                    Spacer()
                                    Text(phone)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let website = venue.website, !website.isEmpty {
                                HStack {
                                    Label("Website", systemImage: "globe")
                                    Spacer()
                                    Link(website, destination: URL(string: website) ?? URL(string: "https://example.com")!)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    Section("Address") {
                        if let address1 = venue.address1, !address1.isEmpty {
                            HStack {
                                Label("Street", systemImage: "mappin")
                                Spacer()
                                Text(address1)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let address2 = venue.address2, !address2.isEmpty {
                            HStack {
                                Label("Address 2", systemImage: "mappin")
                                Spacer()
                                Text(address2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let city = venue.city, !city.isEmpty {
                            HStack {
                                Label("City", systemImage: "building.2")
                                Spacer()
                                Text(city)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let state = venue.state, !state.isEmpty {
                            HStack {
                                Label("State", systemImage: "map")
                                Spacer()
                                Text(state)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let postalCode = venue.postalCode, !postalCode.isEmpty {
                            HStack {
                                Label("Postal Code", systemImage: "number")
                                Spacer()
                                Text(postalCode)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let countryCode = venue.countryCode, !countryCode.isEmpty {
                            HStack {
                                Label("Country", systemImage: "flag")
                                Spacer()
                                Text(countryCode.uppercased())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let rooms = venue.rooms, !rooms.isEmpty {
                        Section("Rooms") {
                            ForEach(rooms, id: \.name) { room in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(room.name)
                                        .font(.headline)
                                    if let capacity = room.capacity {
                                        Text("Capacity: \(capacity)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let description = room.description, !description.isEmpty {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if let contacts = venue.contacts, !contacts.isEmpty {
                        Section("Contacts") {
                            ForEach(contacts, id: \.name) { contact in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(contact.name)
                                        .font(.headline)
                                    if let role = contact.role, !role.isEmpty {
                                        Text(role)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    if let email = contact.email, !email.isEmpty {
                                        Label(email, systemImage: "envelope")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let phone = contact.phone, !phone.isEmpty {
                                        Label(phone, systemImage: "phone")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if venue.timezone != nil || venue.geoLat != nil {
                        Section("Location Settings") {
                            if let timezone = venue.timezone, !timezone.isEmpty {
                                HStack {
                                    Label("Timezone", systemImage: "clock")
                                    Spacer()
                                    Text(timezone)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            if let geoLat = venue.geoLat, let geoLon = venue.geoLon {
                                HStack {
                                    Label("Coordinates", systemImage: "location")
                                    Spacer()
                                    Text("\(geoLat), \(geoLon)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                    
                    Section("Actions") {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Venue", systemImage: "trash")
                        }
                        .disabled(isPerformingAction)
                        
                        if let actionError = actionError {
                            Text(actionError)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Venue")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            VenueFormView(venue: venue) {
                Task { await refreshVenue() }
            }
            .environmentObject(instanceStore)
            .environment(\.httpClient, httpClient)
            .environment(\.theme, theme)
        }
        .alert("Delete Venue", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteVenue() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(venue.name)? This action cannot be undone.")
        }
        .accentColor(theme.accent)
    }
    
    private func deleteVenue() async {
        guard let instance = instanceStore.activeInstance else { return }
        guard !isPerformingAction else { return }
        
        isPerformingAction = true
        actionError = nil
        
        do {
            let repository = RemoteVenueDetailRepository(httpClient: httpClient)
            try await repository.delete(id: venue.id, instance: instance)
            
            await MainActor.run {
                onDelete?(venue)
                dismiss()
                isPerformingAction = false
            }
        } catch {
            await MainActor.run {
                actionError = error.localizedDescription
                isPerformingAction = false
            }
        }
    }
    
    private func refreshVenue() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteVenueDetailRepository(httpClient: httpClient)
            let updated = try await repository.fetch(id: venue.id, instance: instance)
            
            await MainActor.run {
                venue = updated
                onSave?(updated)
            }
        } catch {
            // Keep showing existing venue
        }
    }
}
