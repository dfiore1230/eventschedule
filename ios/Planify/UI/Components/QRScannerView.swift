import SwiftUI
@preconcurrency import AVFoundation
import Combine

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scanner = QRScanner()
    
    let onScan: (String) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                CameraPreview(session: scanner.session)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    // Scanning frame overlay
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 280, height: 280)
                    
                    Spacer()
                    
                    if let error = scanner.error {
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(10)
                            .padding()
                    }
                }
            }
            .navigationTitle("Scan Ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                scanner.start()
            }
            .onDisappear {
                scanner.stop()
            }
            .onChange(of: scanner.scannedCode) { _, newCode in
                if let code = newCode {
                    onScan(code)
                    scanner.scannedCode = nil
                }
            }
            // UITest hook: when running with --uitesting, expose a hidden button
            // that will inject the scan code from the launch environment.
            .overlay(alignment: .bottomLeading) {
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    Button(action: {
                        if let code = ProcessInfo.processInfo.environment["UITEST_SCAN_CODE"] {
                            DispatchQueue.main.async {
                                scanner.scannedCode = code
                            }
                        }
                    }) {
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("UITestInjectScanButton")
                }
            }
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - QR Scanner Logic
@MainActor
class QRScanner: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var error: String?
    
    let session = AVCaptureSession()
    private var lastScanTime: Date?
    private let scanCooldown: TimeInterval = 2.0
    
    deinit {
        // Perform best-effort synchronous cleanup here to avoid creating weak
        // references to self while it's being deallocated (which can crash).
        if session.isRunning { session.stopRunning() }
        for input in session.inputs { session.removeInput(input) }
        for output in session.outputs { session.removeOutput(output) }
    }
    
    func start() {
        Task { [weak self] in
            await self?.setupCamera()
        }
    }
    
    func stop() {
        Task { [weak self] in
            await self?.cleanup()
        }
    }
    
    private func cleanup() async {
        await Task {
            if session.isRunning {
                session.stopRunning()
            }
            // Remove all inputs and outputs to fully clean up
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
        }.value
    }
    
    private func setupCamera() async {
        // Request camera permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        // UITest simulation: if the tester set `UITEST_SIMULATE_CAMERA_DENIED=1` in the
        // launch environment, simulate a permission denial so we can assert UI guidance
        // without toggling simulator privacy settings.
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           ProcessInfo.processInfo.environment["UITEST_SIMULATE_CAMERA_DENIED"] == "1" {
            error = "Camera access denied. Please enable in Settings."
            return
        }

        let hasAccess: Bool
        if status == .authorized {
            hasAccess = true
        } else {
            hasAccess = await requestCameraAccess()
        }

        guard hasAccess else {
            error = "Camera access denied. Please enable in Settings."
            return
        }
        
        guard let device = AVCaptureDevice.default(for: .video) else {
            error = "No camera available"
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            let output = AVCaptureMetadataOutput()
            
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = [.qr]
            }
            
            let captureSession = session
            DispatchQueue.global(qos: .userInitiated).async {
                captureSession.startRunning()
            }
        } catch {
            self.error = "Camera setup failed: \(error.localizedDescription)"
        }
    }
    
    private func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

// MARK: - Metadata Output Delegate
extension QRScanner: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else {
            return
        }
        
        Task { @MainActor in
            // Prevent duplicate scans
            if let lastScan = lastScanTime,
               Date().timeIntervalSince(lastScan) < scanCooldown {
                return
            }
            
            lastScanTime = Date()
            scannedCode = stringValue
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}
