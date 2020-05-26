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

        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return  }

        let image = UIImage(cgImage: cgImage)

        DispatchQueue.main.async {
            self.viewModel?.decoded_seq = "1010"
        }
        print("hello!!! \(self.viewModel?.decoded_seq)")
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

class ViewModel: ObservableObject {
    @Published var someTxt = "Initial Content"
    @Published var decoded_seq = "0101"
}
