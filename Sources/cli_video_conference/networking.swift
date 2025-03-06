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
    } catch {
      fatalError("❌ Failed to create listener: \(error)")
    }
  }

  func start() {
    listener?.newConnectionHandler = { connection in
      print("🎉 Client connected")
      connection.start(queue: .main)
      self.receiveFrames(from: connection)
    }

    listener?.start(queue: .main)
    print("✅ Server listening on port \(listener?.port?.rawValue ?? 0)")

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      if let boundPort = self.listener?.port?.rawValue {
        print("✅ Server is officially listening on port \(boundPort)")
      } else {
        print("❌ Failed to retrieve bound port")
      }
    }
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

  init(host: String, port: UInt16) {
    connection = NWConnection(
      host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .tcp)  // ✅ Switch to TCP
  }

  func start() {
    connection.stateUpdateHandler = { newState in
      switch newState {
      case .ready:
        print("✅ Connected to server!")
        self.startStreaming()
      case .failed(let error):
        print("❌ Connection failed: \(error)")
      default:
        break
      }
    }

    connection.start(queue: .main)
  }

  private func startStreaming() {
    print("in start streaming")
    videoCapture.frameCallback = { sampleBuffer in
      print("In frameCallback")
      if let jpegData = sampleBufferTOJPEGData(sampleBuffer) {
        self.sendFrame(jpegData)
      }
    }
    videoCapture.startCapture()
  }

  private func sendFrame(_ frameData: Data) {
    print("In sendFrame")
    let frameSize = UInt32(frameData.count)
    var dataToSend = withUnsafeBytes(of: frameSize) { Data($0) }  // Send frame size first
    dataToSend.append(frameData)  // Append actual frame data

    connection.send(
      content: dataToSend,
      completion: .contentProcessed { error in
        if let error = error {
          print("❌ Send error: \(error)")
        } else {
          print("📤 Sent frame of size: \(frameData.count) bytes")
        }
      })
  }
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var window: NSWindow!
  var receiver: VideoReceiver!

  func applicationDidFinishLaunching(_ notification: Notification) {
    let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 800, height: 600)

    // Create Window
    window = NSWindow(
      contentRect: CGRect(x: 0, y: 0, width: 640, height: 480),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.center()
    window.title = "Video Stream"
    window.makeKeyAndOrderFront(nil)

    // Create ImageView
    let imageView = NSImageView(frame: CGRect(x: 0, y: 0, width: 640, height: 480))
    imageView.imageScaling = .scaleAxesIndependently
    window.contentView?.addSubview(imageView)

    // Start Video Receiver
    receiver = VideoReceiver(port: 8111, imageView: imageView)
    receiver.start()
  }

  func run() {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
  }
}
