//
//  SimpleDCT.swift
//  HiLight-Capture
//
//  Created by Liang Arthur on 5/30/20.
//  Copyright © 2020 Liang Arthur. All rights reserved.
//

import Foundation
import Accelerate

let numSamples = 6

class SimpleDCT {
    let threshold = Float(0)
    let forwardDCTSetup = vDSP.DCT(count: numSamples, transformType: vDSP.DCTTransformType.II)
    
    func dct(signal: [Float]) -> [Float] {
        var forwardDCT = forwardDCTSetup!.transform(signal)

        vDSP.threshold(forwardDCT,
                       to: self.threshold,
                       with: .zeroFill,
                       result: &forwardDCT)
        
        return forwardDCT
    }
}
