import AVFoundation
import CoreImage
import VideoToolbox

class VideoCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let captureSession = AVCaptureSession()
  var frameCallback: ((CMSampleBuffer) -> Void)?

  func startCapture() {
    guard let videoDevice = AVCaptureDevice.default(for: .video) else {
      print("❌ No video device found")
      return
    }

    do {
      let videoInput = try AVCaptureDeviceInput(device: videoDevice)
      if captureSession.canAddInput(videoInput) {
        captureSession.addInput(videoInput)
      }

      let videoOutput = AVCaptureVideoDataOutput()
      videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

      if captureSession.canAddOutput(videoOutput) {
        captureSession.addOutput(videoOutput)
      }

      captureSession.startRunning()
      print("📷 Video capture started")
    } catch {
      print("❌ Error setting up video capture: \(error)")
    }
  }

  func stopCaptue() {
    captureSession.stopRunning()  // Stop capturing video
    print("Camera preview stopped.")

  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    frameCallback?(sampleBuffer)  // Send frames to the network
  }
}

func sampleBufferTOJPEGData(_ sampleBuffer: CMSampleBuffer) -> Data? {
  print("In sampleBuffer")
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
