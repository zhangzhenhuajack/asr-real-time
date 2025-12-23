# Setup Guide for AWS Transcribe macOS Client

## Quick Start

### 1. Prerequisites

Before you begin, ensure you have:

- **macOS 13.0 or later** (Ventura or newer)
- **Xcode 15.0 or later** installed from the Mac App Store
- **AWS Account** with Transcribe access
- **AWS IAM User** with appropriate permissions

### 2. AWS Setup

#### Create IAM User (if you don't have one)

1. Go to AWS Console → IAM → Users
2. Click "Add users"
3. Enter username (e.g., `transcribe-client-user`)
4. Select "Access key - Programmatic access"
5. Click "Next: Permissions"

#### Attach Permissions

Option A: Use managed policy (simpler)
1. Attach policy: `TranscribeFullAccess`

Option B: Create custom policy (more secure)
1. Click "Create policy"
2. Use JSON editor and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "TranscribeStreamingAccess",
            "Effect": "Allow",
            "Action": [
                "transcribe:StartStreamTranscription"
            ],
            "Resource": "*"
        }
    ]
}
```

3. Name it `TranscribeStreamingOnly`
4. Attach to your user

#### Get Credentials

1. After creating the user, you'll see:
   - **Access Key ID** (e.g., `AKIAIOSFODNN7EXAMPLE`)
   - **Secret Access Key** (e.g., `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`)
2. **Save these securely** - you won't see the secret key again
3. Never commit these to version control

### 3. Build the Application

#### Option A: Using Xcode (Recommended)

1. Open the project:
   ```bash
   cd /projects/sandbox/asr-real-time/macos-client
   open AWSTranscribeClient.xcodeproj
   ```

2. Wait for dependencies to resolve (this may take a few minutes)

3. Select your Mac as the target device

4. Click the Play button or press `Cmd+R`

#### Option B: Using Command Line

1. Navigate to the project:
   ```bash
   cd /projects/sandbox/asr-real-time/macos-client
   ```

2. Build and run:
   ```bash
   ./build.sh
   swift run
   ```

### 4. Configure the Application

#### First Launch

1. The app will show a warning: "⚠️ Configure AWS credentials in Settings"

2. Click the gear icon (⚙️) or press `Cmd+,`

3. Enter your AWS credentials:
   - **Access Key ID**: Paste your AWS access key
   - **Secret Access Key**: Paste your AWS secret key
   - **AWS Region**: Select your preferred region (e.g., `us-east-1`)

4. Choose your preferred language:
   - English (US)
   - Chinese (Mandarin)
   - Japanese

5. Click "Save"

#### Verify Configuration

- The warning message should disappear
- The "Start" button should become enabled
- Status should show "Ready"

### 5. Grant Microphone Permission

#### First Time Audio Capture

1. Click the "Start" button

2. macOS will prompt:
   > "AWS Transcribe Client" would like to access the microphone

3. Click "OK" to allow

4. If you accidentally denied permission:
   - Go to System Preferences → Security & Privacy → Privacy → Microphone
   - Check the box next to "AWS Transcribe Client"
   - Restart the application

### 6. Start Transcribing

1. Click "Start"
2. Speak clearly into your microphone
3. Watch real-time transcriptions appear:
   - Gray/italic text = partial results (in progress)
   - Blue text = final results (confirmed)
4. Click "Stop" when finished
5. Click "Clear" to remove transcriptions

## Advanced Configuration

### Choosing the Right AWS Region

Select a region based on:
- **Proximity**: Closer regions have lower latency
- **Availability**: Ensure Transcribe Streaming is available
- **Compliance**: Some regions may be required for data residency

Recommended regions:
- **North America**: `us-east-1`, `us-west-2`
- **Europe**: `eu-west-1`, `eu-central-1`
- **Asia Pacific**: `ap-northeast-1`, `ap-southeast-1`

### Language Detection

The app supports automatic language detection for:

- English (US) - `en-US`
- Chinese (Mandarin) - `zh-CN`
- Japanese - `ja-JP`
- Hindi - `hi-IN`
- Indonesian - `id-ID`
- Tagalog/Filipino - `tl-PH`
- Russian - `ru-RU`

**Tip**: Set your preferred language in Settings for better accuracy when you primarily speak one language.

### Optimizing Audio Quality

For best transcription results:

1. **Microphone Selection**
   - Use a quality external microphone if available
   - Built-in Mac microphones work but may pick up fan noise

2. **Environment**
   - Minimize background noise
   - Avoid echo-prone rooms
   - Close noisy applications

3. **Speaking Style**
   - Speak clearly at a normal pace
   - Don't speak too fast or too slow
   - Maintain consistent volume

4. **Distance**
   - Position yourself 6-12 inches from the microphone
   - Avoid breathing directly into the microphone

## Security Best Practices

### Credential Management

✅ **DO:**
- Store credentials only in the app's Keychain
- Use IAM users with minimal permissions
- Rotate credentials regularly
- Use different credentials for different apps/purposes

❌ **DON'T:**
- Share your credentials with others
- Commit credentials to version control
- Store credentials in plain text files
- Use root account credentials

### AWS Account Security

1. **Enable MFA** on your AWS root account
2. **Use IAM roles** when possible
3. **Set up CloudTrail** to monitor API usage
4. **Review permissions** regularly
5. **Set up billing alerts** to detect unusual usage

### Monitoring Usage

Track your usage to manage costs:

1. Go to AWS Console → CloudWatch
2. Create a dashboard for Transcribe metrics
3. Set up alarms for:
   - High request rates
   - Unusual error rates
   - Budget thresholds

## Troubleshooting

### Build Issues

**Problem**: Dependencies won't resolve
```
Solution: 
1. Check internet connection
2. Clear package cache: swift package clean
3. Delete .build folder
4. Try again: swift package resolve
```

**Problem**: Xcode won't open project
```
Solution:
1. Ensure Xcode Command Line Tools are installed:
   xcode-select --install
2. Open project file directly:
   open AWSTranscribeClient.xcodeproj
```

### Runtime Issues

**Problem**: "Credentials not found" error
```
Solution:
1. Open Settings (Cmd+,)
2. Re-enter AWS credentials
3. Click Save
4. Restart the app
```

**Problem**: No audio being captured
```
Solution:
1. Check System Preferences → Sound → Input
2. Verify correct microphone is selected
3. Check input level while speaking
4. Grant/re-grant microphone permission
```

**Problem**: Transcription not appearing
```
Solution:
1. Check internet connectivity
2. Verify AWS credentials are correct
3. Check selected region supports Transcribe
4. Review CloudWatch logs for errors
```

### AWS Issues

**Problem**: "Access Denied" errors
```
Solution:
1. Verify IAM user has transcribe:StartStreamTranscription permission
2. Check region is correct
3. Verify credentials haven't expired
```

**Problem**: High latency
```
Solution:
1. Choose a closer AWS region
2. Check internet connection speed
3. Reduce background network usage
4. Consider using AWS Global Accelerator
```

## Cost Estimation

AWS Transcribe Streaming pricing (as of 2024):

- **Standard**: $0.024 per minute
- **Example**: 1 hour of transcription = $1.44

**Tips to reduce costs:**
1. Stop transcription when not speaking
2. Use appropriate audio quality (16kHz is sufficient)
3. Set up billing alerts
4. Monitor usage in CloudWatch

## Development

### Project Structure

```
AWSTranscribeClient/
├── main.swift                    # App entry point
├── Models/
│   └── AppState.swift           # State management
├── Views/
│   ├── ContentView.swift        # Main UI
│   └── SettingsView.swift       # Settings UI
├── Services/
│   ├── AudioCaptureService.swift      # Audio capture
│   └── TranscriptionService.swift     # AWS integration
└── Utilities/
    └── KeychainService.swift    # Credential storage
```

### Extending the Application

Want to add features? Here are some ideas:

1. **Translation** (like the backend)
   - Add AWS Bedrock SDK
   - Create TranslationService
   - Update UI to show translations

2. **Recording**
   - Save audio to files
   - Playback recordings
   - Export transcriptions

3. **Custom Vocabulary**
   - Add vocabulary management
   - Use custom language models
   - Improve domain-specific accuracy

## Getting Help

### Resources

- [AWS Transcribe Documentation](https://docs.aws.amazon.com/transcribe/)
- [AWS SDK for Swift](https://github.com/awslabs/aws-sdk-swift)
- [SwiftUI Documentation](https://developer.apple.com/xcode/swiftui/)

### Common Questions

**Q: Can I use this without an AWS account?**
A: No, you need an AWS account and credentials with Transcribe permissions.

**Q: Is my audio data stored by AWS?**
A: AWS Transcribe Streaming doesn't store your audio data after transcription.

**Q: Can I use this for other languages?**
A: Yes, but you may need to modify the language options in the code.

**Q: Does this work on iOS/iPad?**
A: Not currently, but the code could be adapted with minimal changes.

**Q: Can I use temporary credentials?**
A: Yes, but you'd need to modify the app to handle credential refresh.

## Next Steps

After successful setup:

1. ✅ Test with different languages
2. ✅ Try various speaking styles
3. ✅ Monitor your AWS usage
4. ✅ Customize the UI if desired
5. ✅ Consider adding translation features

## Support

If you encounter issues not covered here:

1. Check the main [README.md](README.md)
2. Review AWS CloudWatch logs
3. Check macOS Console logs (Console.app)
4. Verify AWS service status

Enjoy real-time transcription! 🎤→📝
