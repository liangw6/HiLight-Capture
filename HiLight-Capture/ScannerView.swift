//
//  ScannerView.swift
//  HiLight-Capture
//
//  Created by Liang Arthur on 5/24/20.
//  Copyright © 2020 Liang Arthur. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import SwiftUI

final class ScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, ObservableObject {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var videoOutput = AVCaptureVideoDataOutput()
//    var didOutputNewImage: (UIImage) -> Void
    
    var viewModel: ViewModel?
    
    var lastTimestamp = Date().toMillisTimestamp()!
    var lastTimerTick = 0
    var tick = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blue
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
            configureCameraForHighestFrameRate(device: videoCaptureDevice)
        } else {
            failed()
            return
        }

        
        
        self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer"))

        // always make sure the AVCaptureSession can accept the selected output
        if captureSession.canAddOutput(self.videoOutput) {

          // add the output to the current session
          captureSession.addOutput(self.videoOutput)
        } else {
            failed()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        //previewLayer.frame = view.layer.bounds
        previewLayer.frame = CGRect(x: 20, y: 60, width: 335, height: 200)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }

    func configureCameraForHighestFrameRate(device: AVCaptureDevice) {
        
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?

        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate > bestFrameRateRange?.maxFrameRate ?? 0 {
                    bestFormat = format
                    bestFrameRateRange = range
                }
//                print("curr format \(format) with min \(range.minFrameRate) and max \(range.maxFrameRate)")
            }
        }
        
        if let bestFormat = bestFormat,
           let bestFrameRateRange = bestFrameRateRange {
            do {
                try device.lockForConfiguration()

                // Set the device's active format.
                device.activeFormat = bestFormat

                // Set the device's min/max frame duration.
//                let duration = bestFrameRateRange.minFrameDuration
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(60))
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(60))

                device.unlockForConfiguration()
            } catch {
                // Handle error.
                print("oh no!!!!")
            }
        }
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if (captureSession?.isRunning == false) {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return  }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        print("average color \(ciImage.averageColor)")
//        let context = CIContext()
//        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return  }
//
//        let image = UIImage(cgImage: cgImage)

        // make sure we are at correct framerate
        if (lastTimerTick == 0) {
            lastTimerTick = tick
            lastTimestamp = Date().toMillisTimestamp()
        }
        
        let new_timestamp = Date().toMillisTimestamp()!
        if (new_timestamp - lastTimestamp > 1000) {
            print("frame rate is at \(tick - lastTimerTick) fps")
            lastTimerTick = tick
            lastTimestamp = new_timestamp
        }
        tick += 1
        
        DispatchQueue.main.async {
            self.viewModel?.decoded_seq = "1010"
        }
//        print("hello!!! \(self.viewModel?.decoded_seq)")
      // the final picture is here, we call the completion block
//      self.didOutputNewImage()
    }
    
    func found(code: String) {
        print(code)
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}

extension CIImage {
    var averageColor: UIColor? {
//        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: self.extent.origin.x, y: self.extent.origin.y, z: self.extent.size.width, w: self.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}

// To communicate back with the SwiftUI
struct ScanView: UIViewControllerRepresentable {
    var viewModel: ViewModel

    public typealias UIViewControllerType = ScannerViewController

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.viewModel = viewModel
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ScannerViewController, context:Context) {
        
    }
}

// Wrapper for the text field we are interested in sending between
// SwiftUI and UIViewController
class ViewModel: ObservableObject {
    @Published var someTxt = "Initial Content"
    @Published var decoded_seq = "0101"
}

extension Date {
    func toMillisTimestamp() -> Int64! {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
}

//extension AVCaptureDevice {
//    func set(frameRate: Double) {
//    guard let range = activeFormat.videoSupportedFrameRateRanges.first,
//        range.minFrameRate...range.maxFrameRate ~= frameRate
//        else {
//            print("Requested FPS is not supported by the device's activeFormat !")
//            return
//    }
//
//    do { try lockForConfiguration()
//        activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
//        activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
//        unlockForConfiguration()
//    } catch {
//        print("LockForConfiguration failed with error: \(error.localizedDescription)")
//    }
//  }
//}
