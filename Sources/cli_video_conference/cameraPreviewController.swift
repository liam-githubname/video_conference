import AVFoundation
import Cocoa

// ------------------------------------------------------------------------------------------
// Controller for managing camera preview
// An NSObject is the root class of most objc heirarchies, but its the basic interace to the runtime system
@MainActor
class CameraPreviewController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate,
  NSWindowDelegate
{
  private var captureSession: AVCaptureSession?  // Manages the camera input/output session
  private var previewLayer: AVCaptureVideoPreviewLayer?  // Layer to display the camera feed
  private var window: NSWindow?  // Window to display the preview

  // Starts the camera preview
  func startCameraPreview() -> Bool {
    let session = AVCaptureSession()  // Create a new camera session
    session.sessionPreset = .high  // Set resolution quality

    // Attempt to get the default video camera device
    guard let videoDevice = AVCaptureDevice.default(for: .video) else {
      print("Error: No video device available")
      return false
    }

    do {
      // Create a video input from the camera
      let deviceInput = try AVCaptureDeviceInput(device: videoDevice)
      if session.canAddInput(deviceInput) {
        session.addInput(deviceInput)  // Add camera input to session
      } else {
        print("Error: Could not add video device input to the session")
        return false
      }
    } catch {
      print("Error: Could not create video device input: \(error.localizedDescription)")
      return false
    }

    // Create video data output and set this class as its delegate
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

    if session.canAddOutput(videoOutput) {
      session.addOutput(videoOutput)  // Add video output to session
    } else {
      print("Error: Could not add video data output to the session")
      return false
    }

    // Create a new window to display the camera feed
    let windowRect = NSRect(x: 0, y: 0, width: 640, height: 480)
    let window = NSWindow(
      contentRect: windowRect,
      styleMask: [.titled, .closable, .resizable],  // Basic window controls
      backing: .buffered,
      defer: false
    )
    window.title = "Camera Preview"
    window.center()
    window.delegate = self  // Allow handling window close event

    // Create a preview layer and attach it to the session
    let previewLayer = AVCaptureVideoPreviewLayer(session: session)
    previewLayer.videoGravity = .resizeAspectFill  // Make video fill the view

    // Attach the preview layer to the window’s content view
    if let contentView = window.contentView {
      contentView.wantsLayer = true  // Enable layer-based drawing
      contentView.layer?.addSublayer(previewLayer)
      previewLayer.frame = contentView.bounds  // Fit layer to window
      previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]  // Resize dynamically
    }

    // Store references to manage later
    self.captureSession = session
    self.previewLayer = previewLayer
    self.window = window

    // Start the camera session on the main thread
    session.startRunning()

    // Show the window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)  // Bring app to front

    return true  // Successfully started preview
  }

  // Stops the camera preview and releases resources
  func stopCameraPreview() {
    self.captureSession?.stopRunning()  // Stop capturing video
    self.captureSession = nil  // Release session
    self.previewLayer = nil  // Remove preview layer reference
    self.window = nil  // Close window reference
    print("Camera preview stopped.")
  }

  // Called when the window is about to close
  func windowWillClose(_ notification: Notification) {
    stopCameraPreview()  // Stop the camera when the window closes
    NSApplication.shared.stop(nil)  // Gracefully stop the app event loop
  }

  func run() {
    let app = NSApplication.shared  // Get the shared application instance
    app.setActivationPolicy(.regular)  // Allow it to appear in the Dock

    if startCameraPreview() {
      print("Camera preview started.")
    } else {
      print("Failed to start camera preview.")
      return
    }

    app.run()  // Keep the app running until the user closes the window
  }
}
