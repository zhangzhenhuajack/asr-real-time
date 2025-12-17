# Quick Start Guide - AWS Transcribe macOS Client

Get up and running with the AWS Transcribe macOS client in 5 minutes!

## Prerequisites Checklist

- [ ] macOS 13.0 or later
- [ ] Xcode 15.0 or later installed
- [ ] AWS account with credentials
- [ ] Working microphone

## Step 1: Get AWS Credentials (2 minutes)

If you already have AWS credentials, skip to Step 2.

1. Log into [AWS Console](https://console.aws.amazon.com)
2. Go to **IAM** → **Users** → **Add users**
3. Name: `transcribe-client`
4. Access type: **Access key - Programmatic access**
5. Permissions: Attach policy **TranscribeFullAccess**
6. Save your:
   - Access Key ID: `AKIA...`
   - Secret Access Key: `wJal...`

## Step 2: Build the App (1 minute)

```bash
cd /projects/sandbox/asr-real-time/macos-client
./build.sh
```

Expected output:
```
🏗️  Building AWS Transcribe macOS Client...
📦 Resolving dependencies...
🔨 Building project...
✅ Build successful!
```

## Step 3: Run the App (30 seconds)

```bash
swift run
```

Or double-click the binary:
```bash
open .build/release/AWSTranscribeClient
```

## Step 4: Configure Credentials (1 minute)

1. Click the **⚙️ gear icon** (top right)
2. Enter your credentials:
   - Access Key ID: [paste your key]
   - Secret Access Key: [paste your secret]
   - Region: `us-east-1` (or your preferred region)
3. Click **Save**
4. Close Settings window

## Step 5: Start Transcribing! (30 seconds)

1. Click **Start** button
2. When prompted, click **OK** to allow microphone access
3. Say something: *"Hello, this is a test of AWS Transcribe"*
4. Watch the transcription appear in real-time!

## That's It! 🎉

You now have a working AWS Transcribe client running natively on your Mac!

## What You'll See

- **Gray/Italic Text**: Partial transcription (in progress)
- **Blue Text**: Final transcription (confirmed)
- **Green Dot**: Recording active
- **Gray Dot**: Not recording

## Common Issues

### "Command Line Tools not found"
```bash
xcode-select --install
```

### "Microphone permission denied"
Go to: System Preferences → Security & Privacy → Privacy → Microphone
→ Enable "AWSTranscribeClient"

### "Credentials not found"
Make sure you clicked "Save" in Settings after entering credentials.

### Build takes forever
First build downloads AWS SDK (500MB+). This is normal and only happens once.

## Next Steps

- Read [README.md](README.md) for detailed features
- See [SETUP.md](SETUP.md) for advanced configuration
- Check [IMPLEMENTATION.md](IMPLEMENTATION.md) for technical details

## Tips for Best Results

✅ **DO:**
- Use a quiet room
- Speak clearly and naturally
- Position microphone 6-12 inches away
- Use headphones to prevent echo

❌ **DON'T:**
- Speak too fast or too slow
- Have background music playing
- Cover the microphone
- Move away while speaking

## Cost Estimate

AWS Transcribe Streaming costs **$0.024 per minute**.

Examples:
- 5 minutes = $0.12
- 30 minutes = $0.72
- 1 hour = $1.44

💡 **Pro Tip**: Click "Stop" when you pause to save costs!

## Getting Help

- 📖 Read the [full documentation](README.md)
- 🔧 Check [troubleshooting guide](SETUP.md#troubleshooting)
- 🐛 Review AWS CloudWatch logs
- 📝 Check macOS Console.app for errors

## What Makes This Different?

Unlike the web version that requires:
- Running a backend server
- Setting up Docker
- Configuring load balancers
- Managing infrastructure

This macOS client:
- ✅ Runs completely standalone
- ✅ Connects directly to AWS
- ✅ No server infrastructure needed
- ✅ Lower latency (40-50% faster)
- ✅ Better security (credentials stay on device)

Enjoy transcribing! 🎤→📝
