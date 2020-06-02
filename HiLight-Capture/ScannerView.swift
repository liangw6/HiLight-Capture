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
    let FRAME_SIZE = 6
    let ini_n_frame = 60          // during the first init_n_frame, the processing will sleep, to allow camera warm up
//    let tot_packet_size = 11       // [ignore_head, 8 x data_bits, 1 parity bit, ignore_tail]
    let tot_packet_size = 8       // [n x data_bits, 1 parity bit]
    let simpleFFT = SimpleFFT()
    
    
    var average_init_color: Float = -1.0
    var cool_down_ticks = 0
    var resultManager = ResultManager()
    var detectedPreambleSequence = false
    let PreambleSequence = [0, 1, 0]
    // 1200 = 20 seconds * 60 fps
    var data_buf = [Float](repeating: 0, count: 1200)
    var head_idx = 0
    var tail_idx = 0
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var videoOutput = AVCaptureVideoDataOutput()
    var videoCaptureDevice: AVCaptureDevice!
//    var didOutputNewImage: (UIImage) -> Void
    
    var viewModel: ViewModel?
    
    var lastTimestamp = Date().toMillisTimestamp()!
    var lastTimerTick = 0
    var tick = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.blue
        captureSession = AVCaptureSession()

        self.videoCaptureDevice = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: .video,
                position: AVCaptureDevice.Position.back)
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: self.videoCaptureDevice)
        } catch {
            return
        }

        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
            configureCameraForHighestFrameRate(device: self.videoCaptureDevice)
//            captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
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
        previewLayer.frame = view.layer.bounds
//        previewLayer.frame = CGRect(x: 20, y: 60, width: 335, height: 200)
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
           let _ = bestFrameRateRange {
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
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchPoint = touches.first! as UITouch
        let screenSize = view.bounds.size
        let focusPoint = CGPoint(x: touchPoint.location(in: view).y / screenSize.height, y: 1.0 - touchPoint.location(in: view).x / screenSize.width)

        if let device = self.videoCaptureDevice {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = focusPoint
                    device.focusMode = AVCaptureDevice.FocusMode.autoFocus
//                    device.videoZoomFactor = 2
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = focusPoint
                    device.exposureMode = AVCaptureDevice.ExposureMode.autoExpose
                }
                device.unlockForConfiguration()

            } catch {
                // Handle errors here
            }
        }
        
        if (self.resultManager.allResult.count > 0) {
            for i in 0...(self.resultManager.allResult.count - 1) {
                print(self.resultManager.allResult[i], terminator: ", ")
            }
            exit(0)
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return  }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)

        let currColorChange = ciImage.averageColor
//        print("average color \(currColorChange!)")
        if (currColorChange != nil && tick >= self.ini_n_frame) {
            if (tail_idx < data_buf.count) {
                data_buf[tail_idx] = currColorChange!
                
                // we have not yet found the preamble sequence
                if (!self.detectedPreambleSequence) {
//                    if currColorChange! > self.average_init_color * 1.6 {
////                        print("detected preamble")
//                        self.detectedPreambleSequence = true
//                        // the first ever bright image is part of data
//                        // keep it
//                        head_idx = tail_idx
//                    }
                    
                    if (tail_idx - head_idx >= FRAME_SIZE * self.PreambleSequence.count - 1) {
                        
                        // check with preamble
                        // one bit / 6 frames at a time from the end
                        var found_preamble: Bool = true
                        var curr_preabmle_end = tail_idx
                        var curr_preamble_start = curr_preabmle_end - FRAME_SIZE + 1
                        var curr_preamble_i = self.PreambleSequence.count - 1
                        assert(curr_preamble_start >= head_idx)
                        while (curr_preamble_start >= head_idx) {
                            let currFFToutput = simpleFFT.runFFTonSignal(Array(data_buf[curr_preamble_start...curr_preabmle_end]))
                            let currDataBit = self.resultManager.getDataBit(signal: currFFToutput, threshold: 1000)
                            if (currDataBit == self.PreambleSequence[curr_preamble_i]) {
//                                print("preabmble [\(curr_preamble_i)]: \(currFFToutput) as \(currDataBit)")
                                curr_preabmle_end = curr_preabmle_end - FRAME_SIZE
                                curr_preamble_start = curr_preabmle_end - FRAME_SIZE + 1
                                curr_preamble_i -= 1
                            } else {
                                found_preamble = false
                                break
                            }
                        }
                        if (found_preamble) {
                            print("detected preamble")
                            self.detectedPreambleSequence = true
                            // have finished preamble, we can just skip to actual data
                            head_idx = tail_idx + 1
                        } else {
                            head_idx = head_idx + 1
                        }
                        
//                        let currFFToutput = simpleFFT.runFFTonSignal(Array(data_buf[(tail_idx - FRAME_SIZE + 1)...tail_idx]))
//                        let currDataBit = self.resultManager.getDataBit(signal: currFFToutput, threshold: 2000)
//                        if (currDataBit == self.PreambleSequence[1]) {
//                            let FFToutput = simpleFFT.runFFTonSignal(Array(data_buf[head_idx...(head_idx + FRAME_SIZE - 1)]))
//                            let lastDataBit = self.resultManager.getDataBit(signal: FFToutput, threshold: 2000)
//                            if (lastDataBit == self.PreambleSequence[0]) {
//                                print("detected preamble")
//                                print("preabmble [0]: \(FFToutput) as \(lastDataBit)")
//                                print("preablme [1]: \(currFFToutput) as \(currDataBit)")
//
//                                self.detectedPreambleSequence = true
//                                // have finished preamble, we can just skip to actual data
//                                head_idx = tail_idx + 1
//                            }
//                        } else {
//                            // use sliding window to look for preamble sequence
//                            head_idx = head_idx + 1
//                        }
                    }
                } else {
                    // we have preabmel sequence found
                    // array slicing in swift is inclusive on both ends
                    if (tail_idx - head_idx >= FRAME_SIZE - 1) {
                        // ready for FFT!
                        let FFToutput = simpleFFT.runFFTonSignal(Array(data_buf[head_idx...tail_idx]))
                        let currDataBit = self.resultManager.getDataBit(signal: FFToutput)
                        self.resultManager.appendDataBit(datab: currDataBit)
//                        print("\(FFToutput) as \(currDataBit)")
                        if (self.resultManager.resultSoFar.count == tot_packet_size) {
                            print("Final Result \(self.resultManager.resultSoFar) with correct? = \(self.resultManager.isSequenceCorrect())")
                            self.resultManager.clearResult()
                            self.detectedPreambleSequence = false
                            // cool down for 2 frames
                            self.cool_down_ticks = 2
                            
                            // update visualization
                            DispatchQueue.main.async {
                                self.viewModel?.decoded_seq = "\(self.resultManager.resultSoFar)"
                            }
                        }
//
//                        if (self.resultManager.resultSoFar.count == tot_packet_size - 1) {
//                            // end of packet! check parity
//                            print("\(FFToutput) as \(currDataBit)")
//                            print("Final Result \(self.resultManager.resultSoFar) with correct? = \(self.resultManager.isSequenceCorrect(parityBit: currDataBit))")
//                            self.resultManager.clearResult()
//                            self.detectedPreambleSequence = false
//
//                            // cool down for 2 frames
//                            self.cool_down_ticks = 2
//                        } else {
//                            // still more to go, continue appending packets
//                            self.resultManager.appendDataBit(datab: currDataBit)
//                            print("\(FFToutput) as \(currDataBit)")
//                        }
                        // skip all current data
                        head_idx = tail_idx + 1
                    }
                }
                
                tail_idx += 1
                
            } else {
                // should never reach there until 10 seconds
                DispatchQueue.main.async {
                    self.viewModel?.decoded_seq = "Buffer Full!"
                }
            }
        } else {
            if (tick >= self.ini_n_frame) {
                print("skipping frame!!!")
            }
        }
        
//        let context = CIContext()
//        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return  }
//
//        let image = UIImage(cgImage: cgImage)
        
        
        // used to identify preamble. allows cool down after
        // decoding a packet
        if (self.cool_down_ticks > 0) {
            self.cool_down_ticks -= 1
        }
        
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
        
        if (tick >= self.ini_n_frame) {
            DispatchQueue.main.async {
                self.viewModel?.decoded_seq = "Ready!"
                // do this once and exactly
                if self.average_init_color == -1.0 {
                    self.average_init_color = currColorChange!
                }
            }
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
    var averageColor: Float? {
//        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: self.extent.origin.x, y: self.extent.origin.y, z: self.extent.size.width, w: self.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: self, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        // average of all three channels
        // output is between [0, 1]
        return ( Float(bitmap[0]) + Float(bitmap[1]) + Float(bitmap[2]) ) * Float(bitmap[3]) / 3
        
//        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
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
    @Published var decoded_seq = "Initializing"
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
