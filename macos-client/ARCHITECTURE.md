# Architecture Documentation

## System Architecture Overview

This document compares the architecture of the web-based solution with the new native macOS client.

## Web-Based Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         User's Browser                               │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  React Frontend (S3 + CloudFront)                             │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ Web Audio API│→ │ Audio Buffer  │→ │  HTTP POST   │       │  │
│  │  │ (Microphone) │  │  (Float32)    │  │  (JSON)      │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────┬────────────────────────────────┘  │
└─────────────────────────────────┼─────────────────────────────────┘
                                  │ HTTP/HTTPS
                                  │ (50-200ms latency)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│              Backend Server (ECS Fargate + ALB)                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Python HTTP Server (streaming_transcribe_server.py)         │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │  JSON Parse  │→ │  PCM Convert │→ │    Queue     │       │  │
│  │  │              │  │  (Int16)     │  │   (Buffer)   │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  │                           ▲                                   │  │
│  │  ┌──────────────────────┐ │ ┌──────────────────────┐         │  │
│  │  │ Bedrock Translation  │ │ │ AWS Credentials      │         │  │
│  │  │ (Claude/Nova)        │ │ │ (IAM Role)           │         │  │
│  │  └──────────────────────┘ │ └──────────────────────┘         │  │
│  └────────────────────────────┼──────────────────────────────────┘  │
└─────────────────────────────────┼─────────────────────────────────┘
                                  │ AWS SDK
                                  │ (boto3)
                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AWS Transcribe Streaming                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ Audio Stream │→ │ Language      │→ │ Transcription│       │  │
│  │  │ Processing   │  │ Detection     │  │ Results      │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

Total Latency: ~210-650ms (Browser → Backend → AWS → Backend → Browser)
Infrastructure: S3, CloudFront, ECS, ALB, Global Accelerator
Cost: Server runtime + data transfer + AWS API calls
```

## macOS Native Client Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    macOS Native Application                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  SwiftUI Interface                                            │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ Settings View│  │ Content View │  │  Status View │       │  │
│  │  │ (Credentials)│  │ (Transcript) │  │  (Controls)  │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Audio Capture Service (AVFoundation)                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ AVAudioEngine│→ │ AVAudioFormat│→ │ PCM Int16    │       │  │
│  │  │ (Microphone) │  │  Converter   │  │ (16kHz mono) │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Transcription Service (AWS SDK for Swift)                   │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ AsyncStream  │→ │ Audio Events │→ │ Stream Client│       │  │
│  │  │  (Buffer)    │  │  (Protocol)  │  │  (AWS SDK)   │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Keychain Service (Security Framework)                       │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ Access Key   │  │ Secret Key   │  │   Region     │       │  │
│  │  │  (Encrypted) │  │  (Encrypted) │  │  (Encrypted) │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ Direct HTTPS
                               │ (10-20ms latency)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AWS Transcribe Streaming                        │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │  │
│  │  │ Audio Stream │→ │ Language      │→ │ Transcription│       │  │
│  │  │ Processing   │  │ Detection     │  │ Results      │       │  │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

Total Latency: ~110-320ms (macOS App → AWS → macOS App)
Infrastructure: None (just the client app)
Cost: AWS API calls only
```

## Component Details

### Audio Capture Layer

#### Web Version
```javascript
// JavaScript Web Audio API
navigator.mediaDevices.getUserMedia({ audio: true })
const audioContext = new AudioContext({ sampleRate: 16000 })
const source = audioContext.createMediaStreamSource(stream)
const processor = audioContext.createScriptProcessor(bufferSize, 1, 1)

processor.onaudioprocess = (e) => {
    const audioData = e.inputBuffer.getChannelData(0) // Float32Array
    sendToBackend(Array.from(audioData)) // Convert to JSON
}
```

**Characteristics:**
- Format: Float32 (-1.0 to 1.0)
- Transport: JSON array over HTTP
- Conversion: Backend converts to PCM
- Latency: ~50-100ms (capture + network)

#### macOS Version
```swift
// Swift AVFoundation
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let format = AVAudioFormat(
    commonFormat: .pcmFormatInt16,
    sampleRate: 16000,
    channels: 1,
    interleaved: false
)

inputNode.installTap(onBus: 0, bufferSize: 1600, format: inputFormat) { buffer, _ in
    let pcmData = convertToPCM(buffer) // Direct Int16 conversion
    sendToAWS(pcmData) // Direct binary transmission
}
```

**Characteristics:**
- Format: PCM Int16 (native)
- Transport: Binary data over HTTPS
- Conversion: None needed (native format)
- Latency: ~10-20ms (capture only)

### AWS Integration Layer

#### Web Version (Backend)
```python
# Python with boto3
import boto3
from amazon_transcribe.client import TranscribeStreamingClient

client = TranscribeStreamingClient(region="us-east-1")

# Credentials from IAM role or environment
async def stream_transcription():
    stream = await client.start_stream_transcription(
        language_code=None,
        identify_language=True,
        media_sample_rate_hz=16000,
        media_encoding="pcm"
    )
    
    # Queue-based buffering
    while True:
        chunk = audio_queue.get()
        await stream.input_stream.send_audio_event(audio_chunk=chunk)
```

**Characteristics:**
- Location: Server-side
- Authentication: IAM role
- Network: Server → AWS
- Cost: Server runtime + API calls

#### macOS Version
```swift
// Swift with AWS SDK
import AWSTranscribeStreaming

let config = try await TranscribeStreamingClient.TranscribeStreamingClientConfiguration(
    awsCredentialIdentityResolver: credentialsProvider,
    region: region
)
let client = TranscribeStreamingClient(config: config)

// AsyncStream-based buffering
let audioStream = AsyncStream<Data> { continuation in
    // Audio data producer
}

let request = StartStreamTranscriptionInput(
    audioStream: awsAudioStream,
    identifyLanguage: true,
    mediaSampleRateHertz: 16000,
    mediaEncoding: .pcm
)

let response = try await client.startStreamTranscription(input: request)
```

**Characteristics:**
- Location: Client-side
- Authentication: User credentials
- Network: Client → AWS (direct)
- Cost: API calls only

### State Management

#### Web Version
```javascript
// React state management
const [transcript, setTranscript] = useState("")
const [isRecording, setIsRecording] = useState(false)

// Polling for updates
setInterval(async () => {
    const response = await fetch('/audio', {
        method: 'POST',
        body: JSON.stringify({ data: audioBuffer })
    })
    const result = await response.json()
    setTranscript(result.transcript)
}, 100) // Poll every 100ms
```

**Characteristics:**
- Update mechanism: HTTP polling
- Latency: Additional 100ms per update
- Overhead: Repeated HTTP requests

#### macOS Version
```swift
// SwiftUI reactive state
class AppState: ObservableObject {
    @Published var partialTranscript = ""
    @Published var finalTranscript = ""
    @Published var isRecording = false
}

// Direct updates
await MainActor.run {
    appState.partialTranscript = text
    // UI updates automatically
}
```

**Characteristics:**
- Update mechanism: Direct property updates
- Latency: Immediate (SwiftUI reactive)
- Overhead: None (in-process)

### Security Layer

#### Web Version
```
User → Frontend (HTTPS) → Backend → AWS
         ↑
    CloudFront SSL

Credentials:
- Stored in: Backend environment/IAM
- Access: Backend has full access
- Security: Depends on backend security
```

#### macOS Version
```
User → macOS App (direct HTTPS) → AWS
         ↑
    Keychain encryption

Credentials:
- Stored in: macOS Keychain
- Access: App-specific, encrypted
- Security: OS-level protection
```

## Performance Comparison

### Latency Breakdown

| Stage                  | Web Version | macOS Version | Difference |
|------------------------|-------------|---------------|------------|
| Audio Capture          | 50-100ms    | 10-20ms       | -70%       |
| Format Conversion      | 10-50ms     | 0ms           | -100%      |
| Network to Backend     | 50-200ms    | 0ms           | -100%      |
| Backend Processing     | 10-50ms     | 0ms           | -100%      |
| Network to AWS         | 50-200ms    | 50-200ms      | 0%         |
| AWS Processing         | 100-300ms   | 100-300ms     | 0%         |
| **Total**              | **270-900ms** | **160-520ms** | **-40-42%** |

### Resource Usage

| Resource               | Web Version | macOS Version | Difference |
|------------------------|-------------|---------------|------------|
| Client Memory          | 100-200 MB  | 30-50 MB      | -70-75%    |
| Server Memory          | 50-100 MB   | 0 MB          | -100%      |
| Network Bandwidth      | 2x (duplex) | 1x (simplex)  | -50%       |
| Infrastructure Needed  | 5 services  | 0 services    | -100%      |

### Cost Comparison (Monthly)

**Web Version:**
- ECS Fargate: ~$30-50/month (always running)
- ALB: ~$20-30/month
- Global Accelerator: ~$20/month (optional)
- Data Transfer: ~$10-20/month
- S3/CloudFront: ~$5-10/month
- Transcribe API: $0.024/minute (variable)
- **Total Infrastructure: ~$85-130/month + API costs**

**macOS Version:**
- Infrastructure: $0/month
- Transcribe API: $0.024/minute (variable)
- **Total: API costs only**

**Savings: ~$85-130/month in infrastructure costs**

## Scalability Considerations

### Web Version
✅ Scales horizontally (add more backend servers)
✅ Centralized monitoring and logging
✅ Can implement rate limiting
✅ Can cache/optimize requests
❌ Backend bottleneck for many users
❌ Infrastructure complexity
❌ Higher operational overhead

### macOS Version
✅ Perfect scalability (each client independent)
✅ No backend bottleneck
✅ No infrastructure to manage
❌ No centralized monitoring
❌ Each client needs credentials
❌ Harder to implement cross-user features

## Use Case Recommendations

### Use Web Version When:
- Need centralized control
- Want to hide AWS credentials from users
- Need shared state across users
- Require centralized logging/monitoring
- Want to implement translation (already integrated)
- Need to support multiple platforms (Windows, Linux, etc.)

### Use macOS Version When:
- Single user application
- Want lowest latency
- Need offline configuration
- Don't want to manage infrastructure
- macOS-only deployment is acceptable
- Security is paramount (credentials never leave device)
- Want to minimize costs

## Migration Path

To migrate from web to macOS (or vice versa):

### Web → macOS
1. Extract audio capture logic
2. Implement native audio capture
3. Port transcription integration
4. Add credential management
5. Build UI in SwiftUI
6. Test with same AWS credentials

### macOS → Web
1. Create backend server
2. Implement audio relay
3. Add HTTP API endpoints
4. Build web frontend
5. Deploy infrastructure
6. Configure IAM roles

## Conclusion

Both architectures are valid and serve different use cases:

- **Web Version**: Best for multi-platform, centralized control
- **macOS Version**: Best for native experience, low latency, minimal infrastructure

Choose based on your specific requirements for latency, cost, security, and deployment complexity.
