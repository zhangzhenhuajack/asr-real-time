import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioCaptureService = AudioCaptureService()
    @StateObject private var transcriptionService: TranscriptionService
    
    @State private var showSettings = false
    @State private var errorAlert: String?
    @State private var showErrorAlert = false
    
    init() {
        // Initialize with a temporary appState, will be replaced by @EnvironmentObject
        let tempState = AppState()
        _transcriptionService = StateObject(wrappedValue: TranscriptionService(appState: tempState))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("AWS Transcribe Client")
                    .font(.system(size: 28, weight: .bold))
                
                Spacer()
                
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding()
            
            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(appState.statusMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !appState.isConfigured {
                    Text("⚠️ Configure AWS credentials in Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal)
            
            // Transcription Display
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !appState.finalTranscript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Final Transcription")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text(appState.finalTranscript)
                                .font(.system(size: 16))
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    if !appState.partialTranscript.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Partial Transcription")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Text(appState.partialTranscript)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .italic()
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    if appState.finalTranscript.isEmpty && appState.partialTranscript.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "mic.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Press Start to begin transcription")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(40)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Controls
            HStack(spacing: 16) {
                Button(action: startRecording) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Start")
                    }
                    .frame(width: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isRecording || !appState.isConfigured)
                
                Button(action: stopRecording) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(width: 120)
                }
                .buttonStyle(.bordered)
                .disabled(!appState.isRecording)
                
                Spacer()
                
                Button(action: clearTranscripts) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(appState.finalTranscript.isEmpty && appState.partialTranscript.isEmpty)
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorAlert ?? "Unknown error")
        }
        .onAppear {
            // Update transcription service with the correct appState
            transcriptionService.appState = appState
        }
    }
    
    private var statusColor: Color {
        if appState.isRecording {
            return .green
        } else {
            return .gray
        }
    }
    
    private func startRecording() {
        appState.isRecording = true
        appState.statusMessage = "Starting..."
        
        // Setup audio data handler
        audioCaptureService.audioDataHandler = { audioData in
            transcriptionService.sendAudioData(audioData)
        }
        
        Task {
            do {
                // Initialize transcription service
                try await transcriptionService.initializeClient()
                
                // Start transcription
                try await transcriptionService.startTranscription { _ in }
                
                // Start audio capture
                try audioCaptureService.startCapture()
                
                await MainActor.run {
                    appState.statusMessage = "Listening..."
                }
            } catch {
                await MainActor.run {
                    appState.isRecording = false
                    appState.statusMessage = "Error"
                    errorAlert = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func stopRecording() {
        audioCaptureService.stopCapture()
        transcriptionService.stopTranscription()
        
        appState.isRecording = false
        appState.statusMessage = "Stopped"
    }
    
    private func clearTranscripts() {
        appState.clearTranscripts()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
