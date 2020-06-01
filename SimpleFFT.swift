//
//  SimpleFFT.swift
//  HiLight-Capture
//
//  Created by Liang Arthur on 5/30/20.
//  Copyright © 2020 Liang Arthur. All rights reserved.
//
//
//  The FFT component of this file is modified based on Apple's FFT tutorial
//  https://developer.apple.com/documentation/accelerate/finding_the_component_frequencies_in_a_composite_sine_wave
import Foundation
import AVFoundation
import SwiftUI
import Combine
import Accelerate

class SimpleFFT {
    // some constants for FFT
    let n = 6
    
    // the fft initializer has to take in lengh of 2^()
    let tot_fft_length = 24
    lazy var log2n: vDSP_Length = vDSP_Length(log2(Float(tot_fft_length)))
    
    var fftSetup: vDSP_DFT_Setup
            
    init () {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil,
                                            vDSP_Length(tot_fft_length),
                                            vDSP_DFT_Direction.FORWARD)!
    }
    
    
    // returns two arrays, frequencies and corresponding magnitudes
    func runFFTonSignal(_ signal: [Float]) -> [Float] {
        assert(signal.count == n)
        
        // duplicate signals
        var i = 0
        var duplicated_signal = [Float](repeating: 0,
            count: tot_fft_length)
        while (i < tot_fft_length) {
            duplicated_signal[i] = signal[i % signal.count]
            i += 1
        }
        
        
//        var forwardInputReal = [Float](repeating: 0,
//                                       count: tot_fft_length)
        var forwardInputReal = duplicated_signal
        var forwardInputImag = [Float](repeating: 0,
                                       count: tot_fft_length)
        var forwardOutputReal = [Float](repeating: 0,
                                        count: tot_fft_length)
        var forwardOutputImag = [Float](repeating: 0,
                                        count: tot_fft_length)
        var forwardOutputMagnitude = [Float](repeating: 0,
                                        count: tot_fft_length)
        
        
//        var highlights_mag = [Float](repeating: 0, count: 15)
//        var highlights_freq = [Float](repeating: 0, count: 15)
        
        let forwardOutputRealPtr: UnsafeMutablePointer = UnsafeMutablePointer(mutating: forwardOutputReal)
        let forwardOutputImagPtr: UnsafeMutablePointer = UnsafeMutablePointer(mutating: forwardOutputImag)
        vDSP_DFT_Execute(self.fftSetup,
                        forwardInputReal, forwardInputImag,
                        forwardOutputRealPtr, forwardOutputImagPtr)
        let forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr,
                                            imagp: forwardOutputImagPtr)
        vDSP.absolute(forwardOutput, result: &forwardOutputMagnitude)
        
        print("\(signal)")
        print("\(forwardOutputMagnitude)")
        
//        let _ = withUnsafeMutablePointer(to: &forwardOutputReal, { forwardOutputRealPtr in
//            let _ = withUnsafeMutablePointer(to: &forwardOutputImag, { forwardOutputImagPtr in
//
//                // 1: Create a `DSPSplitComplex` to contain the signal.
////                        var forwardInput = DSPSplitComplex(realp: forwardInputRealPtr.baseAddress!,
////                                                           imagp: forwardInputImagPtr.baseAddress!)
//
//                // 2: Convert the real values in `signal` to complex numbers.
//                duplicated_signal.withUnsafeBytes {
//                    vDSP.convert(interleavedComplexVector: [DSPComplex]($0.bindMemory(to: DSPComplex.self)),
//                                 toSplitComplexVector: &forwardInput)
//                }
//
//                // 3: Create a `DSPSplitComplex` to receive the FFT result.
//                var forwardOutput = DSPSplitComplex(realp: forwardOutputRealPtr,
//                                                    imagp: forwardOutputImagPtr)
//
//                // 4: Perform the forward FFT.
//                vDSP_DFT_Execute(self.fftSetup,
//                                 forwardInputReal, forwardInputImag,
//                                 forwardOutputRealPtr, forwardOutputImagPtr)
////                        self.fftSetup.forward(input: forwardInput,
////                                         output: &forwardOutput)
//
//                // calculate magnitude
////                        print("output highilights")
//                vDSP.absolute(forwardOutput, result: &forwardOutputMagnitude)
//
//            })
//
//        })
        return forwardOutputMagnitude
    }
    
}
