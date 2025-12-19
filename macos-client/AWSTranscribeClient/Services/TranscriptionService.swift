import Foundation
import AWSTranscribeStreaming
import AWSClientRuntime
import AsyncAlgorithms

class TranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var errorMessage: String?
    
    private var transcribeClient: TranscribeStreamingClient?
    private var audioStream: AsyncStream<Data>?
    private var audioContinuation: AsyncStream<Data>.Continuation?
    private var transcriptionTask: Task<Void, Never>?
    
    var appState: AppState
    private let keychainService = KeychainService()
    
    init(appState: AppState) {
        self.appState = appState
    }
    
    func initializeClient() async throws {
        guard let accessKey = keychainService.getAccessKey(),
              let secretKey = keychainService.getSecretKey() else {
            throw TranscriptionError.credentialsNotFound
        }
        
        let region = keychainService.getRegion() ?? "us-east-1"
        
        // Create credentials provider
        let credentials = AWSCredentials(
            accessKey: accessKey,
            secret: secretKey
        )
        
        let credentialsProvider = try StaticCredentialsProvider(credentials)
        
        // Create client configuration
        let config = try await TranscribeStreamingClient.TranscribeStreamingClientConfiguration(
            credentialsProvider: credentialsProvider,
            region: region
        )
        
        transcribeClient = TranscribeStreamingClient(config: config)
    }
    
    func startTranscription() async throws {
        if transcribeClient == nil {
            try await initializeClient()
            guard transcribeClient != nil else {
                throw TranscriptionError.clientNotInitialized
            }
        }
        
        isTranscribing = true
        appState.statusMessage = "Starting transcription..."
        
        // Create audio stream
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
        audioStream = stream
        audioContinuation = continuation
        
        transcriptionTask = Task {
            do {
                try await performTranscription()
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isTranscribing = false
                    self.appState.statusMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func performTranscription() async throws {
        guard let client = transcribeClient,
              let audioStream = audioStream else {
            throw TranscriptionError.clientNotInitialized
        }
        
        // Convert Data stream to AWS audio stream
        let awsAudioStream = audioStream.map { data in
            TranscribeStreamingClientTypes.AudioStream.audioevent(
                TranscribeStreamingClientTypes.AudioEvent(audioChunk: data)
            )
        }
        
        // Configure transcription request
        let request = StartStreamTranscriptionInput(
            audioStream: AsyncThrowingStream { continuation in
                Task {
                    for await chunk in awsAudioStream {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                }
            },
            enableChannelIdentification: false,
            identifyLanguage: true,
            languageCode: nil,
            languageOptions: appState.selectedLanguages.joined(separator: ","),
            mediaEncoding: .pcm,
            mediaSampleRateHertz: 16000,
            numberOfChannels: 1,
            preferredLanguage: .init(rawValue: appState.preferredLanguage)
        )
        
        // Start streaming transcription
        let response = try await client.startStreamTranscription(input: request)
        
        await MainActor.run {
            self.appState.statusMessage = "Listening..."
        }
        
        // Process transcription results
        guard let resultStream = response.transcriptResultStream else {
            throw TranscriptionError.transcriptionFailed("No result stream")
        }
        
        for try await event in resultStream {
            await processTranscriptionEvent(event)
        }
    }
    
    private func processTranscriptionEvent(_ event: TranscribeStreamingClientTypes.TranscriptResultStream) async {
        switch event {
        case .transcriptevent(let transcriptEvent):
            guard let results = transcriptEvent.transcript?.results else { return }
            
            for result in results {
                guard let alternatives = result.alternatives,
                      let firstAlternative = alternatives.first,
                      let transcript = firstAlternative.transcript else { continue }
                
                await MainActor.run {
                    if result.isPartial == true {
                        // Partial result
                        self.appState.partialTranscript = transcript
                    } else {
                        // Final result
                        self.appState.appendFinalTranscript(transcript)
                        self.appState.partialTranscript = ""
                        self.appState.statusMessage = "Listening..."
                    }
                }
            }
            
        default:
            // Handle other cases or errors
            await MainActor.run {
                self.errorMessage = "Unknown transcription event"
            }
        }
    }
    
    func sendAudioData(_ data: Data) {
        audioContinuation?.yield(data)
    }
    
    func stopTranscription() {
        audioContinuation?.finish()
        transcriptionTask?.cancel()
        
        isTranscribing = false
        appState.statusMessage = "Stopped"
    }
    
    deinit {
        stopTranscription()
    }
}

enum TranscriptionError: LocalizedError {
    case credentialsNotFound
    case clientNotInitialized
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "AWS credentials not found. Please configure them in Settings."
        case .clientNotInitialized:
            return "Transcription client not initialized."
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}
