// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AWSTranscribeClient",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AWSTranscribeClient",
            targets: ["AWSTranscribeClient"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "0.35.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "AWSTranscribeClient",
            dependencies: [
                .product(name: "AWSTranscribeStreaming", package: "aws-sdk-swift"),
                .product(name: "AWSClientRuntime", package: "aws-sdk-swift"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms")
            ],
            path: "AWSTranscribeClient"
        )
    ]
)
