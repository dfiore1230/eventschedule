import SwiftUI

struct TalentListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var talents: [Talent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingAddTalent = false
    @State private var talentToEdit: Talent?
    @State private var talentToDelete: Talent?
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
            .navigationTitle("Talent")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(action: { showingAddTalent = true }) {
                            Image(systemName: "plus")
                        }
                        .disabled(instanceStore.activeInstance == nil)
                    }
                }
            }
            .sheet(isPresented: $showingAddTalent) {
                TalentFormView(onSave: { Task { await loadTalent() } })
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
                    .environment(\.theme, theme)
            }
            .sheet(item: $talentToEdit) { talent in
                TalentFormView(talent: talent, onSave: { Task { await loadTalent() } })
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
                    .environment(\.theme, theme)
            }
            .alert("Delete Talent", isPresented: $showingDeleteAlert, presenting: talentToDelete) { talent in
                Button("Cancel", role: .cancel) {
                    talentToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    Task { await deleteTalent(talent) }
                }
            } message: { talent in
                Text("Are you sure you want to delete \(talent.name)? This action cannot be undone.")
            }
            .task {
                await loadTalent()
            }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
                talents = []
                errorMessage = nil
                Task { await loadTalent() }
            }
        }
        .accentColor(theme.accent)
    }
    
    @ViewBuilder
    private func content(for instance: InstanceProfile) -> some View {
        List {
            if isLoading && talents.isEmpty {
                loadingRow
            }
            
            if let errorMessage = errorMessage {
                errorRow(message: errorMessage)
            }
            
            if talents.isEmpty && !isLoading {
                emptyState(for: instance)
            }
            
            ForEach(talents) { talent in
                NavigationLink {
                    TalentDetailView(talent: talent, onSave: { updated in
                        if let index = talents.firstIndex(where: { $0.id == updated.id }) {
                            talents[index] = updated
                        }
                    }, onDelete: { deleted in
                        talents.removeAll { $0.id == deleted.id }
                    })
                    .environmentObject(instanceStore)
                    .environment(\.httpClient, httpClient)
                    .environment(\.theme, theme)
                } label: {
                    TalentRow(talent: talent)
                        .environmentObject(instanceStore)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        talentToDelete = talent
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        talentToEdit = talent
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        talentToEdit = talent
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        talentToDelete = talent
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .refreshable {
            await loadTalent()
        }
    }
    
    private var loadingRow: some View {
        HStack {
            ProgressView()
            Text("Loading talent…")
                .foregroundColor(.secondary)
        }
    }
    
    private func emptyState(for instance: InstanceProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No talent yet")
                .font(.headline)
            Text("Add talent and performers for \(instance.displayName).")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to load talent", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { Task { await loadTalent() } }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }
        .padding(.vertical, 8)
    }
    
    private var missingInstanceView: some View {
        VStack(spacing: 12) {
            Text("Add an instance to manage talent.")
                .foregroundColor(.secondary)
        }
    }
    
    private func loadTalent() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTalentRepository(httpClient: httpClient)
            talents = try await repository.fetchAll(instance: instance)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func deleteTalent(_ talent: Talent) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTalentRepository(httpClient: httpClient)
            try await repository.delete(id: talent.id, instance: instance)
            talents.removeAll { $0.id == talent.id }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        talentToDelete = nil
    }
}

private struct TalentRow: View {
    let talent: Talent
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
            if let url = makeAbsoluteURL(talent.profileImageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(talent.name)
                    .font(.headline)
                    .lineLimit(2)
                
                if let role = talent.role {
                    Text(role)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let bio = talent.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
