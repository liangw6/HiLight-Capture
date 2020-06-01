//
//  ResultManager.swift
//  HiLight-Capture
//
//  Created by Liang Arthur on 5/31/20.
//  Copyright © 2020 Liang Arthur. All rights reserved.
//

import Foundation


class ResultManager {
    
    let threshold = 2000
    // array of only 0 and 1 for now
    var resultSoFar = [Int]()
    
    // input signal is FFT output
    // extract the databit, i.e. 0 or 1, from the signal if the signal is present
    // otherwise return -1
    func getDataBit(signal: [Float]) -> Int {
        // 6 frames per signal
//        assert(signal.count == 16)
        
        let freq_10hz = 4
        let freq_20hz = 8
        if (signal[freq_10hz - 1] <= signal[freq_10hz] && signal[freq_10hz] >= signal[freq_10hz + 1] &&
            signal[freq_20hz - 1] <= signal[freq_20hz] && signal[freq_20hz] >= signal[freq_20hz + 1]
            ) {
            // bins corresponding to 10 hz && 20 hz are the local maxima
            // this corresponds to freq of 30 hz (10 + 20)
            if (Int(signal[freq_10hz]) >= self.threshold) {
                return 1
            }
        } else if (signal[freq_20hz - 1] <= signal[freq_20hz] && signal[freq_20hz] >= signal[freq_20hz + 1]) {
            if (Int(signal[freq_20hz]) >= self.threshold) {
                return 0
            }
        }
        
        return -1
    }
    
    func appendDataBit(datab: Int) {
        self.resultSoFar.append(datab)
    }
    
    func isSequenceCorrect(parityBit: Int) -> Bool {
        let currSum = self.resultSoFar.reduce(0, +)
        if (currSum % 2 != parityBit) {
            return false
        }
        return true
    }
    
    func clearResult() {
        self.resultSoFar = [Int]()
    }
    
    func getResult() -> [Int] {
        return self.resultSoFar
    }
    
}
