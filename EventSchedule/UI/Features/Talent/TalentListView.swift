import SwiftUI

struct TalentListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var talents: [Talent] = []
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
            .navigationTitle("Talent")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button(action: { /* TODO: Add new talent */ }) {
                            Image(systemName: "plus")
                        }
                        .disabled(instanceStore.activeInstance == nil)
                    }
                }
            }
            .task {
                await loadTalent()
            }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
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
                TalentRow(talent: talent)
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
}

private struct TalentRow: View {
    let talent: Talent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(talent.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
            }
            
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
        .padding(.vertical, 4)
    }
}
