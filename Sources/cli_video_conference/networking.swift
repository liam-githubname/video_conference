import AVFoundation
import Cocoa
import Network

class VideoReceiver {
  var listener: NWListener?
  var imageView: NSImageView

  init(port: UInt16, imageView: NSImageView) {
    self.imageView = imageView

    do {
      let parameters = NWParameters.tcp
      listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
      print("VideoReceiver initialized on port \(port)")
    } catch {
      print("❌ Failed to create listener: \(error)")
    }
  }

  func start() {
    guard let listener = listener else {
      print("❌ Cannot start: listener is nil")
      return
    }

    listener.stateUpdateHandler = { state in
      switch state {
      case .ready:
        print("✅ Receiver listening on port \(listener.port?.rawValue ?? 0)")
      case .failed(let error):
        print("❌ Listener failed: \(error)")
      default:
        print("Listener state: \(state)")
      }
    }

    listener.newConnectionHandler = { connection in
      print("🎉 Client connected to receiver")
      connection.start(queue: DispatchQueue.global(qos: .userInitiated))
      self.receiveFrames(from: connection)
    }

    listener.start(queue: DispatchQueue.global(qos: .userInitiated))
  }

  private func receiveFrames(from connection: NWConnection) {
    connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { sizeData, _, _, error in
      if let sizeData = sizeData, sizeData.count == 4 {
        let frameSize = sizeData.withUnsafeBytes { $0.load(as: UInt32.self) }

        connection.receive(minimumIncompleteLength: Int(frameSize), maximumLength: Int(frameSize)) {
          frameData, _, _, error in
          if let frameData = frameData {
            print(frameData)
            self.displayFrame(frameData)
          }
          if error == nil {
            self.receiveFrames(from: connection)  // Keep receiving
          }
        }
      }
    }
  }

  private func displayFrame(_ frameData: Data) {
    if let image = NSImage(data: frameData) {
      DispatchQueue.main.async {
        self.imageView.image = image
      }
    }
  }
}

class VideoSender {
  let connection: NWConnection
  let videoCapture = VideoCapture()
  private var isConnected = false

  init(host: String, port: UInt16) {
    connection = NWConnection(
      host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    print("VideoSender initialized targeting \(host):\(port)")
  }

  func start() {
    print("Starting video sender connection...")

    // Set up connection state handling
    connection.stateUpdateHandler = { [weak self] newState in
      guard let self = self else { return }

      switch newState {
      case .ready:
        print("✅ Sender connected to server!")
        self.isConnected = true
        self.startStreaming()
      case .preparing:
        print("Sender preparing connection...")
      case .setup:
        print("Sender connection setup...")
      case .waiting(let error):
        print("⚠️ Sender waiting to connect: \(error)")
      case .failed(let error):
        print("❌ Sender connection failed: \(error)")
        // Try to reconnect after a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
          print("Attempting to reconnect sender...")
          self.connection.restart()
        }
      case .cancelled:
        print("Sender connection cancelled")
      default:
        print("Sender in state: \(newState)")
      }
    }

    // Start the connection
    connection.start(queue: DispatchQueue.global(qos: .userInitiated))
  }

  private func startStreaming() {
    print("Starting video capture and streaming...")

    // Set up the frame callback
    videoCapture.frameCallback = { [weak self] sampleBuffer in
      guard let self = self, self.isConnected else { return }

      if let jpegData = sampleBufferTOJPEGData(sampleBuffer) {
        // Only send frames when connected
        self.sendFrame(jpegData)
      }
    }

    // Start capturing video
    videoCapture.startCapture()
  }

  private func sendFrame(_ frameData: Data) {
    // Send frame size first, then frame data
    let frameSize = UInt32(frameData.count)
    var dataToSend = withUnsafeBytes(of: frameSize) { Data($0) }
    dataToSend.append(frameData)

    self.connection.send(
      content: dataToSend,
      completion: .contentProcessed { error in
        if let error = error {
          print("❌ Send error: \(error)")
        }
      })
  }

  func stop() {
    videoCapture.stopCapture()
    connection.cancel()
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var receiver: VideoReceiver!
  var imageView: NSImageView!
  var isConferenceMode = false
  var videoSender: VideoSender?

  // Add this method to AppDelegate:
  func setupReceiver() {
    // Create ImageView
    imageView = NSImageView(frame: window.contentView?.bounds ?? .zero)
    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.autoresizingMask = [.width, .height]
    window.contentView?.addSubview(imageView)

    // Create and start receiver
    receiver = VideoReceiver(port: 8111, imageView: imageView)
    print("Starting video receiver on port 8111...")
    receiver.start()
  }

  // And update your run() method:
  func run() {
    print("Starting AppDelegate run...")
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    // Create Window
    let initialSize = CGSize(width: 640, height: 480)
    window = NSWindow(
      contentRect: CGRect(origin: .zero, size: initialSize),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.title = "Video Stream"
    window.makeKeyAndOrderFront(nil)

    // Setup receiver before starting app
    setupReceiver()

    // Set delegate and run
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
    window.title = isConferenceMode ? "Video Conference" : "Video Receiver"
    window.makeKeyAndOrderFront(nil)

    // Handle window closing to properly clean up
    // window.delegate = self
  }

  // Implement NSWindowDelegate
  func windowWillClose(_ notification: Notification) {
    // Cleanup resources
    receiver?.listener?.cancel()
    videoSender?.stop()

    // Quit the app when window closes
    NSApp.terminate(nil)
  }

}
