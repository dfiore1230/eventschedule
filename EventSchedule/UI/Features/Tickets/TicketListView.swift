import SwiftUI

struct TicketListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var tickets: [TicketSale] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if let instance = instanceStore.activeInstance {
                    content(for: instance)
                } else {
                    missingInstanceView
                }
            }
            .navigationTitle("Tickets")
            .searchable(text: $searchQuery, prompt: "Search by name, email, or code")
            .onSubmit(of: .search) {
                Task { await searchTickets() }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    }
                }
            }
            .task {
                await searchTickets()
            }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
                Task { await searchTickets() }
            }
        }
        .accentColor(theme.accent)
    }
    
    @ViewBuilder
    private func content(for instance: InstanceProfile) -> some View {
        List {
            if isLoading && tickets.isEmpty {
                loadingRow
            }
            
            if let errorMessage = errorMessage {
                errorRow(message: errorMessage)
            }
            
            if tickets.isEmpty && !isLoading {
                emptyState(for: instance)
            }
            
            ForEach(tickets) { ticket in
                TicketRow(ticket: ticket)
            }
        }
        .refreshable {
            await searchTickets()
        }
    }
    
    private var loadingRow: some View {
        HStack {
            ProgressView()
            Text("Loading tickets…")
                .foregroundColor(.secondary)
        }
    }
    
    private func emptyState(for instance: InstanceProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No tickets found")
                .font(.headline)
            Text("Search for tickets or wait for ticket sales for \(instance.displayName).")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }
    
    private func errorRow(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unable to load tickets", systemImage: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button(action: { Task { await searchTickets() } }) {
                Label("Retry", systemImage: "arrow.clockwise")
            }
        }
        .padding(.vertical, 8)
    }
    
    private var missingInstanceView: some View {
        VStack(spacing: 12) {
            Text("Add an instance to manage tickets.")
                .foregroundColor(.secondary)
        }
    }
    
    private func searchTickets() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let query = searchQuery.isEmpty ? nil : searchQuery
            tickets = try await repository.search(eventId: nil, query: query, instance: instance)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

private struct TicketRow: View {
    let ticket: TicketSale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(ticket.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                statusBadge
            }
            
            if let event = ticket.event {
                Label(event.name, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 12) {
                Label("\(ticket.totalQuantity) ticket(s)", systemImage: "ticket")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(ticket.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        Text(ticket.displayStatus)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch ticket.status {
        case .paid: return .green
        case .pending: return .orange
        case .refunded, .cancelled: return .red
        case .expired: return .gray
        }
    }
}
