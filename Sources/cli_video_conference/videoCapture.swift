import AVFoundation
import CoreImage
import VideoToolbox

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private var captureSession: AVCaptureSession?
  var frameCallback: ((CMSampleBuffer) -> Void)?

  override init() {
    super.init()
    setupCaptureSession()
  }

  private func setupCaptureSession() {
    let session = AVCaptureSession()
    session.sessionPreset = .high

    guard let videoDevice = AVCaptureDevice.default(for: .video) else {
      print("Error: No video device available")
      return
    }

    do {
      let deviceInput = try AVCaptureDeviceInput(device: videoDevice)
      if session.canAddInput(deviceInput) {
        session.addInput(deviceInput)
      } else {
        print("Error: Could not add video device input to the session")
        return
      }

      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

      if session.canAddOutput(videoOutput) {
        session.addOutput(videoOutput)
      } else {
        print("Error: Could not add video data output to the session")
        return
      }

      self.captureSession = session
    } catch {
      print("Error: Could not create video device input: \(error.localizedDescription)")
    }
  }

  func startCapture() {
    print("Starting video capture...")
    DispatchQueue.global(qos: .userInitiated).async {
      self.captureSession?.startRunning()
    }
  }

  func stopCapture() {
    captureSession?.stopRunning()
  }

  // AVCaptureVideoDataOutputSampleBufferDelegate method
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    frameCallback?(sampleBuffer)
  }
}

func sampleBufferTOJPEGData(_ sampleBuffer: CMSampleBuffer) -> Data? {
  guard let imageBufferr = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

  let ciImage = CIImage(cvPixelBuffer: imageBufferr)
  let context = CIContext()

  if let jpegData = context.jpegRepresentation(
    of: ciImage, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:])
  {
    return jpegData
  }

  return nil
}
