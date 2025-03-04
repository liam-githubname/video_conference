// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "cli_video_conference",
  products: [
    // Define only the executable product.
    .executable(
      name: "cli_video_conference",
      targets: ["cli_video_conference"])
  ],
  targets: [
    // Use executableTarget instead of target for the main program logic.
    .executableTarget(
      name: "cli_video_conference"),
    .testTarget(
      name: "cli_video_conferenceTests",
      dependencies: ["cli_video_conference"]
    ),
  ]
)
