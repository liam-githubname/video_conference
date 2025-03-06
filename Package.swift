// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "cli_video_conference",
  platforms: [
    .macOS(.v10_15)  // Set minimum macOS version for the entire package
  ],
  products: [
    // Define the executable product.
    .executable(
      name: "cli_video_conference",
      targets: ["cli_video_conference"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/stasel/WebRTC.git", .upToNextMajor(from: "134.0.0"))
  ],
  targets: [
    // Main program logic target.
    .executableTarget(
      name: "cli_video_conference",
      dependencies: [
        "WebRTC"
      ],
      path: "Sources/cli_video_conference",
      swiftSettings: [
        .define("MACOS_10_15", .when(platforms: [.macOS]))  // Specify macOS 10.15 as minimum deployment target
      ]
    ),

    .testTarget(
      name: "cli_video_conferenceTests",
      dependencies: ["cli_video_conference"]
    ),
  ])
