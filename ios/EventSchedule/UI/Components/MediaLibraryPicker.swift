import SwiftUI

struct MediaLibraryPicker: View {
    let instance: InstanceProfile
    let onSelect: (MediaItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: MediaItem?
    
    private let repository: MediaLibraryRepositoryProtocol
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]
    
    init(
        instance: InstanceProfile,
        repository: MediaLibraryRepositoryProtocol = RemoteMediaLibraryRepository(),
        onSelect: @escaping (MediaItem) -> Void
    ) {
        self.instance = instance
        self.repository = repository
        self.onSelect = onSelect
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading && mediaItems.isEmpty {
                    ProgressView("Loading media library...")
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await loadMedia()
                            }
                        }
                    }
                    .padding()
                } else if mediaItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No images in media library")
                            .font(.headline)
                        Text("Upload images to see them here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(mediaItems) { item in
                                MediaItemThumbnail(item: item, instance: instance, isSelected: selectedItem?.id == item.id)
                                    .onTapGesture {
                                        selectedItem = item
                                    }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Media Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Select") {
                        if let selectedItem = selectedItem {
                            onSelect(selectedItem)
                            dismiss()
                        }
                    }
                    .disabled(selectedItem == nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Debug: Log IDs") {
                        DebugLogger.log("Media items count=\(mediaItems.count) IDs=\(mediaItems.map { String($0.id) }.joined(separator: ", "))")
                    }
                    .accessibilityIdentifier("MediaDebugLogButton")
                }
            }
        }
        .task {
            await loadMedia()
        }
    }
    
    private func loadMedia() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load entire library (page through results) so users can see all images
            mediaItems = try await repository.fetchAllMedia(instance: instance)
        } catch {
            errorMessage = "Failed to load media library: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}

struct MediaItemThumbnail: View {
    let item: MediaItem
    let instance: InstanceProfile
    let isSelected: Bool
    
    private var fullImageURL: URL? {
        var baseURLString = instance.baseURL.absoluteString
        if baseURLString.hasSuffix("/api") {
            baseURLString = String(baseURLString.dropLast(4))
        }
        if baseURLString.hasSuffix("/") {
            baseURLString = String(baseURLString.dropLast())
        }
        return URL(string: baseURLString + item.url)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            AsyncImage(url: fullImageURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                        )
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color.white))
                    .offset(x: 4, y: -4)
            }
        }
    }
}

#Preview {
    let instance = InstanceProfile(
        id: UUID(),
        displayName: "Test",
        baseURL: URL(string: "https://example.com/api")!,
        environment: .dev,
        authMethod: .sanctum,
        authEndpoints: nil,
        featureFlags: [:],
        minAppVersion: nil,
        rateLimits: nil,
        tokenIdentifier: nil,
        theme: nil
    )
    
    MediaLibraryPicker(instance: instance) { item in
        print("Selected: \(item.originalFilename)")
    }
}
