//
//  DownsampleOperationSepcs.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/10.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import SparseRanges
@testable import RDMWaveformView

class DownsampleOperationSepcs: AudioSpecsBase {
  override func spec() {
    guard !UIDevice.isSimulator else {
      print("DownsampleOperationSepcs doesn't run on a simulator")
      return
    }

    describe("start") {
      it("downsamples") {
        waitUntil { done in
          self.getAudioContext { audioContext in
            var range = SparseCountableRange<Int>()
            var count = 0
            let operation = DownsampleOperation(audioContext: audioContext,
                                                timeRange: 1..<4,
                                                downsampleRate: 32000/25,
                                                decibelMax: -50,
                                                decibelMin: -50)
            { (operation, downsampleRange, downsample, lastCall) in
              range.add(downsampleRange)
              count += downsample.count
            }
            operation.start()
            // The second call should be ignored.
            operation.start()
            operation.waitUntilFinished()

            expect(operation.state) == .finished
            expect(count) == 25*3
            expect(range.ranges) == [25..<100]
            expect(operation.decibelMax) > -50
            expect(operation.decibelMax) <= 0
            // Since it has been invoked, it won't start again.
            operation.start()
            expect(operation.state) == .finished
            done()
          }
        }
      }
    }
  }
}
