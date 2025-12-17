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
            accessKeyId: accessKey,
            secretAccessKey: secretKey
        )
        
        let credentialsProvider = try StaticCredentialsProvider(credentials)
        
        // Create client configuration
        let config = try await TranscribeStreamingClient.TranscribeStreamingClientConfiguration(
            awsCredentialIdentityResolver: credentialsProvider,
            region: region
        )
        
        transcribeClient = TranscribeStreamingClient(config: config)
    }
    
    func startTranscription(audioDataHandler: @escaping (Data) -> Void) async throws {
        guard let client = transcribeClient else {
            try await initializeClient()
            guard let client = transcribeClient else {
                throw TranscriptionError.clientNotInitialized
            }
        }
        
        // Create audio stream
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
        audioStream = stream
        audioContinuation = continuation
        
        isTranscribing = true
        
        // Start transcription task
        transcriptionTask = Task {
            await performTranscription(client: client, audioStream: stream, audioDataHandler: audioDataHandler)
        }
    }
    
    private func performTranscription(
        client: TranscribeStreamingClient,
        audioStream: AsyncStream<Data>,
        audioDataHandler: @escaping (Data) -> Void
    ) async {
        do {
            // Create audio stream for AWS
            let awsAudioStream = AsyncStream<TranscribeStreamingClientTypes.AudioStream> { continuation in
                Task {
                    for await audioData in audioStream {
                        let audioEvent = TranscribeStreamingClientTypes.AudioStream.audioevent(
                            TranscribeStreamingClientTypes.AudioEvent(audioChunk: audioData)
                        )
                        continuation.yield(audioEvent)
                    }
                    continuation.finish()
                }
            }
            
            // Configure transcription request
            let request = StartStreamTranscriptionInput(
                audioStream: awsAudioStream,
                enableChannelIdentification: false,
                languageCode: nil, // Auto-detect
                identifyLanguage: true,
                languageOptions: appState.selectedLanguages,
                mediaSampleRateHertz: 16000,
                mediaEncoding: .pcm,
                numberOfChannels: 1,
                preferredLanguage: .init(rawValue: appState.preferredLanguage)
            )
            
            // Start streaming transcription
            let response = try await client.startStreamTranscription(input: request)
            
            // Process transcription results
            if let transcriptResultStream = response.transcriptResultStream {
                for try await event in transcriptResultStream {
                    await handleTranscriptEvent(event)
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Transcription error: \(error.localizedDescription)"
                self.appState.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleTranscriptEvent(_ event: TranscribeStreamingClientTypes.TranscriptResultStream) async {
        switch event {
        case .transcriptevent(let transcriptEvent):
            guard let results = transcriptEvent.transcript?.results else { return }
            
            for result in results {
                guard let alternatives = result.alternatives, !alternatives.isEmpty else { continue }
                
                if let transcript = alternatives[0].transcript {
                    await MainActor.run {
                        if result.isPartial {
                            // Partial result
                            self.appState.partialTranscript = transcript
                            self.appState.statusMessage = "Transcribing..."
                        } else {
                            // Final result
                            self.appState.appendFinalTranscript(transcript)
                            self.appState.partialTranscript = ""
                            self.appState.statusMessage = "Listening..."
                        }
                    }
                }
            }
            
        case .badrequestevent(let badRequest):
            await MainActor.run {
                self.errorMessage = "Bad request: \(badRequest.message ?? "Unknown error")"
            }
            
        case .conflictexception(let conflict):
            await MainActor.run {
                self.errorMessage = "Conflict: \(conflict.message ?? "Unknown error")"
            }
            
        case .internalfailureexception(let failure):
            await MainActor.run {
                self.errorMessage = "Internal failure: \(failure.message ?? "Unknown error")"
            }
            
        case .limitexceededexception(let limit):
            await MainActor.run {
                self.errorMessage = "Limit exceeded: \(limit.message ?? "Unknown error")"
            }
            
        case .serviceunavailableexception(let unavailable):
            await MainActor.run {
                self.errorMessage = "Service unavailable: \(unavailable.message ?? "Unknown error")"
            }
            
        default:
            break
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
    case streamCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .credentialsNotFound:
            return "AWS credentials not found. Please configure them in Settings."
        case .clientNotInitialized:
            return "Transcription client not initialized"
        case .streamCreationFailed:
            return "Failed to create audio stream"
        }
    }
}
