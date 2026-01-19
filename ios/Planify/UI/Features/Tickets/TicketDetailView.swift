import SwiftUI
import CoreImage.CIFilterBuiltins

struct TicketDetailView: View {
    @EnvironmentObject var instanceStore: InstanceStore
    @Environment(\.httpClient) private var httpClient
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    
    let ticket: TicketSale
    let onUpdate: () -> Void
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sale Information") {
                    LabeledContent("Name", value: ticket.name)
                    LabeledContent("Email", value: ticket.email)
                    LabeledContent("Status", value: ticket.status.displayName)
                    if let event = ticket.event {
                        LabeledContent("Event", value: event.name)
                    }
                }
                
                Section("QR Code") {
                    HStack {
                        Spacer()
                        if let qrImage = generateQRCode(from: "ticket-\(ticket.id)") {
                            Image(uiImage: qrImage)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Tickets") {
                    ForEach(ticket.tickets) { saleTicket in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Ticket #\(saleTicket.ticketId)")
                                    .font(.headline)
                                Text(saleTicket.usageStatus.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("Qty: \(saleTicket.quantity)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Payment Actions") {
                    Button {
                        Task { await markAsPaid() }
                    } label: {
                        Label("Mark as Paid", systemImage: "checkmark.circle")
                    }
                    .disabled(isLoading)
                    
                    Button {
                        Task { await markAsUnpaid() }
                    } label: {
                        Label("Mark as Unpaid", systemImage: "xmark.circle")
                    }
                    .disabled(isLoading)
                    
                    Button {
                        Task { await refundTicket() }
                    } label: {
                        Label("Refund", systemImage: "dollarsign.circle")
                    }
                    .disabled(isLoading)
                    
                    Button(role: .destructive) {
                        Task { await cancelTicket() }
                    } label: {
                        Label("Cancel Ticket", systemImage: "xmark")
                    }
                    .disabled(isLoading)
                }
                
                Section("Usage Actions") {
                    Button {
                        Task { await markAsUsed() }
                    } label: {
                        Label("Mark as Used", systemImage: "checkmark.square")
                    }
                    .disabled(isLoading)
                    
                    Button {
                        Task { await markAsUnused() }
                    } label: {
                        Label("Mark as Unused", systemImage: "ticket")
                    }
                    .disabled(isLoading)
                }
                
                Section {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete Ticket Sale", systemImage: "trash")
                    }
                    .disabled(isLoading)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Ticket Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Ticket Sale", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteTicket() }
                }
            } message: {
                Text("Are you sure you want to delete this ticket sale for \(ticket.name)? This action cannot be undone.")
            }
        }
        .accentColor(theme.accent)
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        
        return nil
    }
    
    private func refreshTicket() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            
            // Try to fetch individual ticket first
            do {
                _ = try await repository.fetch(id: ticket.id, instance: instance)
                DebugLogger.log("Successfully refreshed ticket \(ticket.id)")
            } catch {
                // If individual fetch fails, search for it in the list
                DebugLogger.log("Individual fetch failed, searching in list: \(error)")
                let tickets = try await repository.search(eventId: ticket.eventId, query: nil, instance: instance)
                if let _ = tickets.first(where: { $0.id == ticket.id }) {
                    DebugLogger.log("Found ticket \(ticket.id) in list")
                } else {
                    DebugLogger.error("Ticket \(ticket.id) not found in list")
                }
            }
            
            onUpdate()
        } catch {
            errorMessage = error.localizedDescription
            DebugLogger.error("Failed to refresh ticket: \(error)")
        }
    }
    
    private func markAsPaid() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.markAsPaid(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func markAsUnpaid() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.markAsUnpaid(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func cancelTicket() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.cancel(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func refundTicket() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.refund(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func markAsUsed() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.markAsUsed(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func markAsUnused() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.markAsUnused(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    private func deleteTicket() async {
        guard let instance = instanceStore.activeInstance else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let repository = RemoteTicketRepository(httpClient: httpClient)
            _ = try await repository.delete(id: ticket.id, instance: instance)
            onUpdate()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
