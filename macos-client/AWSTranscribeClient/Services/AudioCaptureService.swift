import Foundation
import AVFoundation
import Combine

class AudioCaptureService: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFormat: AVAudioFormat?
    
    @Published var isCapturing = false
    @Published var errorMessage: String?
    
    var audioDataHandler: ((Data) -> Void)?
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Request microphone permission
            #if os(macOS)
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            if status != .authorized {
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    if !granted {
                        DispatchQueue.main.async {
                            self.errorMessage = "Microphone access denied. Please enable it in System Preferences."
                        }
                    }
                }
            }
            #endif
        }
    }
    
    func startCapture() throws {
        audioEngine = AVAudioEngine()
        
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineInitializationFailed
        }
        
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else {
            throw AudioCaptureError.inputNodeNotFound
        }
        
        // AWS Transcribe requires: PCM, 16kHz, 16-bit, mono
        let desiredSampleRate: Double = 16000
        let desiredChannelCount: AVAudioChannelCount = 1
        
        audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: desiredSampleRate,
            channels: desiredChannelCount,
            interleaved: false
        )
        
        guard let audioFormat = audioFormat else {
            throw AudioCaptureError.formatCreationFailed
        }
        
        // Get input format and convert if needed
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create a converter if the input format doesn't match what we need
        let converter = AVAudioConverter(from: inputFormat, to: audioFormat)
        
        guard converter != nil else {
            throw AudioCaptureError.converterCreationFailed
        }
        
        // Buffer size for ~100ms chunks (1600 frames at 16kHz)
        let bufferSize: AVAudioFrameCount = 1600
        
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, let converter = converter else { return }
            
            // Convert to target format
            self.convertAndSendAudio(buffer: buffer, converter: converter, outputFormat: audioFormat)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        isCapturing = true
        errorMessage = nil
    }
    
    private func convertAndSendAudio(buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        // Calculate output buffer size
        let inputFrameCount = buffer.frameLength
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(inputFrameCount) * ratio)
        
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
            return
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("Audio conversion error: \(error)")
            return
        }
        
        // Convert to Data (raw PCM bytes)
        if let channelData = outputBuffer.int16ChannelData {
            let channelDataPointer = channelData.pointee
            let frameLength = Int(outputBuffer.frameLength)
            let data = Data(bytes: channelDataPointer, count: frameLength * MemoryLayout<Int16>.size)
            
            audioDataHandler?(data)
        }
    }
    
    func stopCapture() {
        guard let audioEngine = audioEngine, let inputNode = inputNode else { return }
        
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        
        self.audioEngine = nil
        self.inputNode = nil
        
        isCapturing = false
    }
    
    deinit {
        stopCapture()
    }
}

enum AudioCaptureError: LocalizedError {
    case engineInitializationFailed
    case inputNodeNotFound
    case formatCreationFailed
    case converterCreationFailed
    case microphonePermissionDenied
    
    var errorDescription: String? {
        switch self {
        case .engineInitializationFailed:
            return "Failed to initialize audio engine"
        case .inputNodeNotFound:
            return "Audio input node not found"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .microphonePermissionDenied:
            return "Microphone permission denied"
        }
    }
}
