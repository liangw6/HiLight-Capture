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
    var allResult = [Int]()
    
    // input signal is FFT output
    // extract the databit, i.e. 0 or 1, from the signal if the signal is present
    // otherwise return -1
    func getDataBit(signal: [Float], threshold: Float=0) -> Int {
        // 6 frames per signal
        assert(signal.count == 24)
        
//        let freq_10hz = 4
        let freq_20hz = 8
        let freq_30hz = 12
        
        if (threshold != 0 && signal[freq_30hz] <= threshold && signal[freq_20hz] <= threshold) {
            return -1
        }
        
        if (signal[freq_30hz] >= signal[freq_20hz]) {
            return 1
        } else {
            return 0
        }
//        if (signal[freq_10hz - 1] <= signal[freq_10hz] && signal[freq_10hz] >= signal[freq_10hz + 1] &&
//            signal[freq_20hz - 1] <= signal[freq_20hz] && signal[freq_20hz] >= signal[freq_20hz + 1]
//            ) {
//            // bins corresponding to 10 hz && 20 hz are the local maxima
//            // this corresponds to freq of 30 hz (10 + 20)
//            if (Int(signal[freq_10hz]) >= self.threshold) {
//                return 1
//            }
//        } else if (signal[freq_20hz - 1] <= signal[freq_20hz] && signal[freq_20hz] >= signal[freq_20hz + 1]) {
//            if (Int(signal[freq_20hz]) >= self.threshold) {
//                return 0
//            }
//        }
//
//        return -1
    }
    
    func appendDataBit(datab: Int) {
        self.resultSoFar.append(datab)
    }
    
    // assume the following layout for the data signal
    // [ignore_head, n x data_bits, 1 parity bit, ignore_tail]
//    func isSequenceCorrect() -> Bool {
//        assert(self.resultSoFar.count >= 3)
//        let actual_sequence = Array(self.resultSoFar[1...(self.resultSoFar.count - 3)])
//        let parityBit = self.resultSoFar[self.resultSoFar.count - 2]
//        let currSum = actual_sequence.reduce(0, +)
//        if (currSum % 2 != parityBit) {
//            return false
//        }
//        return true
//    }
    
    // assume the following layout for the data signal
    // [n x data_bits, 1 parity bit]
    func isSequenceCorrect() -> Bool {
        assert(self.resultSoFar.count >= 1)
        let actual_sequence = Array(self.resultSoFar[0...(self.resultSoFar.count - 2)])
        let parityBit = self.resultSoFar[self.resultSoFar.count - 1]
        let currSum = actual_sequence.reduce(0, +)
        if (currSum % 2 != parityBit) {
            return false
        }
        return true
    }
    
    func clearResult() {
        self.resultSoFar = [Int]()
        // copy it to all_result
        for result in self.resultSoFar {
            self.allResult.append(result)
        }
    }
    
    func getResult() -> [Int] {
        return self.resultSoFar
    }
    
}
