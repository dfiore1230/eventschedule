import SwiftUI

struct TalentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var talent: Talent
    @State private var isEditing = false
    @State private var isPerformingAction = false
    @State private var actionError: String?
    @State private var showingDeleteConfirm = false
    
    private let onSave: ((Talent) -> Void)?
    private let onDelete: ((Talent) -> Void)?
    
    init(talent: Talent, onSave: ((Talent) -> Void)? = nil, onDelete: ((Talent) -> Void)? = nil) {
        _talent = State(initialValue: talent)
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
                if let url = makeAbsoluteURL(talent.headerImageUrl) {
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
                    if let url = makeAbsoluteURL(talent.profileImageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 4))
                        .offset(y: -60)
                        .padding(.bottom, -60)
                    }
                    
                    // Name and basic info
                    VStack(spacing: 8) {
                        Text(talent.name)
                            .font(.title)
                            .bold()
                        
                        if let description = talent.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, talent.headerImageUrl != nil ? 0 : 20)
                
                // Details sections
                Form {
                    if talent.email != nil || talent.phone != nil || talent.website != nil {
                        Section("Contact Information") {
                            if let email = talent.email, !email.isEmpty {
                                HStack {
                                    Label("Email", systemImage: "envelope")
                                    Spacer()
                                    if talent.showEmail ?? true {
                                        Text(email)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Hidden")
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                            }
                            
                            if let phone = talent.phone, !phone.isEmpty {
                                HStack {
                                    Label("Phone", systemImage: "phone")
                                    Spacer()
                                    Text(phone)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let website = talent.website, !website.isEmpty {
                                HStack {
                                    Label("Website", systemImage: "globe")
                                    Spacer()
                                    Link(website, destination: URL(string: website) ?? URL(string: "https://example.com")!)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    if talent.address1 != nil || talent.city != nil || talent.state != nil {
                        Section("Address") {
                            if let address1 = talent.address1, !address1.isEmpty {
                                HStack {
                                    Label("Street", systemImage: "mappin")
                                    Spacer()
                                    Text(address1)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let city = talent.city, !city.isEmpty {
                                HStack {
                                    Label("City", systemImage: "building.2")
                                    Spacer()
                                    Text(city)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let state = talent.state, !state.isEmpty {
                                HStack {
                                    Label("State", systemImage: "map")
                                    Spacer()
                                    Text(state)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let postalCode = talent.postalCode, !postalCode.isEmpty {
                                HStack {
                                    Label("Postal Code", systemImage: "number")
                                    Spacer()
                                    Text(postalCode)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if talent.timezone != nil {
                        Section("Settings") {
                            if let timezone = talent.timezone, !timezone.isEmpty {
                                HStack {
                                    Label("Timezone", systemImage: "clock")
                                    Spacer()
                                    Text(timezone)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            if let scheduleTimezone = talent.scheduleTimezone, !scheduleTimezone.isEmpty {
                                HStack {
                                    Label("Schedule Timezone", systemImage: "clock.fill")
                                    Spacer()
                                    Text(scheduleTimezone)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            if let schedule24Hour = talent.schedule24Hour {
                                HStack {
                                    Label("Time Format", systemImage: "clock.badge")
                                    Spacer()
                                    Text(schedule24Hour ? "24-hour" : "12-hour")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if let subschedules = talent.subschedules, !subschedules.isEmpty {
                        Section("Subschedules") {
                            ForEach(subschedules, id: \.self) { subschedule in
                                Text(subschedule)
                            }
                        }
                    }
                    
                    Section("Actions") {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete Talent", systemImage: "trash")
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
        .navigationTitle("Talent")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            TalentFormView(talent: talent) { 
                Task { await refreshTalent() }
            }
            .environmentObject(instanceStore)
            .environment(\.httpClient, httpClient)
            .environment(\.theme, theme)
        }
        .alert("Delete Talent", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await deleteTalent() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(talent.name)? This action cannot be undone.")
        }
        .accentColor(theme.accent)
    }
    
    private func deleteTalent() async {
        guard let instance = instanceStore.activeInstance else { return }
        guard !isPerformingAction else { return }
        
        isPerformingAction = true
        actionError = nil
        
        do {
            let repository = RemoteTalentRepository(httpClient: httpClient)
            try await repository.delete(id: talent.id, instance: instance)
            
            await MainActor.run {
                onDelete?(talent)
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
    
    private func refreshTalent() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTalentRepository(httpClient: httpClient)
            let updated = try await repository.fetch(id: talent.id, instance: instance)
            
            await MainActor.run {
                talent = updated
                onSave?(updated)
            }
        } catch {
            // Keep showing existing talent
        }
    }
}
