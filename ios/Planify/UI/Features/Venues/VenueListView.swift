import SwiftUI

struct VenueListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var venues: [VenueDetail] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddVenue = false
    @State private var venueToEdit: VenueDetail?
    @State private var venueToDelete: VenueDetail?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let instance = instanceStore.activeInstance {
                    content(for: instance)
                } else {
                    missingInstanceView
                }
            }
            .navigationTitle("Venues")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(action: { showingAddVenue = true }) {
                            Image(systemName: "plus")
                        }
                        .disabled(instanceStore.activeInstance == nil)
                    }
                }
            }
            .sheet(isPresented: $showingAddVenue) {
                VenueFormView(onSave: { Task { await loadVenues() } })
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
                    .environment(\.theme, theme)
            }
            .sheet(item: $venueToEdit) { venue in
                VenueFormView(venue: venue, onSave: { Task { await loadVenues() } })
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
                    .environment(\.theme, theme)
            }
            .alert("Delete Venue", isPresented: $showingDeleteAlert, presenting: venueToDelete) { venue in
                Button("Cancel", role: .cancel) {
                    venueToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    Task { await deleteVenue(venue) }
                }
            } message: { venue in
                Text("Are you sure you want to delete \(venue.name)? This action cannot be undone.")
            }
            .task {
                await loadVenues()
            }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
                venues = []
                errorMessage = nil
                Task { await loadVenues() }
            }
        }
        .accentColor(theme.accent)
    }
    
    @ViewBuilder
    private func content(for instance: InstanceProfile) -> some View {
        List {
            if isLoading && venues.isEmpty {
                loadingRow
            }
            
            if let errorMessage = errorMessage {
                errorRow(message: errorMessage)
            }
            
            if venues.isEmpty && !isLoading {
                emptyState(for: instance)
            }
            
            ForEach(venues) { venue in
                NavigationLink {
                    VenueDetailView(venue: venue, onSave: { updated in
                        if let index = venues.firstIndex(where: { $0.id == updated.id }) {
                            venues[index] = updated
                        }
                    }, onDelete: { deleted in
                        venues.removeAll { $0.id == deleted.id }
                    })
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
                    .environment(\.theme, theme)
                } label: {
                    VenueRow(venue: venue)
                        .environmentObject(instanceStore)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        venueToDelete = venue
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        venueToEdit = venue
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        venueToEdit = venue
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        venueToDelete = venue
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .refreshable {
            await loadVenues()
        }
    }
    
    private var loadingRow: some View {
        HStack {
            ProgressView()
            Text("Loading venues…")
                .foregroundColor(.secondary)
        }
    }
    
    private func emptyState(for instance: InstanceProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No venues yet")
                .font(.headline)
            Text("Add venues for \(instance.displayName).")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to load venues", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { Task { await loadVenues() } }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }
        .padding(.vertical, 8)
    }
    
    private var missingInstanceView: some View {
        VStack(spacing: 12) {
            Text("Add an instance to manage venues.")
                .foregroundColor(.secondary)
        }
    }
    
    private func loadVenues() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteVenueDetailRepository(httpClient: httpClient)
            venues = try await repository.fetchAll(instance: instance)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func deleteVenue(_ venue: VenueDetail) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteVenueDetailRepository(httpClient: httpClient)
            try await repository.delete(id: venue.id, instance: instance)
            venues.removeAll { $0.id == venue.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        venueToDelete = nil
    }
}

private struct VenueRow: View {
    let venue: VenueDetail
    @EnvironmentObject var instanceStore: InstanceStore
    
    private func makeAbsoluteURL(_ urlString: String?) -> URL? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return URL(string: urlString)
        }
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
        HStack(alignment: .top, spacing: 12) {
            // Profile image
            if let url = makeAbsoluteURL(venue.profileImageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "building.2.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(venue.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if !venue.displayAddress.isEmpty {
                    Label(venue.displayAddress, systemImage: "location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    if let phone = venue.phone, !phone.isEmpty {
                        Label(phone, systemImage: "phone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    if let email = venue.email, !email.isEmpty {
                        Label(email, systemImage: "envelope")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
