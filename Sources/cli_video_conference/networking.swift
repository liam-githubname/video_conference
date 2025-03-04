import AVFoundation
import Network

class VideoStreamer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private var captureSession: AVCaptureSession!
    private var connection: NWConnection?
    private var compressionSession: VTCompressionSession?

    init(ip: String, port: UInt16) {
        super.init()
        setupConnection(ip: ip, port: port)
        setupCaptureSession()
    }

    private func setupConnection(ip: String, port: UInt16) {
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: port))
        connection = NWConnection(to: endpoint, using: .tcp)
        connection?.start(queue: .global())
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Failed to access camera")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))

        captureSession.addInput(input)
        captureSession.addOutput(output)

        setupCompressionSession()

        captureSession.startRunning()
    }

    private func setupCompressionSession() {
        let width = 640, height = 480
        VTCompressionSessionCreate(allocator: nil, width: Int32(width), height: Int32(height), codecType: kCMVideoCodecType_H264, encoderSpecification: nil, imageBufferAttributes: nil, compressedDataAllocator: nil, outputCallback: { _, frameStatus, flags, sampleBuffer, refCon in
            if frameStatus == noErr, let sampleBuffer = sampleBuffer {
                let streamer = Unmanaged<VideoStreamer>.fromOpaque(refCon!).takeUnretainedValue()
                streamer.sendEncodedSampleBuffer(sampleBuffer)
            }
        }, refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), compressionSessionOut: &compressionSession)

        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTCompressionSessionPrepareToEncodeFrames(compressionSession!)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        VTCompressionSessionEncodeFrame(compressionSession!, imageBuffer: imageBuffer, presentationTimeStamp: timestamp, duration: .invalid, frameProperties: nil, sourceFrameRefcon: nil, infoFlagsOut: nil)
    }

    private func sendEncodedSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &length, dataPointerOut: &dataPointer)

        if let dataPointer = dataPointer {
            let data = Data(bytes: dataPointer, count: length)
            connection?.send(content: data, completion: .contentProcessed({ error in
                if let error = error {
                    print("Send failed: \(error)")
                }
            }))
        }
    }
}

public class VideoReceiver {
    private var listener: NWListener?
    private var connection: NWConnection?
    private var displayLayer: AVSampleBufferDisplayLayer!
    private var decompressionSession: VTDecompressionSession?

    init(port: UInt16, displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        setupListener(port: port)
        setupDecompressionSession()
    }

    private func setupListener(port: UInt16) {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: port))
            listener?.newConnectionHandler = { [weak self] newConnection in
                self?.connection = newConnection
                newConnection.start(queue: .global())
                self?.receiveData()
            }
            listener?.start(queue: .global())
        } catch {
            print("Failed to start listener: \(error)")
        }
    }

    private func setupDecompressionSession() {
        let width = 640, height = 480
        var formatDescription: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreate(allocator: nil, codecType: kCMVideoCodecType_H264, width: Int32(width), height: Int32(height), extensions: nil, formatDescriptionOut: &formatDescription)

        VTDecompressionSessionCreate(allocator: nil, formatDescription: formatDescription!, decoderSpecification: nil, imageBufferAttributes: nil, outputCallback: { _, status, flags, imageBuffer, timestamp, duration, refCon in
            if status == noErr, let imageBuffer = imageBuffer {
                let receiver = Unmanaged<VideoReceiver>.fromOpaque(refCon!).takeUnretainedValue()
                receiver.displayDecodedFrame(imageBuffer, timestamp: timestamp)
            }
        }, refcon: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), decompressionSessionOut: &decompressionSession)
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536, completion: { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.decodeReceivedData(data)
            }
            if isComplete {
                self?.connection?.cancel()
            } else if error == nil {
                self?.receiveData()
            }
        })
    }

    private func decodeReceivedData(_ data: Data) {
        var blockBuffer: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: data.count, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0, blockBufferOut: &blockBuffer)

        if let blockBuffer = blockBuffer {
            CMBlockBufferReplaceDataBytes(with: data, blockBuffer: blockBuffer, offsetIntoDestination: 0)

            var sampleBuffer: CMSampleBuffer?
            let sampleSizeArray: [Int] = [data.count]
            CMSampleBufferCreateReady(allocator: nil, dataBuffer: blockBuffer, formatDescription: nil, sampleCount: 1, sampleTimingArray: nil, sampleSizeArray: sampleSizeArray, sampleBufferOut: &sampleBuffer)

            if let sampleBuffer = sampleBuffer {
                VTDecompressionSessionDecodeFrame(decompressionSession!, sampleBuffer: sampleBuffer, flags: [], frameRefcon: nil, infoFlagsOut: nil)
            }
        }
    }

    private func displayDecodedFrame(_ imageBuffer: CVImageBuffer, timestamp: CMTime) {
        var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: timestamp, decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?

        CMSampleBufferCreateForImageBuffer(allocator: nil, imageBuffer: imageBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: nil, sampleTiming: &timingInfo, sampleBufferOut: &sampleBuffer)

        if let sampleBuffer = sampleBuffer {
            displayLayer.enqueue(sampleBuffer)
        }
    }
}
