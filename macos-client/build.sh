#!/bin/bash

set -e

echo "🏗️  Building AWS Transcribe macOS Client..."
echo ""

# Check if Swift is installed
if ! command -v swift &> /dev/null; then
    echo "❌ Error: Swift is not installed"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Print Swift version
echo "Swift version:"
swift --version
echo ""

# Change to project directory
cd "$(dirname "$0")"

# Clean previous builds (optional)
if [ "$1" == "clean" ]; then
    echo "🧹 Cleaning previous builds..."
    swift package clean
    rm -rf .build
    echo "✅ Clean complete"
    echo ""
fi

# Resolve dependencies
echo "📦 Resolving dependencies..."
swift package resolve
echo ""

# Build the project
echo "🔨 Building project..."
swift build -c release
echo ""

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "To run the application:"
    echo "  swift run"
    echo ""
    echo "Or run the binary directly:"
    echo "  .build/release/AWSTranscribeClient"
else
    echo "❌ Build failed"
    exit 1
fi
