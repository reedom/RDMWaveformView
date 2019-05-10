//
//  RDMAudioDownsamplerSpecs.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/10.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import SparseRanges
@testable import RDMWaveformView

class RDMAudioDownsamplerSpecs: QuickSpec {
  override func spec() {
    guard !UIDevice.isSimulator else {
      print("RDMAudioLoadOperation doesn't run on a simulator")
      return
    }

    describe("downsample") {
      it("downsamples") {
        waitUntil { done in
          self.getAudioContext { audioContext in
            let downsampler = RDMAudioDownsampler(audioContext: audioContext,
                                                  downsampleRate: 32000/25,
                                                  decibelMax: -50,
                                                  decibelMin: -50)
            var data1 = [CGFloat]()  // timeRange: 0..<4
            var data2 = [CGFloat]()  // timeRange: 4..<8
            var data3 = [CGFloat]()  // timeRange: 3..<5

            let callback1 = { (downsampleRange: DownsampleRange, downsamples: ArraySlice<CGFloat>) in
              data1.append(contentsOf: downsamples)
            }

            let callback2 = { (downsampleRange: DownsampleRange, downsamples: ArraySlice<CGFloat>) in
              data2.append(contentsOf: downsamples)
            }

            let callback3 = { (downsampleRange: DownsampleRange, downsamples: ArraySlice<CGFloat>) in
              data3.append(contentsOf: downsamples)
            }

            let completed3 = {
              expect(data3.count) == 25*2
              expect(data1[75..<100]) == data3[0..<25]
              expect(data2[0..<25]) == data3[25..<50]
              expect(downsampler.decibelMax) > -50.0
              done()
            }

            let completed2 = {
              expect(data2.count) == 25*4
              expect(data1[0..<100]) != data2[0..<100]
              downsampler.downsample(timeRange: 3..<5, onComplete: completed3, callback: callback3)
            }

            let completed1 = {
              expect(data1.count) == 25*4
              expect(downsampler.decibelMax) > -50.0
              downsampler.downsample(timeRange: 4..<8, onComplete: completed2, callback: callback2)
            }

            downsampler.downsample(timeRange: 0..<4, onComplete: completed1, callback: callback1)
          }
        }
      }
    }
  }
}

extension RDMAudioDownsamplerSpecs {
  func getAudioContext(callback: @escaping (_ audioContext: RDMAudioContext) -> Void) {
    guard let url = Bundle.main.url(forResource: "file_example_MP3_700KB", withExtension: "mp3") else {
      fail("Failed to find resource: file_example_MP3_700KB.mp3")
      return
    }

    RDMAudioContext.load(fromAudioURL: url) { result in
      switch result {
      case .success(let audioContext):
        callback(audioContext)
      default:
        fail("Failed to load resource: file_example_MP3_700KB.mp3")
        return
      }
    }
  }
}
