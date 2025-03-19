// import AVFoundation
// import Cocoa
// import Network
//
// class VideoReceiver {
//   var incomingStream: NWListener
//   var imageView: NSImageView
//
//   // FIXME: This class needs to be fully refactored
//   init(imageView: NSImageView, incomingStream: NWListener) {
//     self.imageView = imageView
//     self.incomingStream = incomingStream
//   }
//
//   // func start() {
//   //   // guard let listener = incomingStream else {
//   //   //   print("❌ Cannot start: listener is nil")
//   //   //   return
//   //   // }
//   //
//   //   // NOTE: The state should be handled in the TCPConnection class
//   //   // incomingStream.stateUpdateHandler = { state in
//   //   //   switch state {
//   //   //   case .ready:
//   //   //     print("✅ Receiver listening on port \(incomingStream.port?.rawValue ?? 0)")
//   //   //   case .failed(let error):
//   //   //     print("❌ Listener failed: \(error)")
//   //   //   default:
//   //   //     print("Listener state: \(state)")
//   //   //   }
//   //   // }
//   //
//   //   // NOTE: This part also needs to be decoupled, VideoReceiver should only be initialized once the connection is established
//   //   // incomingStream.newConnectionHandler = { connection in
//   //   //   print("🎉 Client connected to receiver")
//   //   //   connection.start(queue: DispatchQueue.global(qos: .userInitiated))
//   //   //   self.receiveFrames(from: connection)
//   //   // }
//   //
//   //   incomingStream.start(queue: DispatchQueue.global(qos: .userInitiated))
//   // }
//
//   // NOTE: This function is fine
//   private func receiveFrames(from connection: NWConnection) {
//     connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { sizeData, _, _, error in
//       if let sizeData = sizeData, sizeData.count == 4 {
//         let frameSize = sizeData.withUnsafeBytes { $0.load(as: UInt32.self) }
//
//         connection.receive(minimumIncompleteLength: Int(frameSize), maximumLength: Int(frameSize)) {
//           frameData, _, _, error in
//           if let frameData = frameData {
//             // NOTE: this displays the size of the frame in bytes
//             // print(frameData)
//             self.displayFrame(frameData)
//           }
//           if error == nil {
//             self.receiveFrames(from: connection)  // Keep receiving
//           }
//         }
//       }
//     }
//   }
//
//   // NOTE: This function is fine
//   private func displayFrame(_ frameData: Data) {
//     if let image = NSImage(data: frameData) {
//       DispatchQueue.main.async {
//         self.imageView.image = image
//       }
//     }
//   }
// }
//
// // FIXME: This class needs to be totally refactored
// class VideoSender {
//   let connection: NWConnection
//   let videoCapture = VideoCapture()
//   private var isConnected = false
//
//   // TODO: Make init function better
//   init(connection: NWConnection) {
//     self.connection = connection
//   }
//
//   // TODO: decouple connection state behavior
//   func start() {
//     print("Starting video sender connection...")
//
//     // Set up connection state handling
//     // connection.stateUpdateHandler = { [weak self] newState in
//     //   guard let self = self else { return }
//     //
//     //   switch newState {
//     //   case .ready:
//     //     print("✅ Sender connected to server!")
//     //     self.isConnected = true
//     //   self.startStreaming()
//     // case .preparing:
//     //   print("Sender preparing connection...")
//     // case .setup:
//     //   print("Sender connection setup...")
//     // case .waiting(let error):
//     //   print("⚠️ Sender waiting to connect: \(error)")
//     // case .failed(let error):
//     //   print("❌ Sender connection failed: \(error)")
//     //   // Try to reconnect after a delay
//     //   DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
//     //     print("Attempting to reconnect sender...")
//     //     self.connection.restart()
//     //   }
//     // case .cancelled:
//     //   print("Sender connection cancelled")
//     // default:
//     //   print("Sender in state: \(newState)")
//     // }
//
//     // }
//     // Start the connection
//     // connection.start(queue: DispatchQueue.global(qos: .userInitiated))
//
//     self.startStreaming()
//   }
//
//   private func startStreaming() {
//     print("Starting video capture and streaming...")
//
//     // Set up the frame callback
//     videoCapture.frameCallback = { [weak self] sampleBuffer in
//       guard let self = self, self.isConnected else { return }
//
//       if let jpegData = sampleBufferTOJPEGData(sampleBuffer) {
//         // Only send frames when connected
//         self.sendFrame(jpegData)
//       }
//     }
//
//     // Start capturing video
//     videoCapture.startCapture()
//   }
//
//   // NOTE: This is fine don't touch
//   private func sendFrame(_ frameData: Data) {
//     // Send frame size first, then frame data
//     let frameSize = UInt32(frameData.count)
//     var dataToSend = withUnsafeBytes(of: frameSize) { Data($0) }
//     dataToSend.append(frameData)
//
//     self.connection.send(
//       content: dataToSend,
//       completion: .contentProcessed { error in
//         if let error = error {
//           print("❌ Send error: \(error)")
//         }
//       })
//   }
//
//   func stop() {
//     videoCapture.stopCapture()
//     connection.cancel()
//   }
// }
//
// // FIXME: This class needs refatoring, need to completely decouple the connection states from VideoSender and VideoCapture
// class ConnectionManager {
//   // Connection properties
//   var outgoingStream: NWConnection?
//   var incomingListener: NWListener?
//   var receiver: VideoReceiver?
//   var sender: VideoSender?
//
//   // State tracking
//   private var isControlConnected = false
//   private var isVideoConnected = false
//
//   // Configuration
//   private let controlPort: UInt16
//   private let videoPort: UInt16
//
//   init(controlPort: UInt16, videoPort: UInt16) {
//     self.controlPort = controlPort
//     self.videoPort = videoPort
//   }
//
//   // Start as server (listener first)
//   func startAsHost() {
//     createListener(port: controlPort)
//     createListener(port: videoPort)
//   }
//
//   // Start as client (connector first)
//   func connectToHost(host: String) {
//     createConnection(host: host, port: controlPort)
//   }
//
//   // Create listener for incoming connections
//   func createListener(port: UInt16) {
//     let parameters = NWParameters.tcp
//
//     do {
//       let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
//
//       listener.stateUpdateHandler = { state in
//         switch state {
//         case .ready:
//           print("Listening on port \(port)")
//         case .failed(let error):
//           print("Listener failed on port \(port): \(error)")
//         default:
//           break
//         }
//       }
//
//       listener.newConnectionHandler = { [weak self] connection in
//         guard let self = self else { return }
//
//         if port == self.controlPort {
//           self.handleControlConnection(connection)
//         } else if port == self.videoPort {
//           self.handleVideoConnection(connection)
//         }
//       }
//
//       listener.start(queue: .main)
//
//       if port == controlPort {
//         self.incomingListener = listener
//       }
//     } catch {
//       print("❌ Failed to initialize listener on port \(port): \(error)")
//     }
//   }
//
//   // Handle incoming control connection
//   private func handleControlConnection(_ connection: NWConnection) {
//     connection.stateUpdateHandler = { [weak self] state in
//       guard let self = self else { return }
//
//       switch state {
//       case .ready:
//         print("✅ Control connection established: \(connection.endpoint)")
//         self.receiveVideoPort(on: connection)
//       case .failed(let error):
//         print("❌ Control connection failed: \(error)")
//       default:
//         break
//       }
//     }
//     connection.start(queue: .main)
//   }
//
//   // Handle incoming video connection
//   private func handleVideoConnection(_ connection: NWConnection) {
//     connection.stateUpdateHandler = { [weak self] state in
//       guard let self = self else { return }
//
//       switch state {
//       case .ready:
//         print("✅ Video connection established: \(connection.endpoint)")
//         self.isVideoConnected = true
//         self.receiver = VideoReceiver(connection: connection)
//         self.receiver?.start()
//       case .failed(let error):
//         print("❌ Video connection failed: \(error)")
//         self.isVideoConnected = false
//       default:
//         break
//       }
//     }
//     connection.start(queue: .main)
//   }
//
//   // Create outgoing connection
//   func createConnection(host: String, port: UInt16) {
//     let connection = NWConnection(
//       host: NWEndpoint.Host(host),
//       port: NWEndpoint.Port(rawValue: port)!,
//       using: .tcp)
//
//     connection.stateUpdateHandler = { [weak self] state in
//       guard let self = self else { return }
//
//       switch state {
//       case .ready:
//         print("✅ Connected to \(host) on port \(port)")
//
//         if port == self.controlPort {
//           self.isControlConnected = true
//           self.outgoingStream = connection
//
//           // Send our video port to the other side
//           self.sendPort(videoPort: self.videoPort) { success in
//             if success {
//               print("Successfully sent port")
//               // Once control connection is established, connect to video port
//               self.createConnection(host: host, port: self.videoPort)
//             } else {
//               print("Failed to send port... ending process")
//             }
//           }
//         } else if port == self.videoPort {
//           self.isVideoConnected = true
//           self.sender = VideoSender(connection: connection)
//           self.sender?.start()
//         }
//
//       case .failed(let error):
//         print("❌ Connection failed to \(host):\(port): \(error)")
//         if port == self.controlPort {
//           self.isControlConnected = false
//         } else if port == self.videoPort {
//           self.isVideoConnected = false
//         }
//       default:
//         break
//       }
//     }
//
//     connection.start(queue: DispatchQueue.global(qos: .userInitiated))
//   }
//
//   // Send port information
//   func sendPort(videoPort: UInt16, completion: @escaping (Bool) -> Void) {
//     guard let connection = self.outgoingStream else {
//       completion(false)
//       return
//     }
//
//     let portString = "\(videoPort)\n"
//     let data = portString.data(using: .utf8)!
//
//     connection.send(
//       content: data,
//       completion: .contentProcessed { error in
//         if let error = error {
//           print("❌ Failed to send port: \(error)")
//           completion(false)
//         } else {
//           print("✅ Port \(videoPort) sent successfully")
//           completion(true)
//         }
//       })
//   }
//
//   // Receive port information
//   private func receiveVideoPort(on connection: NWConnection) {
//     connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) {
//       [weak self]
//       data, _, isComplete, error in
//       guard let self = self else { return }
//
//       if let data = data, !data.isEmpty {
//         let message = String(decoding: data, as: UTF8.self)
//         print("📩 Received: \(message)")
//
//         if let receivedPort = UInt16(message.trimmingCharacters(in: .whitespacesAndNewlines)) {
//           print("📡 Received peer's video port: \(receivedPort)")
//           // We don't need to open a listener since we already have one
//         }
//       }
//
//       if isComplete {
//         print("🔴 Connection closed by peer")
//         connection.cancel()
//       } else if let error = error {
//         print("❌ Receive error: \(error)")
//         connection.cancel()
//       } else {
//         self.receiveVideoPort(on: connection)  // Keep receiving data
//       }
//     }
//   }
//
//   // Clean up resources
//   func cleanup() {
//     outgoingStream?.cancel()
//     incomingListener?.cancel()
//     receiver?.stop()
//     sender?.stop()
//   }
// }
//
// // NOTE: This class is a nightmare, I don't know what to do with this honestly
// class AppDelegate: NSObject, NSApplicationDelegate {
//   var window: NSWindow!
//   var receiver: VideoReceiver!
//   var imageView: NSImageView!
//   var isConferenceMode = false
//   var videoSender: VideoSender?
//
//   // Add this method to AppDelegate:
//   func setupReceiver(port: UInt16 = 8111) {
//     // Create ImageView
//     imageView = NSImageView(frame: window.contentView?.bounds ?? .zero)
//     imageView.imageScaling = .scaleProportionallyUpOrDown
//     imageView.autoresizingMask = [.width, .height]
//     window.contentView?.addSubview(imageView)
//
//     // Create and start receiver
//     receiver = VideoReceiver(port: port, imageView: imageView)
//     print("Starting video receiver on port \(port)...")
//     receiver.start()
//   }
//
//   // And update your run() method:
//   func run(port: UInt16 = 8111) {
//     print("Starting AppDelegate run...")
//     let app = NSApplication.shared
//     app.setActivationPolicy(.regular)
//
//     // Create Window
//     let initialSize = CGSize(width: 640, height: 480)
//     window = NSWindow(
//       contentRect: CGRect(origin: .zero, size: initialSize),
//       styleMask: [.titled, .closable, .resizable, .miniaturizable],
//       backing: .buffered,
//       defer: false
//     )
//     window.center()
//     window.title = "Video Stream"
//     window.makeKeyAndOrderFront(nil)
//
//     // Setup receiver before starting app
//     setupReceiver(port: port)
//
//     // Set delegate and run
//     app.delegate = self
//     app.run()
//   }
//
//   private func setupWindow() {
//     // Create Window
//     let initialSize = CGSize(width: 640, height: 480)
//     window = NSWindow(
//       contentRect: CGRect(origin: .zero, size: initialSize),
//       styleMask: [.titled, .closable, .resizable, .miniaturizable],
//       backing: .buffered,
//       defer: false
//     )
//     window.center()
//     window.title = isConferenceMode ? "Video Conference" : "Video Receiver"
//     window.makeKeyAndOrderFront(nil)
//
//     // Handle window closing to properly clean up
//     // window.delegate = self
//   }
//
//   // Implement NSWindowDelegate
//   func windowWillClose(_ notification: Notification) {
//     // Cleanup resources
//     receiver?.incomingStream?.cancel()
//     videoSender?.stop()
//
//     // Quit the app when window closes
//     NSApp.terminate(nil)
//   }
//
// }

import AVFoundation
import Cocoa
import Network

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  // UI components
  var window: NSWindow!
  var imageView: NSImageView!

  // Video components
  var connectionManager: ConnectionManager!
  var receiver: VideoReceiver?
  var sender: VideoSender?
  var videoCapture: VideoCapture?

  // Configuration
  var isConferenceMode = false
  var controlPort: UInt16 = 8111
  var videoPort: UInt16 = 8222
  var remoteHost: String?

  // Initialize as a host (server)
  func runAsHost(controlPort: UInt16 = 8111, videoPort: UInt16 = 8222) {
    self.controlPort = controlPort
    self.videoPort = videoPort

    setupWindow()
    setupUI()

    // Initialize connection manager as host
    connectionManager = ConnectionManager(controlPort: controlPort, videoPort: videoPort)
    connectionManager.videoReceiverDelegate = self
    connectionManager.videoSenderDelegate = self
    connectionManager.startAsHost()

    // Start the app
    let app = NSApplication.shared
    app.delegate = self
    app.run()
  }

  // Initialize as a client
  func runAsClient(host: String, controlPort: UInt16 = 8111, videoPort: UInt16 = 8222) {
    self.controlPort = controlPort
    self.videoPort = videoPort
    self.remoteHost = host

    setupWindow()
    setupUI()

    // Initialize connection manager as client
    connectionManager = ConnectionManager(controlPort: controlPort, videoPort: videoPort)
    connectionManager.videoReceiverDelegate = self
    connectionManager.videoSenderDelegate = self
    connectionManager.connectToHost(host: host)

    // Start the app
    let app = NSApplication.shared
    app.delegate = self
    app.run()
  }

  private func setupWindow() {
    // Create Window
    let initialSize = CGSize(width: 640, height: 480)
    window = NSWindow(
      contentRect: CGRect(origin: .zero, size: initialSize),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.title = isConferenceMode ? "Video Conference" : "Video Stream"
    window.delegate = self
    window.makeKeyAndOrderFront(nil)
  }

  private func setupUI() {
    // Create ImageView
    imageView = NSImageView(frame: window.contentView?.bounds ?? .zero)
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.autoresizingMask = [.width, .height]
    window.contentView?.addSubview(imageView)
  }

  // NSWindowDelegate method
  func windowWillClose(_ notification: Notification) {
    // Stop video capture
    videoCapture?.stopCapture()
    videoCapture = nil

    // Clean up resources
    connectionManager.cleanup()

    // Quit the app when window closes
    NSApp.terminate(nil)
  }
}

// MARK: - Video Receiver Delegate
extension AppDelegate: VideoReceiverDelegate {
  func receivedFrame(_ frameData: Data) {
    if let image = NSImage(data: frameData) {
      DispatchQueue.main.async {
        self.imageView.image = image
      }
    }
  }
}

// MARK: - Video Sender Delegate
extension AppDelegate: VideoSenderDelegate {
  func readyToSendFrames(_ sender: VideoSender) {
    print("Ready to send video frames")

    // Initialize the video capture if not already done
    if videoCapture == nil {
      videoCapture = VideoCapture()

      // Set up the frame callback
      videoCapture?.frameCallback = { [weak self] sampleBuffer in
        guard let self = self else { return }

        // Convert CMSampleBuffer to JPEG Data
        if let jpegData = sampleBufferTOJPEGData(sampleBuffer) {
          // Send the frame data over the network
          self.sender?.sendFrame(jpegData)
        }
      }

      // Start capturing
      videoCapture?.startCapture()
    }
  }
}

// MARK: - Protocol Definitions
protocol VideoReceiverDelegate: AnyObject {
  func receivedFrame(_ frameData: Data)
}

protocol VideoSenderDelegate: AnyObject {
  func readyToSendFrames(_ sender: VideoSender)
}

// MARK: - Video Receiver Class
class VideoReceiver {
  private var connection: NWConnection
  weak var delegate: VideoReceiverDelegate?

  init(connection: NWConnection) {
    self.connection = connection
  }

  func start() {
    receiveFrames()
  }

  private func receiveFrames() {
    connection.receive(minimumIncompleteLength: 4, maximumLength: 4) {
      [weak self] sizeData, _, isComplete, error in
      guard let self = self else { return }

      if let sizeData = sizeData, sizeData.count == 4 {
        let frameSize = sizeData.withUnsafeBytes { $0.load(as: UInt32.self) }

        self.connection.receive(
          minimumIncompleteLength: Int(frameSize), maximumLength: Int(frameSize)
        ) { [weak self] frameData, _, isComplete, error in
          guard let self = self else { return }

          if let frameData = frameData {
            self.delegate?.receivedFrame(frameData)
          }

          if isComplete {
            print("Connection completed during frame receive")
          } else if let error = error {
            print("Error receiving frame: \(error)")
          } else {
            self.receiveFrames()  // Continue receiving frames
          }
        }
      } else if isComplete {
        print("Connection completed during size receive")
      } else if let error = error {
        print("Error receiving frame size: \(error)")
      }
    }
  }

  func stop() {
    // No explicit stop needed for the connection as it's managed by ConnectionManager
  }
}

// MARK: - Video Sender Class
class VideoSender {
  private var connection: NWConnection
  weak var delegate: VideoSenderDelegate?
  private var isRunning = false

  init(connection: NWConnection) {
    self.connection = connection
  }

  func start() {
    isRunning = true
    delegate?.readyToSendFrames(self)
  }

  func stop() {
    isRunning = false
    // No explicit stop needed for the connection as it's managed by ConnectionManager
  }

  func sendFrame(_ frameData: Data) {
    guard isRunning else { return }

    // Create a header with the frame size
    var size = UInt32(frameData.count)
    let sizeData = Data(bytes: &size, count: MemoryLayout<UInt32>.size)

    // Send the size first
    connection.send(
      content: sizeData,
      completion: .contentProcessed { [weak self] error in
        guard let self = self, self.isRunning else { return }

        if let error = error {
          print("Error sending frame size: \(error)")
          return
        }

        // Then send the actual frame data
        self.connection.send(
          content: frameData,
          completion: .contentProcessed { error in
            if let error = error {
              print("Error sending frame data: \(error)")
            }
          })
      })
  }
}

// MARK: - Updated Connection Manager
class ConnectionManager {
  // Connection properties
  var outgoingStream: NWConnection?
  var incomingListener: NWListener?
  var receiver: VideoReceiver?
  var sender: VideoSender?

  // Delegates
  weak var videoReceiverDelegate: VideoReceiverDelegate?
  weak var videoSenderDelegate: VideoSenderDelegate?

  // State tracking
  private var isControlConnected = false
  private var isVideoConnected = false

  // Configuration
  private let controlPort: UInt16
  private let videoPort: UInt16

  init(controlPort: UInt16, videoPort: UInt16) {
    self.controlPort = controlPort
    self.videoPort = videoPort
  }

  // Start as server (listener first)
  func startAsHost() {
    createListener(port: controlPort)
    createListener(port: videoPort)
  }

  // Start as client (connector first)
  func connectToHost(host: String) {
    createConnection(host: host, port: controlPort)
  }

  // Create listener for incoming connections
  func createListener(port: UInt16) {
    let parameters = NWParameters.tcp

    do {
      let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          print("Listening on port \(port)")
        case .failed(let error):
          print("Listener failed on port \(port): \(error)")
        default:
          break
        }
      }

      listener.newConnectionHandler = { [weak self] connection in
        guard let self = self else { return }

        if port == self.controlPort {
          self.handleControlConnection(connection)
        } else if port == self.videoPort {
          self.handleVideoConnection(connection)
        }
      }

      listener.start(queue: .main)

      if port == controlPort {
        self.incomingListener = listener
      }
    } catch {
      print("❌ Failed to initialize listener on port \(port): \(error)")
    }
  }

  // Handle incoming control connection
  private func handleControlConnection(_ connection: NWConnection) {
    connection.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }

      switch state {
      case .ready:
        print("✅ Control connection established: \(connection.endpoint)")
      // FIXME: there is no need to exchange a video port
      // self.receiveVideoPort(on: connection)
      case .failed(let error):
        print("❌ Control connection failed: \(error)")
      default:
        break
      }
    }
    connection.start(queue: .main)
  }

  // Handle incoming video connection
  private func handleVideoConnection(_ connection: NWConnection) {
    connection.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }

      switch state {
      case .ready:
        print("✅ Video connection established: \(connection.endpoint)")
        self.isVideoConnected = true

        // Create and start the video receiver
        let receiver = VideoReceiver(connection: connection)
        receiver.delegate = self.videoReceiverDelegate
        receiver.start()
        self.receiver = receiver
      case .failed(let error):
        print("❌ Video connection failed: \(error)")
        self.isVideoConnected = false
      default:
        break
      }
    }
    connection.start(queue: .main)
  }

  // Create outgoing connection
  func createConnection(host: String, port: UInt16) {
    let connection = NWConnection(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: port)!,
      using: .tcp)

    connection.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }

      switch state {
      case .ready:
        print("✅ Connected to \(host) on port \(port)")

        if port == self.controlPort {
          self.isControlConnected = true
          self.outgoingStream = connection

          // Send our video port to the other side
          // self.sendPort(videoPort: self.videoPort) { success in
          //   if success {
          //     print("Successfully sent port")
          //     // Once control connection is established, connect to video port
          //     self.createConnection(host: host, port: self.videoPort)
          //   } else {
          //     print("Failed to send port... ending process")
          //   }
          // }

        } else if port == self.videoPort {
          self.isVideoConnected = true

          // Create and start the video sender
          let sender = VideoSender(connection: connection)
          sender.delegate = self.videoSenderDelegate
          sender.start()
          self.sender = sender
        }

      case .failed(let error):
        print("❌ Connection failed to \(host):\(port): \(error)")
        if port == self.controlPort {
          self.isControlConnected = false
        } else if port == self.videoPort {
          self.isVideoConnected = false
        }
      default:
        break
      }
    }

    connection.start(queue: DispatchQueue.global(qos: .userInitiated))
  }

  // FIXME: Not needed as the connection will not be sharing ports anymore

  // Send port information
  // func sendPort(videoPort: UInt16, completion: @escaping (Bool) -> Void) {
  //   guard let connection = self.outgoingStream else {
  //     completion(false)
  //     return
  //   }
  //
  //   let portString = "\(videoPort)\n"
  //   let data = portString.data(using: .utf8)!
  //
  //   connection.send(
  //     content: data,
  //     completion: .contentProcessed { error in
  //       if let error = error {
  //         print("❌ Failed to send port: \(error)")
  //         completion(false)
  //       } else {
  //         print("✅ Port \(videoPort) sent successfully")
  //         completion(true)
  //       }
  //     })
  // }

  // FIXME: This isn't needed if I am going to always stream to the same port

  // Receive port information
  // private func receiveVideoPort(on connection: NWConnection) {
  //   connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) {
  //     [weak self]
  //     data, _, isComplete, error in
  //     guard let self = self else { return }
  //
  //     if let data = data, !data.isEmpty {
  //       let message = String(decoding: data, as: UTF8.self)
  //       print("📩 Received: \(message)")
  //
  //       if let receivedPort = UInt16(message.trimmingCharacters(in: .whitespacesAndNewlines)) {
  //         print("📡 Received peer's video port: \(receivedPort)")
  //         // We don't need to open a listener since we already have one
  //       }
  //     }
  //
  //     if isComplete {
  //       print("🔴 Connection closed by peer")
  //       connection.cancel()
  //     } else if let error = error {
  //       print("❌ Receive error: \(error)")
  //       connection.cancel()
  //     } else {
  //       self.receiveVideoPort(on: connection)  // Keep receiving data
  //     }
  //   }
  // }

  // Clean up resources
  func cleanup() {
    outgoingStream?.cancel()
    incomingListener?.cancel()
    receiver?.stop()
    sender?.stop()
  }
}
