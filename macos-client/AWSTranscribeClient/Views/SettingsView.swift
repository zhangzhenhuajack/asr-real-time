import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var accessKey: String = ""
    @State private var secretKey: String = ""
    @State private var region: String = "us-east-1"
    @State private var showPassword: Bool = false
    @State private var saveStatus: SaveStatus = .none
    
    private let keychainService = KeychainService()
    
    private let regions = [
        "us-east-1",
        "us-east-2",
        "us-west-1",
        "us-west-2",
        "eu-west-1",
        "eu-west-2",
        "eu-central-1",
        "ap-northeast-1",
        "ap-southeast-1",
        "ap-southeast-2"
    ]
    
    enum SaveStatus {
        case none
        case success
        case failure(String)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // AWS Credentials Section
                    GroupBox(label: Text("AWS Credentials").font(.headline)) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Access Key
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Access Key ID")
                                    .font(.system(size: 12, weight: .semibold))
                                
                                TextField("Enter AWS Access Key", text: $accessKey)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            
                            // Secret Key
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Secret Access Key")
                                        .font(.system(size: 12, weight: .semibold))
                                    
                                    Spacer()
                                    
                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                if showPassword {
                                    TextField("Enter AWS Secret Key", text: $secretKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 13, design: .monospaced))
                                } else {
                                    SecureField("Enter AWS Secret Key", text: $secretKey)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 13, design: .monospaced))
                                }
                            }
                            
                            // Region
                            VStack(alignment: .leading, spacing: 6) {
                                Text("AWS Region")
                                    .font(.system(size: 12, weight: .semibold))
                                
                                Picker("", selection: $region) {
                                    ForEach(regions, id: \.self) { region in
                                        Text(region).tag(region)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            
                            // Info
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                
                                Text("Credentials are securely stored in macOS Keychain and never leave your device.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.top, 4)
                        }
                        .padding()
                    }
                    
                    // Language Settings
                    GroupBox(label: Text("Transcription Settings").font(.headline)) {
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Preferred Language")
                                    .font(.system(size: 12, weight: .semibold))
                                
                                Picker("", selection: $appState.preferredLanguage) {
                                    Text("English (US)").tag("en-US")
                                    Text("Chinese (Mandarin)").tag("zh-CN")
                                    Text("Japanese").tag("ja-JP")
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                
                                Text("The application will automatically detect the spoken language, with preference given to your selected language.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding()
                    }
                    
                    // Status Message
                    if case .success = saveStatus {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Credentials saved successfully!")
                                .font(.system(size: 13))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else if case .failure(let message) = saveStatus {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text(message)
                                .font(.system(size: 13))
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: clearCredentials) {
                    Text("Clear Credentials")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Cancel")
                }
                .buttonStyle(.bordered)
                
                Button(action: saveCredentials) {
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                .disabled(accessKey.isEmpty || secretKey.isEmpty)
            }
            .padding()
        }
        .frame(width: 600, height: 600)
        .onAppear(perform: loadCredentials)
    }
    
    private func loadCredentials() {
        if let savedAccessKey = keychainService.getAccessKey() {
            accessKey = savedAccessKey
        }
        
        if let savedSecretKey = keychainService.getSecretKey() {
            secretKey = savedSecretKey
        }
        
        if let savedRegion = keychainService.getRegion() {
            region = savedRegion
        }
    }
    
    private func saveCredentials() {
        let accessKeySuccess = keychainService.saveAccessKey(accessKey)
        let secretKeySuccess = keychainService.saveSecretKey(secretKey)
        let regionSuccess = keychainService.saveRegion(region)
        
        if accessKeySuccess && secretKeySuccess && regionSuccess {
            saveStatus = .success
            appState.checkConfiguration()
            
            // Auto dismiss after 2 seconds on success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            saveStatus = .failure("Failed to save credentials to Keychain")
        }
    }
    
    private func clearCredentials() {
        accessKey = ""
        secretKey = ""
        region = "us-east-1"
        
        _ = keychainService.deleteAllCredentials()
        appState.checkConfiguration()
        
        saveStatus = .none
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
