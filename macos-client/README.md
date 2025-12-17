# AWS Transcribe macOS Client

A native macOS application that provides real-time speech transcription using AWS Transcribe Streaming API, without requiring any backend server.

## Features

✅ **Direct AWS Integration** - Connects directly to AWS Transcribe Streaming service
✅ **Real-time Transcription** - Live audio transcription as you speak
✅ **Auto Language Detection** - Automatically detects spoken language
✅ **Secure Credential Storage** - AWS credentials stored in macOS Keychain
✅ **No Backend Required** - Runs completely standalone on your Mac
✅ **Native macOS UI** - Built with SwiftUI for a native look and feel
✅ **Multi-language Support** - Supports English, Chinese, Japanese, and more

## Architecture

### Components

1. **Main Application** (`main.swift`)
   - SwiftUI-based application entry point
   - Manages app lifecycle and window management

2. **Views**
   - `ContentView.swift` - Main transcription interface
   - `SettingsView.swift` - AWS credentials configuration

3. **Services**
   - `TranscriptionService.swift` - AWS Transcribe integration
   - `AudioCaptureService.swift` - Microphone audio capture and processing

4. **Models**
   - `AppState.swift` - Application state management

5. **Utilities**
   - `KeychainService.swift` - Secure credential storage using macOS Keychain

### Technical Implementation

#### Audio Capture
- Uses `AVAudioEngine` to capture audio from the microphone
- Converts audio to PCM format (16kHz, 16-bit, mono) as required by AWS Transcribe
- Processes audio in ~100ms chunks for real-time streaming

#### AWS Integration
- Uses AWS SDK for Swift (`aws-sdk-swift`)
- Implements streaming transcription with `TranscribeStreamingClient`
- Handles both partial and final transcription results
- Supports automatic language detection with configurable language preferences

#### Security
- Credentials stored securely in macOS Keychain
- Never transmitted except directly to AWS services
- Uses secure SecItem APIs for credential management

## Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- AWS account with Transcribe permissions
- Microphone access permission

## Building the Application

### Using Xcode

1. Open the project in Xcode:
   ```bash
   cd /projects/sandbox/asr-real-time/macos-client
   open AWSTranscribeClient.xcodeproj
   ```

2. Wait for Swift Package Manager to resolve dependencies

3. Select your target Mac and build/run

### Using Swift Package Manager (Command Line)

1. Build the project:
   ```bash
   cd /projects/sandbox/asr-real-time/macos-client
   swift build
   ```

2. Run the application:
   ```bash
   swift run
   ```

## Configuration

### AWS Credentials Setup

1. Launch the application
2. Open Settings (gear icon or Cmd+,)
3. Enter your AWS credentials:
   - **Access Key ID**: Your AWS access key
   - **Secret Access Key**: Your AWS secret key
   - **Region**: AWS region (default: us-east-1)
4. Click "Save"

### Required AWS Permissions

Your AWS credentials need the following permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "transcribe:StartStreamTranscription"
            ],
            "Resource": "*"
        }
    ]
}
```

## Usage

1. **Configure AWS Credentials** (first time only)
   - Click the settings icon
   - Enter your AWS Access Key and Secret Key
   - Select your preferred AWS region
   - Click Save

2. **Start Transcription**
   - Click the "Start" button
   - Grant microphone permission when prompted
   - Begin speaking

3. **View Results**
   - Partial transcriptions appear in gray (real-time)
   - Final transcriptions appear in blue (confirmed)
   - Transcriptions accumulate as you speak

4. **Stop Transcription**
   - Click the "Stop" button
   - Transcriptions remain visible

5. **Clear Transcriptions**
   - Click the "Clear" button to remove all transcriptions

## Supported Languages

The application automatically detects the following languages:

- 🇺🇸 English (US) - `en-US`
- 🇨🇳 Chinese (Mandarin) - `zh-CN`
- 🇯🇵 Japanese - `ja-JP`
- 🇮🇳 Hindi - `hi-IN`
- 🇮🇩 Indonesian - `id-ID`
- 🇵🇭 Tagalog/Filipino - `tl-PH`
- 🇷🇺 Russian - `ru-RU`

You can set a preferred language in Settings for better accuracy when multiple languages are detected.

## Project Structure

```
macos-client/
├── Package.swift                           # Swift Package Manager configuration
├── README.md                               # This file
├── AWSTranscribeClient.xcodeproj/         # Xcode project
└── AWSTranscribeClient/
    ├── main.swift                          # Application entry point
    ├── Info.plist                          # App configuration
    ├── Models/
    │   └── AppState.swift                  # Application state
    ├── Views/
    │   ├── ContentView.swift               # Main UI
    │   └── SettingsView.swift              # Settings UI
    ├── Services/
    │   ├── AudioCaptureService.swift       # Audio capture
    │   └── TranscriptionService.swift      # AWS Transcribe integration
    └── Utilities/
        └── KeychainService.swift           # Keychain management
```

## Dependencies

- [AWS SDK for Swift](https://github.com/awslabs/aws-sdk-swift) - Official AWS SDK
  - `AWSTranscribeStreaming` - Transcribe streaming client
  - `AWSClientRuntime` - AWS client runtime
- [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) - Async sequence utilities

## Comparison with Backend Implementation

### Backend (`streaming_transcribe_server.py`)

The Python backend implementation uses:
- `amazon-transcribe` library for streaming
- HTTP server to relay audio from frontend
- WebSocket for potential real-time updates
- Queue-based audio buffering
- Manual PCM conversion

### macOS Client (This Implementation)

The macOS client directly implements:
- Native Swift AWS SDK integration
- Direct audio capture from microphone
- Native AVFoundation for audio processing
- SwiftUI for native macOS interface
- Secure Keychain credential storage
- No intermediate server required

### Key Advantages

1. **Lower Latency** - Direct connection to AWS without intermediate server
2. **Better Security** - Credentials never leave the device
3. **Offline Operation** - No backend infrastructure needed
4. **Native Performance** - Native audio processing and UI
5. **Cost Effective** - No server hosting costs

## Troubleshooting

### Microphone Not Working

1. Check System Preferences → Security & Privacy → Privacy → Microphone
2. Ensure the app has microphone permission
3. Restart the application after granting permission

### Transcription Not Starting

1. Verify AWS credentials are configured correctly
2. Check internet connectivity
3. Ensure the selected region supports Transcribe Streaming
4. Check CloudWatch logs for AWS errors

### Audio Quality Issues

1. Use a good quality microphone
2. Reduce background noise
3. Speak clearly at a normal pace
4. Ensure microphone is not muted or too far away

### Build Errors

1. Ensure you have the latest Xcode version
2. Clean build folder: Product → Clean Build Folder
3. Delete derived data
4. Reset package cache: File → Packages → Reset Package Caches

## Development

### Code Organization

- **Views**: SwiftUI views for the user interface
- **Models**: Data models and application state
- **Services**: Business logic and external service integration
- **Utilities**: Helper classes and utilities

### Adding New Features

To add translation capabilities (like the backend):
1. Add AWS Bedrock SDK dependency
2. Create `TranslationService.swift`
3. Update UI to show translations
4. Add language selection controls

### Testing

Run tests using:
```bash
swift test
```

## Performance Considerations

- Audio is processed in 100ms chunks for optimal real-time performance
- Audio format conversion happens in-memory
- Transcription results are processed asynchronously
- Keychain operations are cached to minimize lookups

## Security Best Practices

1. **Never hardcode credentials** - Always use Keychain
2. **Validate user input** - Especially AWS credentials
3. **Use HTTPS only** - AWS SDK uses secure connections
4. **Minimal permissions** - Request only necessary AWS permissions
5. **Clear sensitive data** - Properly dispose of credentials

## Future Enhancements

- [ ] Translation integration (similar to backend)
- [ ] Multiple language detection improvements
- [ ] Audio recording and playback
- [ ] Export transcriptions to various formats
- [ ] Custom vocabulary support
- [ ] Speaker diarization
- [ ] Custom language models
- [ ] Batch transcription support

## License

MIT License - See the main repository README for details

## Support

For issues specific to the macOS client, please check:
1. This README's troubleshooting section
2. macOS Console logs (Console.app)
3. AWS CloudWatch logs for service errors

For AWS Transcribe API issues, refer to [AWS Transcribe Documentation](https://docs.aws.amazon.com/transcribe/).
