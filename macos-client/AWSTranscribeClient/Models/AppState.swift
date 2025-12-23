import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var partialTranscript = ""
    @Published var finalTranscript = ""
    @Published var statusMessage = "Ready"
    @Published var isConfigured = false
    @Published var selectedLanguages: [String] = ["en-US", "zh-CN", "ja-JP"]
    @Published var preferredLanguage = "en-US"
    
    private let keychainService = KeychainService()
    
    init() {
        checkConfiguration()
    }
    
    func checkConfiguration() {
        if let _ = keychainService.getAccessKey(),
           let _ = keychainService.getSecretKey() {
            isConfigured = true
        } else {
            isConfigured = false
        }
    }
    
    func getCredentials() -> (accessKey: String, secretKey: String)? {
        guard let accessKey = keychainService.getAccessKey(),
              let secretKey = keychainService.getSecretKey() else {
            return nil
        }
        return (accessKey, secretKey)
    }
    
    func appendFinalTranscript(_ text: String) {
        if !finalTranscript.isEmpty {
            finalTranscript += " "
        }
        finalTranscript += text
    }
    
    func clearTranscripts() {
        partialTranscript = ""
        finalTranscript = ""
    }
}
