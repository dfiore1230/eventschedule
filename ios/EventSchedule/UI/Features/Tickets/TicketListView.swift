import SwiftUI

struct TicketListView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.theme) private var theme
    
    @State private var tickets: [TicketSale] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var searchQuery = ""
    @State private var sortBy: SortOption = .event
    @State private var ticketToDelete: TicketSale?
    @State private var showingDeleteAlert = false
    @State private var currentPage: Int = 1
    @State private var lastPage: Int = 1
    @State private var perPage: Int = 25
    @State private var toastMessage: String?
    @State private var showingScanner: Bool = false
    @State private var isProcessingScan: Bool = false
    
    enum SortOption: String, CaseIterable {
        case event = "Event"
        case status = "Status"
        case name = "Name"
        case date = "Date"
    }
    
    var sortedAndGroupedTickets: [(String, [TicketSale])] {
        let sorted: [TicketSale]
        switch sortBy {
        case .event:
            sorted = tickets.sorted { ($0.event?.name ?? "") < ($1.event?.name ?? "") }
        case .status:
            sorted = tickets.sorted { $0.status.rawValue < $1.status.rawValue }
        case .name:
            sorted = tickets.sorted { $0.name < $1.name }
        case .date:
            sorted = tickets.sorted { ($0.id) > ($1.id) }
        }
        
        // Group by event when sorting by event
        if sortBy == .event {
            let grouped = Dictionary(grouping: sorted) { $0.event?.name ?? "Unknown Event" }
            return grouped.sorted { $0.key < $1.key }
        } else {
            return [("All Tickets", sorted)]
        }
    }
    
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
            .overlay(alignment: .bottom) {
                if let toast = toastMessage {
                    Button(action: { withAnimation { toastMessage = nil } }) {
                        Text(toast)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .padding(.bottom, 24)
                            .transition(.opacity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ScanToast")
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isLoading {
                        ProgressView()
                    } else {
                        HStack {
                            Button(action: { showingScanner = true }) {
                                Image(systemName: "qrcode.viewfinder")
                            }
                            .padding(.trailing, 8)
                            .accessibilityIdentifier("TicketsScanButton")

                        Menu {
                            Picker("Sort By", selection: $sortBy) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        }
                    }
                }
            }

        .sheet(isPresented: $showingScanner) {
            if let instance = instanceStore.activeInstance {
                QRScannerView { scannedCode in
                    showingScanner = false
                    Task { await processScan(code: scannedCode, instance: instance) }
                }
            }
        }
            .alert("Delete Ticket Sale", isPresented: $showingDeleteAlert, presenting: ticketToDelete) { ticket in
                Button("Cancel", role: .cancel) {
                    ticketToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    Task { await deleteTicket(ticket) }
                }
            } message: { ticket in
                Text("Are you sure you want to delete the ticket sale for \(ticket.name)? This action cannot be undone.")
            }
            .task {
                await searchTickets()
            }
            .onChange(of: instanceStore.activeInstance?.id) { _, _ in
                tickets = []
                errorMessage = nil
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
            
            ForEach(sortedAndGroupedTickets, id: \.0) { section in
                if sortBy == .event {
                    Section(section.0) {
                        ForEach(section.1) { ticket in
                            ticketRowWithActions(ticket)
                        }
                    }
                } else {
                    ForEach(section.1) { ticket in
                        ticketRowWithActions(ticket)
                    }
                }
            }

            if currentPage < lastPage {
                HStack {
                    Spacer()
                    if isLoadingMore {
                        ProgressView().padding(.vertical, 8)
                    } else {
                        Button(action: { Task { await loadMoreTickets() } }) {
                            Label("Load More", systemImage: "arrow.down.circle")
                        }
                        .padding(.vertical, 8)
                    }
                    Spacer()
                }
            }
        }
        .refreshable {
            await searchTickets()
        }
    }
    
    @ViewBuilder
    private func ticketRowWithActions(_ ticket: TicketSale) -> some View {
        NavigationLink {
            TicketDetailView(ticket: ticket, onUpdate: { Task { await searchTickets() } })
                .environmentObject(instanceStore)
                .environment(\.httpClient, httpClient)
                .environment(\.theme, theme)
        } label: {
            TicketRow(ticket: ticket)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                ticketToDelete = ticket
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                Task { await refundTicket(ticket) }
            } label: {
                Label("Refund", systemImage: "dollarsign.circle")
            }
            .tint(.purple)
            
            Button {
                Task { await markAsUnpaid(ticket) }
            } label: {
                Label("Unpaid", systemImage: "xmark.circle")
            }
            .tint(.orange)
            
            Button {
                Task { await markAsPaid(ticket) }
            } label: {
                Label("Paid", systemImage: "checkmark.circle")
            }
            .tint(.green)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Task { await markAsUnused(ticket) }
            } label: {
                Label("Unused", systemImage: "ticket")
            }
            .tint(.blue)
            
            Button {
                Task { await markAsUsed(ticket) }
            } label: {
                Label("Used", systemImage: "checkmark.square")
            }
            .tint(.purple)
            
            Button {
                Task { await cancelTicket(ticket) }
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(.red)
        }
        .contextMenu {
            Section("Payment Status") {
                Button {
                    Task { await markAsPaid(ticket) }
                } label: {
                    Label("Mark as Paid", systemImage: "checkmark.circle")
                }
                
                Button {
                    Task { await markAsUnpaid(ticket) }
                } label: {
                    Label("Mark as Unpaid", systemImage: "xmark.circle")
                }
                
                Button {
                    Task { await refundTicket(ticket) }
                } label: {
                    Label("Refund", systemImage: "dollarsign.circle")
                }
                
                Button(role: .destructive) {
                    Task { await cancelTicket(ticket) }
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
            }
            
            Section("Usage Status") {
                Button {
                    Task { await markAsUsed(ticket) }
                } label: {
                    Label("Mark as Used", systemImage: "checkmark.square")
                }
                
                Button {
                    Task { await markAsUnused(ticket) }
                } label: {
                    Label("Mark as Unused", systemImage: "ticket")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                ticketToDelete = ticket
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func processScan(code: String, instance: InstanceProfile) async {
        guard !isProcessingScan else { return }
        isProcessingScan = true
        toastMessage = nil

        let checkInRepo = RemoteCheckInRepository(httpClient: httpClient)
        do {
            let result = try await checkInRepo.scanTicket(code: code, eventId: "", gateId: nil, deviceId: UIDevice.current.identifierForVendor?.uuidString, instance: instance)
            await MainActor.run {
                if result.status.isSuccess {
                    // Prefer server-provided message when present (e.g., fallback generic success)
                    if let msg = result.message, !msg.isEmpty {
                        toastMessage = "✅ \(result.status.displayName) - \(msg)"
                    } else {
                        toastMessage = "✅ \(result.status.displayName) - \(result.holder ?? "Unknown")"
                    }
                } else {
                    var msg = "⚠️ \(result.status.displayName)"
                    if let extra = result.message, !extra.isEmpty {
                        msg += ": \(extra)"
                    }
                    toastMessage = msg
                }
            }
            // Refresh tickets list to reflect updated status
            await searchTickets()
        } catch {
            await MainActor.run {
                toastMessage = "❌ Scan failed: \(error.localizedDescription)"
            }
        }

        await Task.sleep(UInt64(3_000_000_000))
        await MainActor.run {
            withAnimation { toastMessage = nil }
            isProcessingScan = false
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
        currentPage = 1
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let query = searchQuery.isEmpty ? nil : searchQuery
            let (pageData, meta) = try await repository.searchPage(eventId: nil, query: query, page: currentPage, perPage: perPage, instance: instance)
            tickets = pageData
            lastPage = meta?.lastPage ?? 1
            DebugLogger.log("Loaded page #\(currentPage) of \(lastPage). Tickets: \(tickets.count)")
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    private func loadMoreTickets() async {
        guard let instance = instanceStore.activeInstance else { return }
        guard currentPage < lastPage else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let query = searchQuery.isEmpty ? nil : searchQuery
            let nextPage = currentPage + 1
            let (pageData, meta) = try await repository.searchPage(eventId: nil, query: query, page: nextPage, perPage: perPage, instance: instance)
            tickets.append(contentsOf: pageData)
            currentPage = nextPage
            lastPage = meta?.lastPage ?? currentPage
            DebugLogger.log("Appended page #\(currentPage). Total tickets: \(tickets.count)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func markAsPaid(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let updated = try await repository.markAsPaid(id: ticket.id, instance: instance)
            
            await searchTickets()
            if updated.status != .paid {
                errorMessage = "Server did not apply the change. Ticket status remains '\(updated.status.displayName)'."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func markAsUnpaid(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let updated = try await repository.markAsUnpaid(id: ticket.id, instance: instance)
            
            await searchTickets()
            if updated.status != .unpaid {
                errorMessage = "Server did not apply the change. Ticket status remains '\(updated.status.displayName)'."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func cancelTicket(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let updated = try await repository.cancel(id: ticket.id, instance: instance)
            
            await searchTickets()
            if updated.status != .cancelled {
                errorMessage = "Server did not apply the change. Ticket status remains '\(updated.status.displayName)'."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func refundTicket(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let updated = try await repository.refund(id: ticket.id, instance: instance)
            
            await searchTickets()
            if updated.status != .refunded {
                errorMessage = "Server did not apply the change. Ticket status remains '\(updated.status.displayName)'."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func markAsUsed(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.markAsUsed(id: ticket.id, instance: instance)
            // Delay to let backend cache invalidate (1.5 seconds)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await searchTickets()
            if let updated = tickets.first(where: { $0.id == ticket.id }) {
                let details = updated.tickets.map { "id:\($0.id) status:\($0.usageStatus)" }.joined(separator: " | ")
                DebugLogger.log("After mark_used sale #\(ticket.id): ticket details=[\(details)]")
            }
            showToast("Marked as Used for sale #\(ticket.id)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func markAsUnused(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.markAsUnused(id: ticket.id, instance: instance)
            // Delay to let backend cache invalidate (1.5 seconds)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await searchTickets()
            if let updated = tickets.first(where: { $0.id == ticket.id }) {
                let details = updated.tickets.map { "id:\($0.id) status:\($0.usageStatus)" }.joined(separator: " | ")
                DebugLogger.log("After mark_unused sale #\(ticket.id): ticket details=[\(details)]")
            }
            showToast("Marked as Unused for sale #\(ticket.id)")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteTicket(_ ticket: TicketSale) async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            let updated = try await repository.delete(id: ticket.id, instance: instance)
            
            await searchTickets()
            if updated.status != .deleted {
                errorMessage = "Server did not delete the ticket. Status is '\(updated.status.displayName)'."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        ticketToDelete = nil
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
            Label("Sale #\(ticket.id)", systemImage: "number")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            HStack(spacing: 12) {
                Label("\(ticket.totalQuantity) ticket(s)", systemImage: "ticket")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !ticket.tickets.isEmpty {
                    usageStatusBadge
                }
                
                Text(ticket.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("TicketRow_\(ticket.id)")
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
        case .pending, .unpaid: return .orange
        case .refunded, .cancelled: return .red
        case .expired, .deleted: return .gray
        }
    }
    
    @ViewBuilder
    private var usageStatusBadge: some View {
        if ticket.tickets.isEmpty {
            // No tickets data available
            Label("No Data", systemImage: "square.dashed")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            let allUsed = ticket.tickets.allSatisfy { $0.usageStatus.lowercased() == "used" }
            let anyUsed = ticket.tickets.contains { $0.usageStatus.lowercased() == "used" }
            
            if allUsed {
                Label("Used", systemImage: "checkmark.square.fill")
                    .font(.caption)
                    .foregroundColor(.purple)
            } else if anyUsed {
                Label("Partial", systemImage: "square.split.2x1.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Label("Unused", systemImage: "square")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private extension TicketListView {
    func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { toastMessage = nil }
        }
    }
}
