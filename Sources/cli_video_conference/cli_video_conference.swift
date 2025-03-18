import AVFoundation
import Cocoa
import Foundation
import Network

// self explanatory
enum Command: String {
  case help = "help"
  case list = "list"
  case preview = "preview"
  case conference = "conference"
  case sender = "sender"
  case receiver = "receiver"
  case test = "test"
}

// main app class
@available(macOS 10.15, *)
@MainActor  // Ensure all UI-related code runs on the main thread
class CameraStreamCLI {

  // command options
  private var deviceId: String?
  private var outputPath: String?
  private var shouldExit = false

  func run() {
    parseArguments()
  }

  private func parseArguments() {
    let arguments = CommandLine.arguments

    guard arguments.count > 1 else {
      printUsage()
      exit(1)
    }

    guard let command = Command(rawValue: arguments[1]) else {
      print("Error: Unknown command '\(arguments[1])'")
      printUsage()
      exit(1)
    }

    // handles the passed arguments
    switch command {
    case .list:
      doListCameras()

    case .help:
      printUsage()
      exit(0)

    case .preview:
      let cameraPreviewController = CameraPreviewController()
      cameraPreviewController.run()

    case .conference:

      if CommandLine.arguments[2] == "-h" {
        // Run as host (server)
        let appDelegate = AppDelegate()
        appDelegate.isConferenceMode = true  // Set to true for bidirectional video
        appDelegate.runAsHost(controlPort: 8112, videoPort: 8223)
      }

      if CommandLine.arguments[2] == "-c" {
        // Run as client
        let appDelegate = AppDelegate()
        appDelegate.isConferenceMode = true
        appDelegate.runAsClient(host: "192.168.1.206", controlPort: 8111, videoPort: 8222)
      }

    case .sender:

      guard arguments.count > 2 else {
        print("Usage: \(arguments[1]) <ip_address>")
        exit(1)
      }

      let host = arguments[2]

    // let tcpsocket = TCPConnection.init(host: host, port: 8111)

    // let sender = VideoSender(connection: tcpsocket.connection)
    // sender.start()
    // dispatchMain()  // Ensures the CLI keeps running

    case .receiver:

      break
    case .test:
      // Run main app loop
      break

    }

  }

  private func printUsage() {
    print(
      """
      Usage: camera-cli <command> [options]

      Commands:
        list                List available camera devices
        capture             Capture an image from a camera
        help                Display this help message

      Capture Options:
        --device <id>       Specify the device ID to use (default: first available camera)
        --output <path>     Specify the output file path (required)
        --format <format>   Output format: jpeg or png (default: jpeg)

      Examples:
        camera-cli list
        camera-cli capture --output image.jpg
        camera-cli capture --device 0x1400000046d81a12 --output image.png --format png
      """)
  }

  private func buildDiscoverySession() -> AVCaptureDevice.DiscoverySession {
    if #available(macOS 14.0, *) {
      let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .external, .externalUnknown],
        mediaType: .video,
        position: .unspecified
      )
      return discoverySession
    } else {
      let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
        mediaType: .video,
        position: .unspecified
      )

      return discoverySession
    }
  }

  private func doListCameras() {
    let discoverySession = buildDiscoverySession()

    let devices = discoverySession.devices

    if devices.isEmpty {
      print("No camera devices found")
    } else {
      print("Available Camera Devices:")
      print("-------------------------")

      for (index, device) in devices.enumerated() {
        print("\(index + 1). \(device.localizedName)")
        print("  ID: \(device.uniqueID)")
        print("  Model: \(device.modelID)")
        print("  Position: \(positionString(for: device.position))")

        if let formatDescriptions = device.formats as? [AVCaptureDevice.Format] {
          print("   Supported Formats: \(formatDescriptions.count)")

          let sampleFormats = formatDescriptions.prefix(3)
          for (formatIndex, format) in sampleFormats.enumerated() {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let maxFrameRate = format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 0

            print(
              "      Format \(formatIndex + 1): \(dimensions.width)x\(dimensions.height) @ \(maxFrameRate) fps"
            )
          }

          if formatDescriptions.count > 3 {
            print("      ... and \(formatDescriptions.count - 3) more formats")
          }
        }
        print("")
      }
    }
    shouldExit = true
  }

  private func positionString(for position: AVCaptureDevice.Position) -> String {
    switch position {
    case .front:
      return "Front"
    case .back:
      return "Back"
    case .unspecified:
      return "Unspecified"
    @unknown default:
      return "Unknown"
    }
  }
}

@main  // Marks this struct as the entry point for the executable
struct CLIApp {
  static func main() {
    if #available(macOS 10.15, *) {
      let cli = CameraStreamCLI()
      cli.run()
    } else {
      print("Error: macOS 10.15^ is required")

    }
  }
}
