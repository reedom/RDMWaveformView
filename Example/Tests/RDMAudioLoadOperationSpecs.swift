//
//  RDMAudioLoadOperationSpecs.swift
//  RDMWaveformView_Tests
//
//  Created by HANAI Tohru on 2019/05/10.
//  Copyright © 2019 CocoaPods. All rights reserved.
//

import Quick
import Nimble
import SparseRanges
@testable import RDMWaveformView

class RDMAudioLoadOperationSpecs: QuickSpec {
  override func spec() {
    guard !UIDevice.isSimulator else {
      print("RDMAudioLoadOperation doesn't run on a simulator")
      return
    }

    describe("start") {
      it("downsamples") {
        waitUntil { [weak self] done in
          guard let self = self else { return }
          self.getAudioContext { audioContext in
            var range = SparseCountableRange<Int>()
            var count = 0
            let operation = RDMAudioLoadOperation(audioContext: audioContext,
                                                  timeRange: 1..<4,
                                                  downsampleRate: 32000/25,
                                                  decibelMax: -50,
                                                  decibelMin: -50)
            { (operation, downsampleRange, downsample) in
              range.add(downsampleRange)
              count += downsample?.count ?? 0
            }
            operation.start()
            // The second call should be ignored.
            operation.start()
            operation.waitUntilFinished()

            expect(operation.state) == .finished
            expect(count) == 25*3
            expect(range.ranges) == [25..<100]
            expect(operation.decibelMax) > -50
            expect(operation.decibelMax) < 0
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

extension RDMAudioLoadOperationSpecs {
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
