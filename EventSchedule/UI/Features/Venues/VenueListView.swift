import SwiftUI

struct VenueListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var venues: [VenueDetail] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
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
                        Button(action: { /* TODO: Add new venue */ }) {
                            Image(systemName: "plus")
                        }
                        .disabled(instanceStore.activeInstance == nil)
                    }
                }
            }
            .task {
                await loadVenues()
            }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
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
                VenueRow(venue: venue)
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
}

private struct VenueRow: View {
    let venue: VenueDetail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(venue.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
            }
            
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
        .padding(.vertical, 4)
    }
}
